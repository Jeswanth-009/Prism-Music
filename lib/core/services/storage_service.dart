import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../di/injection.dart';
import 'download_service.dart';
import 'settings_service.dart';
import 'stream_cache_service.dart';

/// Granular storage accounting across app caches, downloads, and database
class StorageBreakdown {
  final int cacheBytes;
  final int downloadsBytes;
  final int databaseBytes;
  final int totalBytes;
  final int streamCacheCount;
  final int lyricsCacheCount;
  final int downloadsCount;

  const StorageBreakdown({
    required this.cacheBytes,
    required this.downloadsBytes,
    required this.databaseBytes,
    required this.totalBytes,
    required this.streamCacheCount,
    required this.lyricsCacheCount,
    required this.downloadsCount,
  });
}

/// Service providing accurate storage metrics and safe cache cleanup
class StorageService {
  final StreamCacheService _streamCacheService;
  final DownloadService? _downloadService;

  StorageService({
    StreamCacheService? streamCacheService,
    DownloadService? downloadService,
  })  : _streamCacheService = streamCacheService ??
            (getIt.isRegistered<StreamCacheService>()
                ? getIt<StreamCacheService>()
                : StreamCacheService()),
        _downloadService = downloadService ??
            (getIt.isRegistered<DownloadService>()
                ? getIt<DownloadService>()
                : null);

  static StorageService get instance => _instance ??= StorageService();
  static StorageService? _instance;

  Future<int> _calculateDirBytes(Directory dir) async {
    if (!await dir.exists()) return 0;
    int total = 0;
    try {
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  /// Calculates granular storage usage breakdown
  Future<StorageBreakdown> getStorageBreakdown() async {
    int cacheBytes = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      cacheBytes = await _calculateDirBytes(tempDir);
    } catch (_) {}

    int downloadsBytes = 0;
    int downloadsCount = 0;
    try {
      final downloadDirPath = _downloadService != null
          ? await _downloadService.getDownloadDirectoryPath()
          : SettingsService.instance.downloadFolderPath;
      if (downloadDirPath != null && downloadDirPath.isNotEmpty) {
        final downloadDir = Directory(downloadDirPath);
      if (await downloadDir.exists()) {
        await for (final entity
            in downloadDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            final lower = entity.path.toLowerCase();
            if (lower.endsWith('.m4a') ||
                lower.endsWith('.mp3') ||
                lower.endsWith('.opus') ||
                lower.endsWith('.aac')) {
              downloadsCount++;
              try {
                downloadsBytes += await entity.length();
              } catch (_) {}
            }
          }
        }
      }
    }
  } catch (_) {}

    int databaseBytes = 0;
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      if (await appDocDir.exists()) {
        await for (final entity in appDocDir.list(followLinks: false)) {
          if (entity is File && entity.path.endsWith('.hive')) {
            try {
              databaseBytes += await entity.length();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    final streamStats = _streamCacheService.getStats();
    final streamCacheCount = streamStats['valid'] as int? ?? 0;

    int lyricsCacheCount = 0;
    try {
      if (Hive.isBoxOpen('lyrics_cache')) {
        lyricsCacheCount = Hive.box<Map>('lyrics_cache').length;
      }
    } catch (_) {}

    return StorageBreakdown(
      cacheBytes: cacheBytes,
      downloadsBytes: downloadsBytes,
      databaseBytes: databaseBytes,
      totalBytes: cacheBytes + downloadsBytes + databaseBytes,
      streamCacheCount: streamCacheCount,
      lyricsCacheCount: lyricsCacheCount,
      downloadsCount: downloadsCount,
    );
  }

  /// Performs accurate and safe cleanup of volatile caches while preserving user library data
  Future<int> clearCache() async {
    final beforeBreakdown = await getStorageBreakdown();

    // Clear in-memory stream cache
    _streamCacheService.clearAll();

    // Clear Flutter image cache
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    // Clear network image disk cache
    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {}

    // Clear lyrics cache box
    try {
      if (Hive.isBoxOpen('lyrics_cache')) {
        await Hive.box<Map>('lyrics_cache').clear();
      } else {
        final box = await Hive.openBox<Map>('lyrics_cache');
        await box.clear();
      }
    } catch (_) {}

    // Clear song metadata cache box
    try {
      if (Hive.isBoxOpen('song_cache')) {
        await Hive.box('song_cache').clear();
      }
    } catch (_) {}

    // Delete temporary files safely
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await for (final entity in tempDir.list(followLinks: false)) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}

    final afterBreakdown = await getStorageBreakdown();
    final freed = beforeBreakdown.cacheBytes - afterBreakdown.cacheBytes;
    return freed > 0 ? freed : beforeBreakdown.cacheBytes;
  }
}
