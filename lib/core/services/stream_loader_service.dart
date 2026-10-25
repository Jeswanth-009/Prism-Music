import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/stream_info.dart';
import '../../domain/entities/song.dart';
import '../../data/datasources/remote/youtube/youtube_music_datasource.dart';
import '../../data/datasources/remote/jiosaavn/jiosaavn_datasource.dart';
import '../providers/audio_stream_resolver.dart';
import '../providers/stream_resolvers.dart';
import 'instance_health_service.dart';
import 'stream_cache_service.dart';

/// Health status and metrics for an individual stream provider
class ProviderHealthStatus {
  final String resolverName;
  final String displayName;
  final bool isCircuitOpen;
  final bool isQuarantined;
  final int consecutiveErrors;
  final int averageLatencyMs;
  final double successRate;

  const ProviderHealthStatus({
    required this.resolverName,
    required this.displayName,
    required this.isCircuitOpen,
    required this.isQuarantined,
    required this.consecutiveErrors,
    required this.averageLatencyMs,
    required this.successRate,
  });
}

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
  final StreamCacheService _cache;
  final List<AudioStreamResolver> _resolvers;

  static const Duration _streamFetchTimeout = Duration(milliseconds: 4500);
  static const Duration _overallResolutionBudget = Duration(seconds: 12);

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

  StreamLoaderService(
    YouTubeMusicDataSource datasource,
    this._cache, {
    JioSaavnDataSource? jioSaavn,
    List<AudioStreamResolver>? resolvers,
  }) : _resolvers = resolvers ??
           [
             JioSaavnAudioStreamResolver(dataSource: jioSaavn ?? JioSaavnDataSourceImpl()),
             YouTubeExplodeAudioStreamResolver(dataSource: datasource),
             PipedAudioStreamResolver(),
             InvidiousAudioStreamResolver(),
           ];

  List<AudioStreamResolver> get resolvers => List.unmodifiable(_resolvers);

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
    String? preferredResolverName,
  }) async {
    final overallStopwatch = Stopwatch()..start();
    final videoId = song.playableId; // Use playableId (youtubeId ?? id)

    // Check cache first - instant return if available (unless explicitly requesting a specific resolver)
    if (useCache && preferredResolverName == null) {
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
    if (existingPrefetch != null && preferredResolverName == null) {
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
    debugPrint('StreamLoader: Loading stream for ${song.title} (preferred: $preferredResolverName)');
    final streamInfo = await _fetchOptimized(
      song,
      preferredQuality,
      preferredResolverName: preferredResolverName,
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
    AudioQuality preferredQuality, {
    String? preferredResolverName,
  }) async {
    final videoId = song.playableId;
    final stopwatch = Stopwatch()..start();

    final candidateResolvers = preferredResolverName != null
        ? [
            ..._resolvers.where((r) => r.resolverName == preferredResolverName),
            ..._resolvers.where((r) => r.resolverName != preferredResolverName),
          ]
        : _resolvers;

    for (final resolver in candidateResolvers) {
      if (!resolver.isAvailable) continue;
      final source = _mapResolverToSource(resolver.resolverName);
      final isExplicitUserChoice = resolver.resolverName == preferredResolverName;

      if (!isExplicitUserChoice && _isCircuitOpen(source)) {
        debugPrint('StreamLoader: ${resolver.resolverName} circuit is OPEN; skipping.');
        continue;
      }

      debugPrint('StreamLoader: Trying ${resolver.resolverName} resolver...');
      StreamInfo? stream;
      try {
        stream = await resolver
            .resolveStream(song, preferredQuality: preferredQuality)
            .timeout(_streamFetchTimeout);
      } catch (e) {
        debugPrint('StreamLoader: ${resolver.resolverName} failed or timed out: $e');
      }

      if (stream != null) {
        debugPrint(
          'StreamLoader: ${resolver.resolverName} succeeded in ${stopwatch.elapsedMilliseconds}ms',
        );
        _recordSourceSuccess(source);
        _recordAttempt(
          _FetchResult(
            source: source,
            streamInfo: stream,
            error: null,
            fetchTime: stopwatch.elapsed,
          ),
        );
        return stream;
      } else {
        _recordSourceFailure(source);
      }
    }

    stopwatch.stop();
    throw Exception('All stream sources failed to fetch $videoId');
  }

  StreamSource _mapResolverToSource(String resolverName) {
    switch (resolverName) {
      case 'jiosaavn':
        return StreamSource.jioSaavn;
      case 'youtube_explode':
        return StreamSource.youtubeExplode;
      case 'piped':
        return StreamSource.alternative;
      case 'invidious':
        return StreamSource.invidious;
      default:
        return StreamSource.alternative;
    }
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

  /// Explicitly resolves a stream from a specified resolver for comparison and safe source switching.
  Future<StreamInfo?> resolveCandidateStream(
    Song song,
    String resolverName, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    final resolver = _resolvers.cast<AudioStreamResolver?>().firstWhere(
          (r) => r?.resolverName == resolverName,
          orElse: () => null,
        );
    if (resolver == null || !resolver.isAvailable) return null;

    final stopwatch = Stopwatch()..start();
    final source = _mapResolverToSource(resolverName);
    try {
      final stream = await resolver
          .resolveStream(song, preferredQuality: preferredQuality)
          .timeout(_streamFetchTimeout);
      stopwatch.stop();

      if (stream != null) {
        _recordSourceSuccess(source);
        _recordAttempt(
          _FetchResult(
            source: source,
            streamInfo: stream,
            error: null,
            fetchTime: stopwatch.elapsed,
          ),
        );
      } else {
        _recordSourceFailure(source);
      }
      return stream;
    } catch (e) {
      stopwatch.stop();
      _recordSourceFailure(source);
      debugPrint('StreamLoader: Candidate resolution for $resolverName failed: $e');
      return null;
    }
  }

  /// Returns current diagnostics and health metrics for each registered audio provider.
  Map<String, ProviderHealthStatus> getProviderHealthSummary() {
    final healthService = InstanceHealthService();
    final instanceStats = healthService.getStats();
    final latencies = instanceStats['latencies'] as Map<String, int>? ?? {};
    final summary = <String, ProviderHealthStatus>{};

    for (final resolver in _resolvers) {
      final name = resolver.resolverName;
      final source = _mapResolverToSource(name);
      final isCircuitOpen = _isCircuitOpen(source);
      final consecutiveErrors = _consecutiveErrors[source] ?? 0;

      final attempts = _recentAttempts.where((a) => a.source == source).toList();
      final successes = attempts.where((a) => a.isSuccess).length;
      final rate = attempts.isEmpty ? 100.0 : (successes / attempts.length) * 100.0;
      final avgTime = attempts.isEmpty
          ? 120
          : (attempts.map((a) => a.fetchTime.inMilliseconds).reduce((a, b) => a + b) ~/
              attempts.length);

      String displayName;
      bool isQuarantined = false;

      switch (name) {
        case 'jiosaavn':
          displayName = 'JioSaavn 320kbps High-Fi';
          break;
        case 'youtube_explode':
          displayName = 'YouTube Direct DASH';
          break;
        case 'piped':
          displayName = 'Piped Audio Proxy Pool';
          isQuarantined = healthService.pipedProxyPool.any(healthService.isHostQuarantined);
          break;
        case 'invidious':
          displayName = 'Invidious Instance Network';
          isQuarantined = healthService.invidiousPool.any(healthService.isHostQuarantined);
          break;
        default:
          displayName = name;
      }

      int effectiveLatency = avgTime;
      if (name == 'piped' || name == 'invidious') {
        final hostLatencies = latencies.values;
        if (hostLatencies.isNotEmpty) {
          effectiveLatency = hostLatencies.reduce((a, b) => a + b) ~/ hostLatencies.length;
        }
      }

      summary[name] = ProviderHealthStatus(
        resolverName: name,
        displayName: displayName,
        isCircuitOpen: isCircuitOpen,
        isQuarantined: isQuarantined,
        consecutiveErrors: consecutiveErrors,
        averageLatencyMs: effectiveLatency,
        successRate: rate,
      );
    }

    return summary;
  }
}
