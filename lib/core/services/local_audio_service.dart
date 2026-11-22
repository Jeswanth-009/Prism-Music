import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../../domain/entities/entities.dart';
import '../utils/logger.dart';
import 'settings_service.dart';

/// Service for scanning, indexing, and managing on-device audio files.
///
/// Supports standard formats (.mp3, .m4a, .flac, .opus, .wav, .ogg, .aac),
/// handles Android 13+ (API 33+) vs legacy storage permissions, respects .nomedia
/// exclusions, and integrates with folder whitelist/blacklist configurations.
class LocalAudioService {
  static const Set<String> supportedExtensions = {
    '.mp3',
    '.m4a',
    '.flac',
    '.opus',
    '.wav',
    '.ogg',
    '.aac',
  };

  final SettingsService _settings;
  final List<Directory>? _overrideDirectories;
  final Future<bool> Function()? _overridePermissionChecker;

  List<Song> _cachedSongs = const [];
  DateTime? _lastScanTime;
  bool _isScanning = false;

  final _songsController = StreamController<List<Song>>.broadcast();
  Stream<List<Song>> get songsStream => _songsController.stream;
  List<Song> get cachedSongs => _cachedSongs;
  bool get isScanning => _isScanning;

  static LocalAudioService? _instance;
  static LocalAudioService get instance => _instance ??= LocalAudioService();

  LocalAudioService({
    SettingsService? settings,
    List<Directory>? overrideDirectories,
    Future<bool> Function()? overridePermissionChecker,
  })  : _settings = settings ?? SettingsService.instance,
        _overrideDirectories = overrideDirectories,
        _overridePermissionChecker = overridePermissionChecker;

  /// Check whether the app has permission to access on-device audio.
  Future<bool> hasStoragePermission() async {
    if (_overridePermissionChecker != null) {
      return _overridePermissionChecker();
    }

    if (kIsWeb) return false;
    if (!Platform.isAndroid && !Platform.isIOS) {
      // Desktop platforms don't require scoped runtime permissions
      return true;
    }

    if (Platform.isAndroid) {
      // On Android 13+ (API 33+), check Permission.audio
      final audioStatus = await Permission.audio.status;
      if (audioStatus.isGranted || audioStatus.isLimited) return true;

      // On Android 12 and below, check legacy storage permission
      final storageStatus = await Permission.storage.status;
      return storageStatus.isGranted || storageStatus.isLimited;
    }

    return true;
  }

  /// Request runtime permissions for on-device audio.
  Future<bool> requestStoragePermission() async {
    if (_overridePermissionChecker != null) {
      return _overridePermissionChecker();
    }

    if (kIsWeb) return false;
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    if (Platform.isAndroid) {
      // Request audio permission first (API 33+)
      final audioStatus = await Permission.audio.request();
      if (audioStatus.isGranted || audioStatus.isLimited) return true;

      // Fallback for Android 12 and below
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted || storageStatus.isLimited;
    }

    return true;
  }

  /// Get candidate root directories to scan.
  List<Directory> _getTargetDirectories() {
    if (_overrideDirectories != null) {
      return _overrideDirectories;
    }

    final dirs = <Directory>[];

    if (!kIsWeb && Platform.isAndroid) {
      const androidPaths = [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Podcasts',
        '/storage/emulated/0/Audiobooks',
      ];
      for (final path in androidPaths) {
        final d = Directory(path);
        if (d.existsSync()) dirs.add(d);
      }
    } else if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final userProfile = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
      if (userProfile != null) {
        final music = Directory(p.join(userProfile, 'Music'));
        final downloads = Directory(p.join(userProfile, 'Downloads'));
        if (music.existsSync()) dirs.add(music);
        if (downloads.existsSync()) dirs.add(downloads);
      }
    }

    // Add user-configured custom folders from settings
    try {
      for (final folderPath in _settings.includedAudioFolders) {
        final d = Directory(folderPath);
        if (d.existsSync() && !dirs.any((existing) => existing.path == d.path)) {
          dirs.add(d);
        }
      }
    } catch (_) {}

    return dirs;
  }

  /// Scans device storage for audio files.
  Future<List<Song>> scanLocalAudio({bool force = false}) async {
    if (_isScanning) return _cachedSongs;
    if (!force && _cachedSongs.isNotEmpty && _lastScanTime != null) {
      if (DateTime.now().difference(_lastScanTime!) < const Duration(minutes: 5)) {
        return _cachedSongs;
      }
    }

    final permitted = await hasStoragePermission();
    if (!permitted) {
      logDebug('LocalAudioService: Storage permission not granted; skipping scan');
      return _cachedSongs;
    }

    _isScanning = true;
    try {
      final targetDirs = _getTargetDirectories();
      List<String> excludedFolders = const [];
      try {
        excludedFolders = _settings.excludedAudioFolders;
      } catch (_) {}

      final foundSongs = <Song>[];
      final seenPaths = <String>{};

      for (final rootDir in targetDirs) {
        try {
          if (!rootDir.existsSync()) continue;
          await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
            if (entity is! File) continue;

            final filePath = entity.path;
            if (seenPaths.contains(filePath)) continue;

            final ext = p.extension(filePath).toLowerCase();
            if (!supportedExtensions.contains(ext)) continue;

            // Check hidden directory or file
            final pathSegments = p.split(filePath);
            if (pathSegments.any((seg) => seg.startsWith('.') && seg != '.' && seg != '..')) {
              continue;
            }

            // Check excluded folders
            final isExcluded = excludedFolders.any((excluded) =>
                filePath.toLowerCase().contains(excluded.toLowerCase()));
            if (isExcluded) continue;

            // Check .nomedia in parent directory
            final parentDir = entity.parent;
            if (File(p.join(parentDir.path, '.nomedia')).existsSync()) {
              continue;
            }

            final song = _fileToSong(entity);
            if (song != null) {
              seenPaths.add(filePath);
              foundSongs.add(song);
            }
          }
        } catch (e, st) {
          logError('LocalAudioService: Error scanning directory ${rootDir.path}', e, st);
        }
      }

      // Sort alphabetically by title
      foundSongs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

      _cachedSongs = List.unmodifiable(foundSongs);
      _lastScanTime = DateTime.now();
      _songsController.add(_cachedSongs);
      logDebug('LocalAudioService: Scanned ${foundSongs.length} local audio files');
      return _cachedSongs;
    } finally {
      _isScanning = false;
    }
  }

  /// Maps an on-device [File] to a [Song] domain entity.
  Song? _fileToSong(File file) {
    try {
      final fileName = p.basenameWithoutExtension(file.path);
      final parentFolder = p.basename(file.parent.path);

      String title = fileName;
      String artist = parentFolder.isNotEmpty && parentFolder != 'Music' && parentFolder != 'Download'
          ? parentFolder
          : 'Local Track';

      // Parse "Artist - Title" filename pattern
      if (fileName.contains(' - ')) {
        final parts = fileName.split(' - ');
        if (parts.length >= 2) {
          artist = parts[0].trim();
          title = parts.sublist(1).join(' - ').trim();
        }
      }

      final hash = md5.convert(utf8.encode(file.path)).toString();
      final songId = 'local_$hash';

      return Song(
        id: songId,
        title: title,
        artist: artist,
        album: parentFolder,
        duration: Duration.zero,
        thumbnails: const Thumbnails(),
        streamUrl: file.path,
        source: MusicSource.local,
      );
    } catch (e, st) {
      logError('LocalAudioService: Failed to parse file ${file.path}', e, st);
      return null;
    }
  }

  void dispose() {
    _songsController.close();
  }
}
