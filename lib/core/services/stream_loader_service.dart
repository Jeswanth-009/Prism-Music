import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/stream_info.dart';
import '../../domain/entities/song.dart';
import '../../data/datasources/remote/youtube/youtube_music_datasource.dart';
import 'stream_cache_service.dart';

/// Strategy for fetching stream URLs
enum StreamSource { youtubeExplode, invidious, alternative }

/// Result from a stream fetch attempt
class _FetchResult {
  final StreamSource source;
  final StreamInfo? streamInfo;
  final Object? error;
  final Duration fetchTime;

  _FetchResult({
    required this.source,
    required this.streamInfo,
    required this.error,
    required this.fetchTime,
  });

  bool get isSuccess => streamInfo != null;
}

/// Production-ready stream loader with parallel fetching and caching
class StreamLoaderService {
  final YouTubeMusicDataSource _datasource;
  final StreamCacheService _cache;

  static const Duration _streamFetchTimeout = Duration(seconds: 6);

  // Prefetch queue to load next songs in background
  final Map<String, Future<StreamInfo?>> _prefetchQueue = {};

  // Track fetch attempts for analytics
  final List<_FetchResult> _recentAttempts = [];
  static const int _maxRecentAttempts = 20;

  StreamLoaderService(this._datasource, this._cache);

