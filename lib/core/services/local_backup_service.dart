import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';
import '../utils/path_safety.dart';
import 'settings_service.dart';

/// Structured result of a backup write operation.
class BackupResult {
  final bool isSuccess;
  final DateTime timestamp;
  final int bytesWritten;
  final Map<String, int> boxCounts;
  final String? error;

  const BackupResult({
    required this.isSuccess,
    required this.timestamp,
    this.bytesWritten = 0,
    this.boxCounts = const {},
    this.error,
  });

  int get totalItems => boxCounts.values.fold(0, (sum, count) => sum + count);
}

/// Structured result of a backup restore operation.
class RestoreResult {
  final bool isSuccess;
  final DateTime? backupTimestamp;
  final Map<String, int> restoredCounts;
  final String? error;

  const RestoreResult({
    required this.isSuccess,
    this.backupTimestamp,
    this.restoredCounts = const {},
    this.error,
  });

  int get totalRestored => restoredCounts.values.fold(0, (sum, count) => sum + count);
}

/// Metadata describing a reachable backup snapshot on disk.
class BackupSnapshotInfo {
  final DateTime timestamp;
  final int fileSizeBytes;
  final Map<String, int> boxCounts;
  final String filePath;

  const BackupSnapshotInfo({
    required this.timestamp,
    required this.fileSizeBytes,
    required this.boxCounts,
    required this.filePath,
  });

  int get totalItems => boxCounts.values.fold(0, (sum, count) => sum + count);
}

/// Local backup of the user's library.
///
/// The automatic backup is written to *app-private* storage only. An extra
/// copy in shared storage (public Downloads on Android) is written only
/// when the user opts in from Settings — that copy survives an uninstall
/// but is readable by any app or user with storage access, which is why it
/// is opt-in and off by default. Nothing is ever uploaded to the cloud.
/// Restore always validates a candidate file before writing anything
/// (see [restoreIfNeeded]).
class LocalBackupService {
  LocalBackupService._();

  static final LocalBackupService instance = LocalBackupService._();

  /// Boxes that hold user data worth preserving across uninstalls.
  static const List<String> _boxes = <String>[
    'listening_history',
    'liked_songs',
    'playlists',
    'search_history',
    'downloads',
  ];

  /// Backup schema version written by this build; restore refuses others.
  static const int _version = 1;

  /// Restore refuses files larger than this before decoding them.
  static const int _maxBackupBytes = 50 * 1024 * 1024;

  /// Restore refuses any box with more entries than this.
  static const int _maxEntriesPerBox = 5000;

  Timer? _debounce;

  /// Backup read candidates, best first: private locations, then the legacy
  /// shared Downloads location (older builds wrote there; still restorable
  /// after validation, even when the opt-in is off).
  Future<List<Directory>> _candidateBaseDirs() async {
    final dirs = <Directory>[];
    try {
      dirs.add(await getApplicationDocumentsDirectory());
    } catch (_) {
      // Not available on this platform.
    }
    try {
      final external = await getExternalStorageDirectory();
      if (external != null) dirs.add(external);
    } catch (_) {
      // Not available on this platform.
    }
    dirs.add(Directory('/storage/emulated/0/Download'));
    return dirs;
  }

  /// Creates (if needed) the PrismMusic backup file under [base].
  Future<File?> _backupFileIn(Directory base) async {
    try {
      final Directory backupDir = Directory('${base.path}/PrismMusic/backup');
      await backupDir.create(recursive: true);
      return File('${backupDir.path}/library_backup.json');
    } catch (_) {
      return null;
    }
  }

  /// Existing backup files, best-first order. Returns every candidate that
  /// exists on disk; [restoreIfNeeded] uses the first valid one.
  Future<List<File>> _existingBackupFiles() async {
    final files = <File>[];
    for (final Directory base in await _candidateBaseDirs()) {
      final file = File('${base.path}/PrismMusic/backup/library_backup.json');
      try {
        if (await file.exists()) files.add(file);
      } catch (_) {
        // Unreadable candidate — skip it.
      }
    }
    return files;
  }

