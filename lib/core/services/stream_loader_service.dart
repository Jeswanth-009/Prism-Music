import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/stream_info.dart';
import '../../domain/entities/song.dart';
import '../../data/datasources/remote/youtube/youtube_music_datasource.dart';
import '../../data/datasources/remote/youtube/piped_datasource.dart';
import '../../data/datasources/remote/youtube/invidious_datasource.dart';
import '../../data/datasources/remote/jiosaavn/jiosaavn_datasource.dart';
import 'stream_cache_service.dart';

/// Strategy for fetching stream URLs
enum StreamSource { jioSaavn, youtubeExplode, invidious, alternative }

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
  final JioSaavnDataSource _jioSaavn = JioSaavnDataSourceImpl();

  static const Duration _streamFetchTimeout = Duration(seconds: 10);

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
    final streamInfo = await _fetchOptimized(song, preferredQuality);

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
    Song song,
    AudioQuality preferredQuality,
  ) async {
    final videoId = song.playableId;
    final stopwatch = Stopwatch()..start();

    // Primary: JioSaavn
    debugPrint('StreamLoader: Trying JioSaavn primary...');
    final jioStream = await _jioSaavn.getStreamUrl(song);
    
    if (jioStream != null) {
      debugPrint('StreamLoader: JioSaavn succeeded in ${stopwatch.elapsedMilliseconds}ms');
      _recordAttempt(_FetchResult(source: StreamSource.jioSaavn, streamInfo: jioStream, error: null, fetchTime: stopwatch.elapsed));
      return jioStream;
    }

    debugPrint('StreamLoader: JioSaavn failed, trying YouTube Explode fallback...');

    // Fallback 1: YouTube Explode
    final ytResult = await _fetchFromSource(
      videoId,
      StreamSource.youtubeExplode,
      preferredQuality,
    );
    _recordAttempt(ytResult);

    if (ytResult.isSuccess) {
      debugPrint('StreamLoader: YouTube Explode succeeded in ${stopwatch.elapsedMilliseconds}ms');
      return ytResult.streamInfo!;
    }
    
    debugPrint('StreamLoader: YouTube Explode failed, trying Piped fallback...');

    // Fallback 1: Piped (Alternative)
    final pipedResult = await _fetchFromSource(
      videoId,
      StreamSource.alternative,
      preferredQuality,
    );
    _recordAttempt(pipedResult);

    if (pipedResult.isSuccess) {
      debugPrint('StreamLoader: Piped fallback succeeded in ${stopwatch.elapsedMilliseconds}ms');
      return pipedResult.streamInfo!;
    }

    debugPrint('StreamLoader: Piped failed, trying Invidious fallback...');

    // Fallback 2: Invidious
    final invResult = await _fetchFromSource(
      videoId,
      StreamSource.invidious,
      preferredQuality,
    );
    _recordAttempt(invResult);

    if (invResult.isSuccess) {
      debugPrint('StreamLoader: Invidious fallback succeeded in ${stopwatch.elapsedMilliseconds}ms');
      return invResult.streamInfo!;
    }

    stopwatch.stop();
    throw Exception('All stream sources failed to fetch $videoId');
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
    _prefetchQueue[videoId] = _fetchOptimized(song, preferredQuality)
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

  /// Invalidate cached stream for a song
  void invalidateCache(String videoId) {
    _cache.invalidate(videoId);
    _prefetchQueue.remove(videoId);
    debugPrint('StreamLoader: Invalidated cache and prefetch for $videoId');
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
          final invidious = InvidiousDataSource();
          streamInfo = await invidious.getStreamUrl(videoId)
              .timeout(_streamFetchTimeout);
          break;

        case StreamSource.alternative:
          final piped = PipedDataSource();
          streamInfo = await piped.getStreamUrl(videoId)
              .timeout(_streamFetchTimeout);
          break;

        case StreamSource.jioSaavn:
          // Handled directly in _fetchOptimized
          break;
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
