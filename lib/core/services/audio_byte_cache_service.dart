import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Disk LRU cache for audio byte streams.
///
/// Prevents redundant network requests when songs are replayed, looped,
/// or navigated during playback. Enforces a strict storage quota (default 512 MB).
class AudioByteCacheService {
  final Directory? _overrideDir;
  final int maxCacheSizeBytes;

  Directory? _cacheDir;
  final Map<String, DateTime> _accessTimes = {};

  AudioByteCacheService({
    Directory? cacheDirectory,
    this.maxCacheSizeBytes = 512 * 1024 * 1024, // 512 MB
  }) : _overrideDir = cacheDirectory;

  Future<Directory> _getCacheDir() async {
    final override = _overrideDir;
    if (override != null) {
      if (!override.existsSync()) {
        await override.create(recursive: true);
      }
      return override;
    }

    if (_cacheDir != null && _cacheDir!.existsSync()) {
      return _cacheDir!;
    }

    final tempDir = await getTemporaryDirectory();
    final dir = Directory(p.join(tempDir.path, 'audio_byte_cache'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  String _sanitizeKey(String songId) {
    return songId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  Future<File> _getFile(String songId) async {
    final dir = await _getCacheDir();
    final safeKey = _sanitizeKey(songId);
    return File(p.join(dir.path, '$safeKey.cache'));
  }

  /// Checks if complete cached audio bytes exist for [songId].
  Future<bool> isCached(String songId) async {
    try {
      final file = await _getFile(songId);
      final exists = await file.exists();
      if (exists && (await file.length()) > 0) {
        _accessTimes[songId] = DateTime.now();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves the cached file for [songId] if present, updating LRU access time.
  Future<File?> getCachedFile(String songId) async {
    try {
      final file = await _getFile(songId);
      if (await file.exists() && (await file.length()) > 0) {
        _accessTimes[songId] = DateTime.now();
        return file;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Saves raw audio bytes for [songId] to cache, enforcing quota.
  Future<File> putBytes(String songId, List<int> bytes) async {
    final file = await _getFile(songId);
    await file.writeAsBytes(bytes, flush: true);
    _accessTimes[songId] = DateTime.now();
    await evictOldestIfNeeded();
    return file;
  }

  /// Pipes a byte stream into cache for [songId].
  Future<File> putStream(String songId, Stream<List<int>> stream) async {
    final file = await _getFile(songId);
    final sink = file.openWrite();
    try {
      await sink.addStream(stream);
      await sink.flush();
    } finally {
      await sink.close();
    }
    _accessTimes[songId] = DateTime.now();
    await evictOldestIfNeeded();
    return file;
  }

  /// Reads a byte range stream from cached file if present.
  Future<Stream<List<int>>?> getStream(String songId, [int? start, int? end]) async {
    final file = await getCachedFile(songId);
    if (file == null) return null;
    return file.openRead(start, end);
  }

  /// Calculates total size of currently cached audio files in bytes.
  Future<int> getCacheSizeBytes() async {
    try {
      final dir = await _getCacheDir();
      if (!dir.existsSync()) return 0;
      int total = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Evicts least recently accessed audio files until total size is within [maxCacheSizeBytes].
  Future<void> evictOldestIfNeeded() async {
    try {
      final dir = await _getCacheDir();
      if (!dir.existsSync()) return;

      final files = <File>[];
      int totalSize = 0;

      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.cache')) {
          files.add(entity);
          totalSize += await entity.length();
        }
      }

      if (totalSize <= maxCacheSizeBytes) return;

      // Sort files by last modified / recorded access time
      files.sort((a, b) {
        final aTime = _accessTimes[p.basenameWithoutExtension(a.path)] ??
            a.lastModifiedSync();
        final bTime = _accessTimes[p.basenameWithoutExtension(b.path)] ??
            b.lastModifiedSync();
        return aTime.compareTo(bTime);
      });

      for (final file in files) {
        if (totalSize <= maxCacheSizeBytes) break;
        final len = await file.length();
        try {
          await file.delete();
          totalSize -= len;
          _accessTimes.remove(p.basenameWithoutExtension(file.path));
          debugPrint('AudioByteCacheService: Evicted LRU file ${file.path} ($len bytes)');
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('AudioByteCacheService.evictOldestIfNeeded error: $e');
    }
  }

  /// Deletes a specific song's cache entry.
  Future<void> deleteCached(String songId) async {
    try {
      final file = await _getFile(songId);
      if (await file.exists()) {
        await file.delete();
      }
      _accessTimes.remove(_sanitizeKey(songId));
    } catch (_) {}
  }

  /// Clears the entire audio byte cache directory.
  Future<void> clearCache() async {
    try {
      final dir = await _getCacheDir();
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
      _accessTimes.clear();
    } catch (e) {
      debugPrint('AudioByteCacheService.clearCache error: $e');
    }
  }
}