  /// Load stream URL with cache check and parallel fetching
  Future<StreamInfo> loadStream(
    Song song, {
    bool useCache = true,
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    final overallStopwatch = Stopwatch()..start();
    final videoId = song.playableId; // Use playableId (youtubeId ?? id)

    // Check cache first - instant return if available
    if (useCache) {
      final cached = _cache.getCached(videoId);
      if (cached != null) {
        overallStopwatch.stop();
        debugPrint(
          'StreamLoader: Cache HIT for ${song.title} '
          '(${overallStopwatch.elapsedMilliseconds}ms)',
        );
        return cached;
      }
    }
    debugPrint('StreamLoader: Cache MISS for ${song.title}');

    // Check if already prefetching - wait for that instead of starting new fetch
    final existingPrefetch = _prefetchQueue[videoId];
    if (existingPrefetch != null) {
      debugPrint('StreamLoader: Waiting for prefetch result for ${song.title}');
      try {
        final result = await existingPrefetch;
        if (result != null) {
          overallStopwatch.stop();
          debugPrint(
            'StreamLoader: Using prefetched stream for ${song.title} '
            '(${overallStopwatch.elapsedMilliseconds}ms)',
          );
          return result;
        }
      } catch (e) {
        debugPrint('StreamLoader: Prefetch failed, fetching fresh: $e');
      }
    }

    // Fetch with optimized strategy (primary source only to reduce latency)
    debugPrint('StreamLoader: Loading stream for ${song.title}');
    final streamInfo = await _fetchOptimized(videoId, preferredQuality);

    // Cache the result
    _cache.cache(videoId, streamInfo);

    overallStopwatch.stop();
    debugPrint(
      'StreamLoader: Stream resolved for ${song.title} '
      'in ${overallStopwatch.elapsedMilliseconds}ms',
    );

    return streamInfo;
  }

  /// Optimized fetch - use primary source once and fail fast on errors.
  Future<StreamInfo> _fetchOptimized(
    String videoId,
    AudioQuality preferredQuality,
  ) async {
    final stopwatch = Stopwatch()..start();

    final result = await _fetchFromSource(
      videoId,
      StreamSource.youtubeExplode,
      preferredQuality,
    );

    _recordAttempt(result);
    stopwatch.stop();

    if (result.isSuccess) {
      debugPrint(
        'StreamLoader: Source ${result.source.name} succeeded '
        'in ${stopwatch.elapsedMilliseconds}ms',
      );
      return result.streamInfo!;
    }

    debugPrint(
      'StreamLoader: Source ${result.source.name} failed '
      'in ${stopwatch.elapsedMilliseconds}ms: ${result.error}',
    );
    throw Exception('Stream fetch failed: ${result.error}');
  }

  /// Prefetch stream for a song (non-blocking, background task)
  void prefetch(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) {
    final videoId = song.playableId; // Use playableId (youtubeId ?? id)

    // Skip if already cached or prefetching
    if (_cache.isCached(videoId) || _prefetchQueue.containsKey(videoId)) {
      debugPrint(
        'StreamLoader: Skip prefetch for ${song.title} (already cached/queued)',
      );
      return;
    }

    debugPrint('StreamLoader: Prefetching ${song.title}');
    _prefetchQueue[videoId] = _fetchOptimized(videoId, preferredQuality)
        .then<StreamInfo?>((streamInfo) {
          _cache.cache(videoId, streamInfo);
          debugPrint('StreamLoader: Prefetch complete for ${song.title}');
          return streamInfo;
        })
        .catchError((error) {
          debugPrint('StreamLoader: Prefetch failed for ${song.title}: $error');
          return null as StreamInfo?;
        })
        .whenComplete(() {
          _prefetchQueue.remove(videoId);
        });
  }

  /// Fetch from a specific source with timeout
  Future<_FetchResult> _fetchFromSource(
    String videoId,
    StreamSource source,
    AudioQuality preferredQuality,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      StreamInfo? streamInfo;

      switch (source) {
        case StreamSource.youtubeExplode:
          streamInfo = await _datasource
              .getStreamUrl(videoId, preferredQuality: preferredQuality)
              .timeout(
                _streamFetchTimeout,
                onTimeout: () =>
                    throw TimeoutException('YouTube Explode timeout'),
              );
          break;

        case StreamSource.invidious:
          // Add Invidious implementation here
          await Future.delayed(const Duration(milliseconds: 100));
          throw UnimplementedError('Invidious not implemented yet');

        case StreamSource.alternative:
          // Add alternative source implementation here
          await Future.delayed(const Duration(milliseconds: 100));
          throw UnimplementedError('Alternative source not implemented yet');
      }

      stopwatch.stop();
      return _FetchResult(
        source: source,
        streamInfo: streamInfo,
        error: null,
        fetchTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return _FetchResult(
        source: source,
        streamInfo: null,
        error: e,
        fetchTime: stopwatch.elapsed,
      );
    }
  }

  /// Record fetch attempt for analytics
  void _recordAttempt(_FetchResult result) {
    _recentAttempts.add(result);
    if (_recentAttempts.length > _maxRecentAttempts) {
      _recentAttempts.removeAt(0);
    }
  }

  /// Get analytics about recent fetch attempts
  Map<String, dynamic> getAnalytics() {
    if (_recentAttempts.isEmpty) {
      return {'totalAttempts': 0, 'successRate': 0.0, 'averageFetchTime': 0};
    }

    final successful = _recentAttempts.where((a) => a.isSuccess).length;
    final avgTime =
        _recentAttempts
            .map((a) => a.fetchTime.inMilliseconds)
            .reduce((a, b) => a + b) /
        _recentAttempts.length;

    final sourceStats = <String, Map<String, dynamic>>{};
    for (final source in StreamSource.values) {
      final attempts = _recentAttempts
          .where((a) => a.source == source)
          .toList();
      if (attempts.isNotEmpty) {
        final successes = attempts.where((a) => a.isSuccess).length;
        final avgSourceTime =
            attempts
                .map((a) => a.fetchTime.inMilliseconds)
                .reduce((a, b) => a + b) /
            attempts.length;

        sourceStats[source.name] = {
          'attempts': attempts.length,
          'successes': successes,
          'successRate': (successes / attempts.length * 100).toStringAsFixed(1),
          'avgTime': avgSourceTime.toStringAsFixed(0),
        };
      }
    }

    return {
      'totalAttempts': _recentAttempts.length,
      'successRate': (successful / _recentAttempts.length * 100)
          .toStringAsFixed(1),
      'averageFetchTime': avgTime.toStringAsFixed(0),
      'sources': sourceStats,
      'cacheStats': _cache.getStats(),
    };
  }

  /// Clear prefetch queue
  void clearPrefetchQueue() {
    _prefetchQueue.clear();
  }
}
