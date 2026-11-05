import 'dart:async';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../domain/entities/song.dart';
import '../utils/logger.dart';

/// Service that aggressively prefetches artwork for upcoming queue items
/// and individual songs into [DefaultCacheManager].
///
/// Because [CachedNetworkImage] uses [DefaultCacheManager] under the hood,
/// downloading them here ensures instant, zero-latency image rendering
/// when navigating, scrolling through queue, or viewing now playing.
class ArtworkPrefetchService {
  ArtworkPrefetchService._({BaseCacheManager? cacheManager})
      : _customCacheManager = cacheManager;

  static ArtworkPrefetchService instance = ArtworkPrefetchService._();

  /// Create an instance with custom cache manager for testing
  factory ArtworkPrefetchService.custom({required BaseCacheManager cacheManager}) {
    return ArtworkPrefetchService._(cacheManager: cacheManager);
  }

  final BaseCacheManager? _customCacheManager;
  final Set<String> _inFlightUrls = {};

  BaseCacheManager? _getCacheManager() {
    if (_customCacheManager != null) return _customCacheManager;
    try {
      return DefaultCacheManager();
    } catch (_) {
      return null;
    }
  }

  /// Pre-caches artwork for upcoming tracks in the queue.
  ///
  /// [lookahead] determines how many tracks beyond [currentIndex] to fetch (default: 8).
  /// Returns the number of distinct URLs scheduled for prefetching.
  Future<int> prefetchUpcomingQueue(
    List<Song> queue,
    int currentIndex, {
    int lookahead = 8,
  }) async {
    try {
      if (queue.isEmpty || currentIndex < 0) return 0;

      final targets = <String>{};
      final startIndex = currentIndex;
      final endIndex = (currentIndex + 1 + lookahead).clamp(0, queue.length);

      for (int i = startIndex; i < endIndex; i++) {
        final song = queue[i];
        final url = _resolveArtworkUrl(song);
        if (url != null && url.isNotEmpty && !_inFlightUrls.contains(url)) {
          targets.add(url);
        }
      }

      if (targets.isEmpty) return 0;

      int initiatedCount = 0;
      for (final url in targets) {
        _inFlightUrls.add(url);
        initiatedCount++;
        unawaited(_prefetchSingleUrl(url));
      }

      return initiatedCount;
    } catch (e) {
      logDebug('ArtworkPrefetchService: failed to prefetch queue: $e');
      return 0;
    }
  }

  /// Prefetches artwork for a single song (e.g. when added to queue).
  Future<void> prefetchSongArtwork(Song song) async {
    try {
      final url = _resolveArtworkUrl(song);
      if (url != null && url.isNotEmpty && !_inFlightUrls.contains(url)) {
        _inFlightUrls.add(url);
        await _prefetchSingleUrl(url);
      }
    } catch (e) {
      logDebug('ArtworkPrefetchService: failed to prefetch single song artwork: $e');
    }
  }

  String? _resolveArtworkUrl(Song song) {
    if (song.thumbnailUrl.isNotEmpty) {
      return song.thumbnailUrl;
    }
    final best = song.thumbnails.best;
    if (best != null && best.isNotEmpty) {
      return best;
    }
    return null;
  }

  Future<void> _prefetchSingleUrl(String url) async {
    try {
      final cm = _getCacheManager();
      if (cm == null) return;
      final existing = await cm.getFileFromCache(url);
      if (existing != null && await existing.file.exists()) {
        return;
      }
      await cm.downloadFile(url);
    } catch (e) {
      logDebug('ArtworkPrefetchService: failed to prefetch $url: $e');
    } finally {
      _inFlightUrls.remove(url);
    }
  }

  /// Clear the tracking set
  void resetInFlight() {
    _inFlightUrls.clear();
  }
}
