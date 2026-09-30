import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

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
  Future<void> restoreIfNeeded() async {
    try {
      final candidates = await _existingBackupFiles();
      if (candidates.isEmpty) return;

      Map<String, dynamic>? boxes;
      for (final file in candidates) {
        try {
          final Map<String, dynamic> payload =
              jsonDecode(await file.readAsString()) as Map<String, dynamic>;
          boxes =
              (payload['boxes'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>();
          if (boxes != null && boxes.isNotEmpty) break;
        } catch (_) {
          // Corrupt or unreadable candidate — try the next one.
        }
      }
      if (boxes == null) return;

      for (final String name in _boxes) {
        final dynamic entries = boxes[name];
        if (entries is! Map) continue;

        final Box<dynamic> box = await Hive.openBox(name);
        if (box.isNotEmpty) continue;

        final Map<dynamic, dynamic> map = entries.cast<dynamic, dynamic>();
        for (final MapEntry<dynamic, dynamic> entry in map.entries) {
          await box.put(entry.key, entry.value);
        }
      }
    } catch (_) {
      // If the backup is corrupt or unreadable, ignore it.
    }
  }
}
