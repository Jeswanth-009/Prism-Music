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
  static const Duration _overallResolutionBudget = Duration(seconds: 15);

  // Circuit breaker state per source
  final Map<StreamSource, DateTime> _circuitCooldownUntil = {};
  final Map<StreamSource, int> _consecutiveErrors = {};
  static const int _circuitErrorThreshold = 3;
  static const Duration _circuitCooldownDuration = Duration(seconds: 60);

  // Set of videoIds invalidated while prefetching was in-flight
  final Set<String> _invalidatedVideoIds = {};

  // Prefetch queue to load next songs in background
  final Map<String, Future<StreamInfo?>> _prefetchQueue = {};

  // Track fetch attempts for analytics
  final List<_FetchResult> _recentAttempts = [];
  static const int _maxRecentAttempts = 20;

  StreamLoaderService(this._datasource, this._cache);

  bool _isCircuitOpen(StreamSource source) {
    final cooldownUntil = _circuitCooldownUntil[source];
    if (cooldownUntil == null) return false;
    if (DateTime.now().isAfter(cooldownUntil)) {
      _circuitCooldownUntil.remove(source);
      _consecutiveErrors[source] = 0;
      return false;
    }
    return true;
  }

  void _recordSourceSuccess(StreamSource source) {
    _consecutiveErrors[source] = 0;
    _circuitCooldownUntil.remove(source);
  }

  void _recordSourceFailure(StreamSource source) {
    final count = (_consecutiveErrors[source] ?? 0) + 1;
    _consecutiveErrors[source] = count;
    if (count >= _circuitErrorThreshold) {
      _circuitCooldownUntil[source] =
          DateTime.now().add(_circuitCooldownDuration);
      debugPrint(
        'StreamLoader: Circuit OPEN for ${source.name} for 60s ($count consecutive failures)',
      );
    }
  }

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
      final cached = _cache.getCached(videoId, preferredQuality);
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

    // Fetch with bounded overall resolution budget
    debugPrint('StreamLoader: Loading stream for ${song.title}');
    final streamInfo = await _fetchOptimized(
      song,
      preferredQuality,
    ).timeout(
      _overallResolutionBudget,
      onTimeout: () =>
          throw TimeoutException('Overall stream resolution budget (15s) exceeded for $videoId'),
    );

    // Cache the result
    _cache.cache(videoId, streamInfo, quality: preferredQuality);

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

    // Primary: JioSaavn (check circuit breaker)
    if (!_isCircuitOpen(StreamSource.jioSaavn)) {
      debugPrint('StreamLoader: Trying JioSaavn primary...');
      StreamInfo? jioStream;
      try {
        jioStream = await _jioSaavn
            .getStreamUrl(song)
            .timeout(_streamFetchTimeout);
      } catch (e) {
        debugPrint('StreamLoader: JioSaavn timed out or failed: $e');
      }

      if (jioStream != null) {
        debugPrint(
          'StreamLoader: JioSaavn succeeded in ${stopwatch.elapsedMilliseconds}ms',
        );
        _recordSourceSuccess(StreamSource.jioSaavn);
        _recordAttempt(
          _FetchResult(
            source: StreamSource.jioSaavn,
            streamInfo: jioStream,
            error: null,
            fetchTime: stopwatch.elapsed,
          ),
        );
        return jioStream;
      } else {
        _recordSourceFailure(StreamSource.jioSaavn);
      }
    } else {
      debugPrint('StreamLoader: JioSaavn circuit is OPEN; skipping.');
    }

    debugPrint('StreamLoader: JioSaavn unavailable, trying YouTube Explode fallback...');

    // Fallback 1: YouTube Explode
    if (!_isCircuitOpen(StreamSource.youtubeExplode)) {
      final ytResult = await _fetchFromSource(
        videoId,
        StreamSource.youtubeExplode,
        preferredQuality,
      );
      _recordAttempt(ytResult);

      if (ytResult.isSuccess) {
        debugPrint(
          'StreamLoader: YouTube Explode succeeded in ${stopwatch.elapsedMilliseconds}ms',
        );
        _recordSourceSuccess(StreamSource.youtubeExplode);
        return ytResult.streamInfo!;
      } else {
        _recordSourceFailure(StreamSource.youtubeExplode);
      }
    } else {
      debugPrint('StreamLoader: YouTube Explode circuit is OPEN; skipping.');
    }

    debugPrint('StreamLoader: YouTube Explode failed, trying Piped fallback...');

    // Fallback 2: Piped (Alternative)
    if (!_isCircuitOpen(StreamSource.alternative)) {
      final pipedResult = await _fetchFromSource(
        videoId,
        StreamSource.alternative,
        preferredQuality,
      );
      _recordAttempt(pipedResult);

      if (pipedResult.isSuccess) {
        debugPrint(
          'StreamLoader: Piped fallback succeeded in ${stopwatch.elapsedMilliseconds}ms',
        );
        _recordSourceSuccess(StreamSource.alternative);
        return pipedResult.streamInfo!;
      } else {
        _recordSourceFailure(StreamSource.alternative);
      }
    } else {
      debugPrint('StreamLoader: Piped circuit is OPEN; skipping.');
    }

    debugPrint('StreamLoader: Piped failed, trying Invidious fallback...');

    // Fallback 3: Invidious
    if (!_isCircuitOpen(StreamSource.invidious)) {
      final invResult = await _fetchFromSource(
        videoId,
        StreamSource.invidious,
        preferredQuality,
      );
      _recordAttempt(invResult);

      if (invResult.isSuccess) {
        debugPrint(
          'StreamLoader: Invidious fallback succeeded in ${stopwatch.elapsedMilliseconds}ms',
        );
        _recordSourceSuccess(StreamSource.invidious);
        return invResult.streamInfo!;
      } else {
        _recordSourceFailure(StreamSource.invidious);
      }
    } else {
      debugPrint('StreamLoader: Invidious circuit is OPEN; skipping.');
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
    _invalidatedVideoIds.remove(videoId);

    // Skip if already cached or prefetching
    if (_cache.isCached(videoId, preferredQuality) ||
        _prefetchQueue.containsKey(videoId)) {
      debugPrint(
        'StreamLoader: Skip prefetch for ${song.title} (already cached/queued)',
      );
      return;
    }

    debugPrint('StreamLoader: Prefetching ${song.title}');
    _prefetchQueue[videoId] = _fetchOptimized(song, preferredQuality)
        .then<StreamInfo?>((streamInfo) {
          if (!_invalidatedVideoIds.contains(videoId)) {
            _cache.cache(videoId, streamInfo, quality: preferredQuality);
            debugPrint('StreamLoader: Prefetch complete for ${song.title}');
          } else {
            debugPrint(
              'StreamLoader: Discarding late prefetch for invalidated $videoId',
            );
          }
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
    _invalidatedVideoIds.add(videoId);
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