  /// App-private base dirs for *writing* the automatic backup.
  Future<List<Directory>> _privateBaseDirs() async {
    final dirs = <Directory>[];
    try {
      dirs.add(await getApplicationDocumentsDirectory());
    } catch (_) {
      // Not available on this platform.
    }
    try {
      final external = await getExternalStorageDirectory();
      if (external != null) dirs.add(external);
    } catch (_) {
      // Not available on this platform.
    }
    return dirs;
  }

  /// Shared base dir for *writing* the opt-in extra copy.
  Future<List<Directory>> _sharedBaseDirs() async =>
      <Directory>[Directory('/storage/emulated/0/Download')];

  /// The shared-storage copy is written only on explicit opt-in. When the
  /// setting cannot be read, fail closed: no shared writes.
  bool _sharedBackupOptIn() {
    try {
      return SettingsService.instance.sharedBackupEnabled;
    } catch (_) {
      return false;
    }
  }

  /// Schedule a debounced backup. Safe to call after every mutation; rapid
  /// successive calls collapse into a single write a few seconds later.
  /// No-op when the user disabled automatic backups.
  void scheduleBackup() {
    try {
      if (!SettingsService.instance.autoBackupEnabled) return;
    } catch (_) {
      // Settings unavailable — default to backing up.
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () async {
      await backup();
    });
  }

  /// Write all tracked boxes to the JSON backup file: always to app-private
  /// storage, plus one shared-storage copy when the user opted in.
  Future<BackupResult> backup() async {
    final now = DateTime.now();
    try {
      final Map<String, dynamic> payload = <String, dynamic>{
        'version': _version,
        'backedUpAt': now.toIso8601String(),
        'boxes': <String, dynamic>{},
      };

      final Map<String, int> boxCounts = <String, int>{};

      for (final String name in _boxes) {
        try {
          final Box<dynamic> box = await Hive.openBox(name);
          final Map<String, dynamic> entries = <String, dynamic>{};
          for (final dynamic key in box.keys) {
            final dynamic value = box.get(key);
            if (value != null) entries[key.toString()] = value;
          }
          payload['boxes'][name] = entries;
          boxCounts[name] = entries.length;
        } catch (_) {
          // Skip boxes that fail to open; keep the rest.
        }
      }

      final String encoded = jsonEncode(payload);
      final List<File> targets = <File>[];

      // Private primary copy — always.
      for (final Directory base in await _privateBaseDirs()) {
        final File? file = await _backupFileIn(base);
        if (file != null) {
          targets.add(file);
          break;
        }
      }

      // Shared copy — only on explicit opt-in (survives uninstall, but is
      // readable by other apps with storage access).
      if (_sharedBackupOptIn()) {
        for (final Directory base in await _sharedBaseDirs()) {
          final File? file = await _backupFileIn(base);
          if (file != null) {
            targets.add(file);
            break;
          }
        }
      }

      if (targets.isEmpty) {
        return BackupResult(
          isSuccess: false,
          timestamp: now,
          error: 'No writable storage location found for backup',
        );
      }

      int writtenBytes = 0;
      for (final File file in targets) {
        try {
          final tempFile = File('${file.path}.tmp');
          await tempFile.writeAsString(encoded, flush: true);
          if (await file.exists()) {
            await file.delete();
          }
          await tempFile.rename(file.path);
          writtenBytes = encoded.length;
        } catch (e) {
          logError('Failed writing backup to ${file.path}: $e');
        }
      }

      if (writtenBytes == 0) {
        return BackupResult(
          isSuccess: false,
          timestamp: now,
          error: 'Failed to write backup files to disk',
        );
      }

      return BackupResult(
        isSuccess: true,
        timestamp: now,
        bytesWritten: writtenBytes,
        boxCounts: boxCounts,
      );
    } catch (e) {
      logError('Unexpected error during backup: $e');
      return BackupResult(
        isSuccess: false,
        timestamp: now,
        error: e.toString(),
      );
    }
  }

