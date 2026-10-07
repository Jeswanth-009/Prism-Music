import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';
import '../utils/path_safety.dart';

/// Privacy-first local backup.
///
/// Serializes the user's library boxes to a plain JSON file in *shared*
/// external storage (outside the app sandbox) so the data survives an
/// uninstall. Nothing is ever uploaded to the cloud. The file is readable
/// and deletable by the user at any time.
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

  /// Backup file locations, best first.
  ///
  /// The primary location is the *public* Downloads folder: it is visible
  /// to the user and the only place that survives an uninstall — the
  /// app-specific dirs returned by getExternalStorageDirectory()
  /// (`Android/data/<package>/…`) are wiped by Android together with the
  /// app, which defeated the whole purpose of this backup. The remaining
  /// candidates are kept so backups written by older builds are still
  /// readable, and so non-Android platforms have a home.
  Future<File?> _backupFile() async {
    for (final Directory base in await _candidateBaseDirs()) {
      try {
        final Directory backupDir = Directory('${base.path}/PrismMusic/backup');
        await backupDir.create(recursive: true);
        return File('${backupDir.path}/library_backup.json');
      } catch (_) {
        // Try the next candidate.
      }
    }
    return null;
  }

  /// Existing backup files, newest-preference order. Returns every
  /// candidate that exists on disk; [restoreIfNeeded] uses the first.
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

  Future<List<Directory>> _candidateBaseDirs() async {
    final dirs = <Directory>[];
    // Public shared storage (Android). Unreachable paths simply fail the
    // create() in the caller and fall through to the next candidate.
    dirs.add(Directory('/storage/emulated/0/Download'));
    try {
      final external = await getExternalStorageDirectory();
      if (external != null) dirs.add(external);
    } catch (_) {
      // Not available on this platform.
    }
    try {
      dirs.add(await getApplicationDocumentsDirectory());
    } catch (_) {
      // Last resort failed — caller handles the empty list.
    }
    return dirs;
  }

  /// Schedule a debounced backup. Safe to call after every mutation; rapid
  /// successive calls collapse into a single write a few seconds later.
  void scheduleBackup() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () async {
      await backup();
    });
  }

  /// Write all tracked boxes to the JSON backup file.
  Future<void> backup() async {
    try {
      final File? file = await _backupFile();
      if (file == null) return;

      final Map<String, dynamic> payload = <String, dynamic>{
        'version': 1,
        'backedUpAt': DateTime.now().toIso8601String(),
        'boxes': <String, dynamic>{},
      };

      for (final String name in _boxes) {
        try {
          final Box<dynamic> box = await Hive.openBox(name);
          final Map<String, dynamic> entries = <String, dynamic>{};
          for (final dynamic key in box.keys) {
            final dynamic value = box.get(key);
            if (value != null) entries[key.toString()] = value;
          }
          payload['boxes'][name] = entries;
        } catch (_) {
          // Skip boxes that fail to open; keep the rest.
        }
      }

      await file.writeAsString(jsonEncode(payload));
    } catch (_) {
      // Best-effort backup; never crash the app over it.
    }
  }

  /// Restore boxes from the newest reachable backup file, but only when a
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

      for (final file in candidates) {
        try {
          if (await file.length() > _maxBackupBytes) {
            logError('Backup restore skipped: file too large (${file.path})');
            continue;
          }

          final dynamic payload = jsonDecode(await file.readAsString());
          if (payload is! Map<String, dynamic>) continue;

          final downloadRoots = await DownloadPathGuard.allowedRoots();
          final boxes = validateRestoredPayload(payload, downloadRoots: downloadRoots);
          if (boxes == null) {
            logError('Backup restore rejected: invalid schema (${file.path})');
            continue;
          }

          await _writeValidatedBoxes(boxes);
          return;
        } catch (_) {
          // Corrupt or unreadable candidate — try the next one.
        }
      }
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