  /// Inspect the newest valid backup candidate on disk without modifying Hive.
  Future<BackupSnapshotInfo?> getLatestBackupInfo() async {
    try {
      final candidates = await _existingBackupFiles();
      if (candidates.isEmpty) return null;

      final downloadRoots = await DownloadPathGuard.allowedRoots();

      for (final file in candidates) {
        try {
          final length = await file.length();
          if (length > _maxBackupBytes) continue;

          final dynamic payload = jsonDecode(await file.readAsString());
          if (payload is! Map<String, dynamic>) continue;

          final boxes = validateRestoredPayload(payload, downloadRoots: downloadRoots);
          if (boxes == null) continue;

          final backedUpAtStr = payload['backedUpAt']?.toString();
          final DateTime backupTime = backedUpAtStr != null
              ? (DateTime.tryParse(backedUpAtStr) ?? await file.lastModified())
              : await file.lastModified();

          final counts = <String, int>{};
          for (final entry in boxes.entries) {
            counts[entry.key] = entry.value.length;
          }

          return BackupSnapshotInfo(
            timestamp: backupTime,
            fileSizeBytes: length,
            boxCounts: counts,
            filePath: file.path,
          );
        } catch (_) {
          continue;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Manually restore all boxes from the newest valid backup file.
  /// When [overwrite] is true, replaces existing entries in each box.
  Future<RestoreResult> restoreFromBackup({bool overwrite = true}) async {
    try {
      final candidates = await _existingBackupFiles();
      if (candidates.isEmpty) {
        return const RestoreResult(
          isSuccess: false,
          error: 'No backup file found on device',
        );
      }

      final downloadRoots = await DownloadPathGuard.allowedRoots();
      final List<(DateTime, Map<String, Map<String, dynamic>>)> validBackups = [];

      for (final file in candidates) {
        try {
          if (await file.length() > _maxBackupBytes) continue;

          final dynamic payload = jsonDecode(await file.readAsString());
          if (payload is! Map<String, dynamic>) continue;

          final boxes = validateRestoredPayload(payload, downloadRoots: downloadRoots);
          if (boxes == null) continue;

          final backedUpAtStr = payload['backedUpAt']?.toString();
          final DateTime backupTime = backedUpAtStr != null
              ? (DateTime.tryParse(backedUpAtStr) ?? await file.lastModified())
              : await file.lastModified();

          validBackups.add((backupTime, boxes));
        } catch (_) {}
      }

      if (validBackups.isEmpty) {
        return const RestoreResult(
          isSuccess: false,
          error: 'No valid or compatible backup snapshot found',
        );
      }

      // Sort newest first
      validBackups.sort((a, b) => b.$1.compareTo(a.$1));
      final selected = validBackups.first;
      final boxes = selected.$2;

      final restoredCounts = <String, int>{};
      for (final String name in _boxes) {
        final Map<String, dynamic>? entries = boxes[name];
        if (entries == null || entries.isEmpty) continue;

        final Box<dynamic> box = await Hive.openBox(name);
        if (overwrite) {
          await box.clear();
        }
        for (final MapEntry<String, dynamic> entry in entries.entries) {
          await box.put(entry.key, entry.value);
        }
        restoredCounts[name] = entries.length;
      }

      return RestoreResult(
        isSuccess: true,
        backupTimestamp: selected.$1,
        restoredCounts: restoredCounts,
      );
    } catch (e) {
      return RestoreResult(
        isSuccess: false,
        error: e.toString(),
      );
    }
  }

  /// Exports the latest backup file. If none exists, creates one first.
  Future<File?> getBackupFileForExport() async {
    var candidates = await _existingBackupFiles();
    if (candidates.isEmpty) {
      final res = await backup();
      if (!res.isSuccess) return null;
      candidates = await _existingBackupFiles();
    }
    if (candidates.isEmpty) return null;
    return candidates.first;
  }

  /// Imports and restores user data from a given backup file.
  Future<RestoreResult> importBackupFromFile(
    File file, {
    bool overwrite = true,
  }) async {
    try {
      if (!await file.exists()) {
        return const RestoreResult(
          isSuccess: false,
          error: 'Specified backup file does not exist',
        );
      }

      if (await file.length() > _maxBackupBytes) {
        return const RestoreResult(
          isSuccess: false,
          error: 'Backup file exceeds maximum allowed size (50MB)',
        );
      }

      final dynamic payload = jsonDecode(await file.readAsString());
      if (payload is! Map<String, dynamic>) {
        return const RestoreResult(
          isSuccess: false,
          error: 'Backup file does not contain valid JSON metadata',
        );
      }

      final downloadRoots = await DownloadPathGuard.allowedRoots();
      final boxes =
          validateRestoredPayload(payload, downloadRoots: downloadRoots);
      if (boxes == null) {
        return const RestoreResult(
          isSuccess: false,
          error: 'Backup format is incompatible or contains corrupted entries',
        );
      }

      final backedUpAtStr = payload['backedUpAt']?.toString();
      final DateTime backupTime = backedUpAtStr != null
          ? (DateTime.tryParse(backedUpAtStr) ?? await file.lastModified())
          : await file.lastModified();

      final restoredCounts = <String, int>{};
      for (final String name in _boxes) {
        final Map<String, dynamic>? entries = boxes[name];
        if (entries == null || entries.isEmpty) continue;

        final Box<dynamic> box = await Hive.openBox(name);
        if (overwrite) {
          await box.clear();
        }
        for (final MapEntry<String, dynamic> entry in entries.entries) {
          await box.put(entry.key, entry.value);
        }
        restoredCounts[name] = entries.length;
      }

      return RestoreResult(
        isSuccess: true,
        backupTimestamp: backupTime,
        restoredCounts: restoredCounts,
      );
    } catch (e) {
      return RestoreResult(
        isSuccess: false,
        error: e.toString(),
      );
    }
  }

  /// Deletes all backup files found across private and shared locations.
  Future<int> deleteBackupFiles() async {
    final candidates = await _existingBackupFiles();
    int count = 0;
    for (final file in candidates) {
      try {
        if (await file.exists()) {
          await file.delete();
          count++;
        }
      } catch (_) {}
    }
    return count;
  }

  /// Removes backup files or refreshes backup after user explicitly clears data.
  Future<void> clearBackupData({List<String>? boxes}) async {
    try {
      if (boxes == null) {
        final candidates = await _existingBackupFiles();
        for (final file in candidates) {
          try {
            if (await file.exists()) await file.delete();
          } catch (_) {}
        }
      } else {
        // Rewrite backup with current live state
        await backup();
      }
    } catch (_) {}
  }

  /// Restore boxes from the newest reachable valid backup file, but only when a
  /// box is currently empty (so a fresh install reuses old data without
  /// clobbering new data).
  ///
  /// Backup files live in storage other parties may be able to modify, so
  /// every candidate is size-capped and schema-validated *before* anything
  /// is written; a corrupt or hostile file is rejected wholesale.
  Future<void> restoreIfNeeded() async {
    try {
      final candidates = await _existingBackupFiles();
      if (candidates.isEmpty) return;

      final List<(DateTime, Map<String, Map<String, dynamic>>)> validBackups = [];
      final downloadRoots = await DownloadPathGuard.allowedRoots();

      for (final file in candidates) {
        try {
          if (await file.length() > _maxBackupBytes) {
            logError('Backup restore skipped: file too large (${file.path})');
            continue;
          }

          final dynamic payload = jsonDecode(await file.readAsString());
          if (payload is! Map<String, dynamic>) continue;

          final boxes = validateRestoredPayload(payload, downloadRoots: downloadRoots);
          if (boxes == null) {
            logError('Backup restore rejected: invalid schema (${file.path})');
            continue;
          }

          DateTime backupTime;
          final backedUpAtStr = payload['backedUpAt']?.toString();
          if (backedUpAtStr != null) {
            backupTime = DateTime.tryParse(backedUpAtStr) ?? await file.lastModified();
          } else {
            backupTime = await file.lastModified();
          }

          validBackups.add((backupTime, boxes));
        } catch (_) {
          // Corrupt or unreadable candidate — try the next one.
        }
      }

      if (validBackups.isEmpty) return;

      // Sort newest first
      validBackups.sort((a, b) => b.$1.compareTo(a.$1));

      // Restore from the newest valid backup
      await _writeValidatedBoxes(validBackups.first.$2);
    } catch (_) {
      // If the backup is corrupt or unreadable, ignore it.
    }
  }

  /// Validates a decoded backup payload against the v1 schema.
  ///
  /// Returns the normalized box entries eligible for restore, or null when
  /// the payload must be rejected wholesale (wrong version, unexpected
  /// structure, or entry/count abuse). Download paths outside the app-owned
  /// [downloadRoots] are stripped from the returned entries — the file they
  /// point at must never be deleted or played by this app. Pure function:
  /// nothing is written to Hive here.
  static Map<String, Map<String, dynamic>>? validateRestoredPayload(
    Map<String, dynamic> payload, {
    List<String> downloadRoots = const [],
  }) {
    final dynamic version = payload['version'];
    if (version is! num || version != _version) return null;

    final dynamic rawBoxes = payload['boxes'];
    if (rawBoxes is! Map || rawBoxes.isEmpty) return null;

    // Strict v1 schema: any unrecognized box name rejects the payload.
    for (final dynamic name in rawBoxes.keys) {
      if (!_boxes.contains(name)) return null;
    }

    final validated = <String, Map<String, dynamic>>{};
    for (final String name in _boxes) {
      final dynamic rawEntries = rawBoxes[name];
      if (rawEntries == null) continue;
      if (rawEntries is! Map) return null;
      if (rawEntries.length > _maxEntriesPerBox) return null;

      final entries = <String, dynamic>{};
      for (final MapEntry<dynamic, dynamic> entry in rawEntries.entries) {
        if (entry.key is! String) return null;
        if (entry.value is! Map) return null;
        entries[entry.key as String] =
            _sanitizeRestoredEntry(name, entry.value as Map, downloadRoots);
      }
      validated[name] = entries;
    }
    return validated;
  }

  /// Strips untrusted fields from a single restored entry.
  static Map<String, dynamic> _sanitizeRestoredEntry(
    String boxName,
    Map<dynamic, dynamic> value,
    List<String> downloadRoots,
  ) {
    final map = Map<String, dynamic>.from(value);
    if (boxName == 'downloads') {
      final dynamic path = map['localPath'];
      if (path is! String ||
          path.isEmpty ||
          !isPathWithinAllowedRoots(path, downloadRoots)) {
        map.remove('localPath');
      }
    }
    return map;
  }

  /// Writes validated entries into currently-empty boxes only.
  Future<void> _writeValidatedBoxes(Map<String, Map<String, dynamic>> boxes) async {
    for (final String name in _boxes) {
      final Map<String, dynamic>? entries = boxes[name];
      if (entries == null || entries.isEmpty) continue;

      final Box<dynamic> box = await Hive.openBox(name);
      if (box.isNotEmpty) continue; // Never clobber live data.

      for (final MapEntry<String, dynamic> entry in entries.entries) {
        await box.put(entry.key, entry.value);
      }
    }
  }
}
