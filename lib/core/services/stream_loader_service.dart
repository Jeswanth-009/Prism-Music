import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/stream_info.dart';
import '../../domain/entities/song.dart';
import '../../data/datasources/remote/youtube/youtube_music_datasource.dart';
import '../../data/datasources/remote/jiosaavn/jiosaavn_datasource.dart';
import '../providers/audio_stream_resolver.dart';
import '../providers/innertube/innertube_stream_resolver.dart';
import '../providers/stream_resolvers.dart';
import '../error/exceptions.dart';
import 'instance_health_service.dart';
import 'playback_reliability_service.dart';
import 'stream_cache_service.dart';

export 'playback_reliability_service.dart' show StreamSource;

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

/// Production-ready stream loader with caching, circuit breakers, and
/// staggered hedging race resolution across audio providers.
class StreamLoaderService {
  final StreamCacheService _cache;
  final List<AudioStreamResolver> _resolvers;

  static const Duration _streamFetchTimeout = Duration(milliseconds: 9000);
  static const Duration _overallResolutionBudget = Duration(seconds: 22);

  /// How long the best-ranked resolver runs alone before the next one is
  /// started alongside it. See [_raceResolvers].
  static const Duration defaultHedgeDelay = Duration(seconds: 2);
  final Duration _hedgeDelay;

  final PlaybackReliabilityService _reliability;
  PlaybackReliabilityService get reliability => _reliability;

  final StreamController<GeoRestrictionException> _geoRestrictionController =
      StreamController<GeoRestrictionException>.broadcast();

  /// Emits whenever an audio provider resolution fails due to regional geo-restrictions.
  Stream<GeoRestrictionException> get onGeoRestrictionDetected =>
      _geoRestrictionController.stream;

  // Set of videoIds invalidated while prefetching was in-flight
  final Set<String> _invalidatedVideoIds = {};

  // Prefetch queue to load next songs in background
  final Map<String, Future<StreamInfo?>> _prefetchQueue = {};

  // Track fetch attempts for analytics
  final List<_FetchResult> _recentAttempts = [];
  static const int _maxRecentAttempts = 20;

  // Per-song resolvers that already failed during playback and should be skipped
  // on failover retries so playback switches to healthy alternatives (e.g. InnerTube).
  final Map<String, Set<String>> _excludedResolversBySong = {};

  StreamLoaderService(
    YouTubeMusicDataSource datasource,
    this._cache, {
    JioSaavnDataSource? jioSaavn,
    List<AudioStreamResolver>? resolvers,
    PlaybackReliabilityService? reliability,
    Duration hedgeDelay = defaultHedgeDelay,
  }) : _reliability = reliability ?? PlaybackReliabilityService(),
       _hedgeDelay = hedgeDelay,
       _resolvers = resolvers ??
           [
             JioSaavnAudioStreamResolver(dataSource: jioSaavn ?? JioSaavnDataSourceImpl()),
             YouTubeExplodeAudioStreamResolver(dataSource: datasource),
             InnerTubeStreamResolver(),
             PipedAudioStreamResolver(),
             InvidiousAudioStreamResolver(),
           ];

  List<AudioStreamResolver> get resolvers => List.unmodifiable(_resolvers);

  bool _isCircuitOpen(StreamSource source) =>
      _reliability.isSourceCircuitOpen(source);

  void _recordSourceSuccess(StreamSource source) =>
      _reliability.recordSourceSuccess(source);

  void _recordSourceFailure(StreamSource source) =>
      _reliability.recordSourceFailure(source);

  /// Maps a [StreamInfo.streamProvenance] tag back to its owning resolver name.
  static String? resolverNameForProvenance(String? provenance) {
    if (provenance == null || provenance.isEmpty) return null;
    if (provenance == 'jiosaavn' || provenance.contains('jiosaavn')) {
      return 'jiosaavn';
    }
    if (provenance == 'youtube_explode' || provenance == 'youtube') {
      return 'youtube_explode';
    }
    if (provenance.startsWith('innertube')) {
      return 'innertube_ladder';
    }
    if (provenance == 'piped' || provenance.contains('piped')) {
      return 'piped';
    }
    if (provenance == 'invidious' || provenance.contains('invidious')) {
      return 'invidious';
    }
    return provenance;
  }

  /// Marks the resolver behind [streamProvenance] as failed for [videoId] at
  /// playback time, records a source failure, and evicts stale cache/prefetch.
  void markResolverFailedForPlayback(String videoId, String? streamProvenance) {
    final resolverName = resolverNameForProvenance(streamProvenance);
    if (resolverName == null || resolverName.isEmpty) return;
    (_excludedResolversBySong[videoId] ??= <String>{}).add(resolverName);
    _recordSourceFailure(_mapResolverToSource(resolverName));
    invalidateCache(videoId);
    debugPrint(
      'StreamLoader: Excluded resolver "$resolverName" for $videoId after playback failure',
    );
  }

  /// Clears playback-time resolver exclusions for [videoId].
  void clearExcludedResolvers(String videoId) {
    _excludedResolversBySong.remove(videoId);
  }

  /// Whether at least one enabled resolver remains for [videoId] after
  /// excluding resolvers that already failed during playback.
  bool hasUntriedResolvers(String videoId) {
    final excluded = _excludedResolversBySong[videoId];
    if (excluded == null || excluded.isEmpty) return true;
    return _resolvers.any(
      (r) =>
          r.isAvailable &&
          !excluded.contains(r.resolverName) &&
          !_isCircuitOpen(_mapResolverToSource(r.resolverName)),
    );
  }

  /// Resolves a stream while explicitly excluding [excludedResolvers]
  /// (used e.g. by YouTube fallback so it skips JioSaavn/YouTubeExplode).
  Future<StreamInfo> loadStreamExcluding(
    Song song, {
    required Set<String> excludedResolvers,
    bool useCache = true,
    AudioQuality preferredQuality = AudioQuality.high,
  }) {
    return _loadStreamInternal(
      song,
      useCache: useCache,
      preferredQuality: preferredQuality,
      explicitExcludedResolvers: excludedResolvers,
    );
  }

  /// Resolves the stream URL using cache checks, circuit breakers, and
  /// staggered-race resolution across eligible resolvers (or sequential fallback
  /// when an explicit resolver is preferred).
  Future<StreamInfo> loadStream(
    Song song, {
    bool useCache = true,
    AudioQuality preferredQuality = AudioQuality.high,
    String? preferredResolverName,
  }) =>
      _loadStreamInternal(
        song,
        useCache: useCache,
        preferredQuality: preferredQuality,
        preferredResolverName: preferredResolverName,
      );

  Future<StreamInfo> _loadStreamInternal(
    Song song, {
    bool useCache = true,
    AudioQuality preferredQuality = AudioQuality.high,
    String? preferredResolverName,
    Set<String>? explicitExcludedResolvers,
  }) async {
    final overallStopwatch = Stopwatch()..start();
    final videoId = song.playableId; // Use playableId (youtubeId ?? id)
    final excluded = <String>{
      if (preferredResolverName == null)
        ...?_excludedResolversBySong[videoId],
      ...?explicitExcludedResolvers,
    };

    bool isAllowedCached(StreamInfo stream) {
      if (excluded.isEmpty) return true;
      final provResolver = resolverNameForProvenance(stream.streamProvenance);
      return provResolver == null || !excluded.contains(provResolver);
    }

    // Check cache first - instant return if available (unless explicitly requesting a specific resolver)
    if (useCache && preferredResolverName == null) {
      final cached = _cache.getCached(videoId, preferredQuality);
      if (cached != null && isAllowedCached(cached)) {
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
        if (result != null && isAllowedCached(result)) {
          // The stream may have been invalidated (e.g. a 403 expiry recovery)
          // while the prefetch was in flight; serving that result here would
          // hand back exactly the stale URL the invalidation tried to drop.
          if (_invalidatedVideoIds.contains(videoId)) {
            debugPrint(
              'StreamLoader: Prefetch result for ${song.title} was '
              'invalidated while waiting; fetching fresh',
            );
          } else {
            overallStopwatch.stop();
            debugPrint(
              'StreamLoader: Using prefetched stream for ${song.title} '
              '(${overallStopwatch.elapsedMilliseconds}ms)',
            );
            return result;
          }
        }
      } catch (e) {
        debugPrint('StreamLoader: Prefetch failed, fetching fresh: $e');
      }
    }

    // Fetch with bounded overall resolution budget
    debugPrint(
      'StreamLoader: Loading stream for ${song.title} '
      '(preferred: $preferredResolverName, excluded: $excluded)',
    );
    final streamInfo = await _fetchOptimized(
      song,
      preferredQuality,
      preferredResolverName: preferredResolverName,
      excludedResolvers: excluded,
    ).timeout(
      _overallResolutionBudget,
      onTimeout: () =>
          throw TimeoutException('Overall stream resolution budget (22s) exceeded for $videoId'),
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

  /// Resolves a stream for [song].
  ///
  /// Resolvers are ranked by priority. Normally they are raced with a stagger
  /// (see [_raceResolvers]): a slow or hung resolver no longer holds playback
  /// up for its whole timeout. An explicit [preferredResolverName] is a user
  /// choice and keeps the strict "preferred first, then fall back" order.
  Future<StreamInfo> _fetchOptimized(
    Song song,
    AudioQuality preferredQuality, {
    String? preferredResolverName,
    Set<String> excludedResolvers = const {},
  }) async {
    final videoId = song.playableId;
    final stopwatch = Stopwatch()..start();

    final List<AudioStreamResolver> orderedResolvers;
    if (preferredResolverName != null) {
      final preferred = _resolvers.where((r) => r.resolverName == preferredResolverName);
      final nonPreferred = _resolvers.where((r) => r.resolverName != preferredResolverName);
      // When explicitly switching to a YouTube-family resolver, try the rest of
      // the YouTube/relay ladder before circling back to JioSaavn.
      final isExplicitYouTube = preferredResolverName != 'jiosaavn';
      orderedResolvers = isExplicitYouTube
          ? [
              ...preferred,
              ...nonPreferred.where((r) => r.resolverName != 'jiosaavn'),
              ...nonPreferred.where((r) => r.resolverName == 'jiosaavn'),
            ]
          : [...preferred, ...nonPreferred];
    } else {
      orderedResolvers = _resolvers;
    }

    final candidateResolvers = excludedResolvers.isEmpty
        ? orderedResolvers
        : orderedResolvers
            .where((r) => !excludedResolvers.contains(r.resolverName))
            .toList();

    if (preferredResolverName == null) {
      final eligible = <AudioStreamResolver>[];
      for (final resolver in candidateResolvers) {
        if (!resolver.isAvailable) continue;
        final source = _mapResolverToSource(resolver.resolverName);
        if (_isCircuitOpen(source)) {
          debugPrint('StreamLoader: ${resolver.resolverName} circuit is OPEN; skipping.');
          continue;
        }
        eligible.add(resolver);
      }
      // With fewer than two usable resolvers there is nothing to race.
      if (eligible.length > 1) {
        return _raceResolvers(song, preferredQuality, eligible, stopwatch);
      }
    }

    for (final resolver in candidateResolvers) {
      if (!resolver.isAvailable) continue;
      final source = _mapResolverToSource(resolver.resolverName);
      final isExplicitUserChoice = resolver.resolverName == preferredResolverName;

      if (!isExplicitUserChoice && _isCircuitOpen(source)) {
        debugPrint('StreamLoader: ${resolver.resolverName} circuit is OPEN; skipping.');
        continue;
      }

      debugPrint('StreamLoader: Trying ${resolver.resolverName} resolver...');
      final stream = await _attemptResolver(resolver, song, preferredQuality);

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

  /// Runs a single [resolver], bounded by [_streamFetchTimeout].
  ///
  /// Never throws: any failure (including a timeout) yields `null`, and a
  /// geo-restriction is additionally reported on [onGeoRestrictionDetected].
  Future<StreamInfo?> _attemptResolver(
    AudioStreamResolver resolver,
    Song song,
    AudioQuality preferredQuality,
  ) async {
    try {
      return await resolver
          .resolveStream(song, preferredQuality: preferredQuality)
          .timeout(_streamFetchTimeout);
    } catch (e) {
      if (e is GeoRestrictionException) {
        debugPrint('StreamLoader: ${resolver.resolverName} hit geo-restriction: $e');
        // A resolver that loses a race can fail after dispose().
        if (!_geoRestrictionController.isClosed) {
          _geoRestrictionController.add(e);
        }
      }
      debugPrint('StreamLoader: ${resolver.resolverName} failed or timed out: $e');
      return null;
    }
  }

  /// Starts [candidates] in priority order, staggered by [_hedgeDelay], and
  /// completes with the first stream any of them resolves.
  ///
  /// The best-ranked resolver runs alone for [_hedgeDelay]. If it has neither
  /// answered nor failed by then, the next one is started alongside it, and so
  /// on down the list. A resolver that fails or finds no match starts the next
  /// one immediately. A healthy primary therefore behaves exactly like a
  /// sequential loop (the others are never contacted), while a slow or hung one
  /// no longer costs its full timeout before the fallback even begins.
  ///
  /// Resolvers that lose the race keep running until they finish or time out.
  /// Their streams are discarded, but their outcomes still feed the circuit
  /// breakers: a primary that is persistently too slow to win must still get
  /// its circuit opened, otherwise every track would keep paying the hedge
  /// delay for it.
  Future<StreamInfo> _raceResolvers(
    Song song,
    AudioQuality preferredQuality,
    List<AudioStreamResolver> candidates,
    Stopwatch stopwatch,
  ) {
    final completer = Completer<StreamInfo>();
    Timer? hedgeTimer;
    var launched = 0;
    var failures = 0;

    void launchNext() {
      if (completer.isCompleted || launched >= candidates.length) return;
      hedgeTimer?.cancel();

      final resolver = candidates[launched++];
      final source = _mapResolverToSource(resolver.resolverName);
      debugPrint('StreamLoader: Trying ${resolver.resolverName} resolver...');

      _attemptResolver(resolver, song, preferredQuality).then((stream) {
        // Health tracking covers every resolver, winner or not.
        if (stream != null) {
          _recordSourceSuccess(source);
        } else {
          _recordSourceFailure(source);
        }
        if (completer.isCompleted) return; // another resolver already won

        if (stream != null) {
          hedgeTimer?.cancel();
          debugPrint(
            'StreamLoader: ${resolver.resolverName} succeeded in ${stopwatch.elapsedMilliseconds}ms',
          );
          _recordAttempt(
            _FetchResult(
              source: source,
              streamInfo: stream,
              error: null,
              fetchTime: stopwatch.elapsed,
            ),
          );
          completer.complete(stream);
          return;
        }

        failures++;
        if (launched < candidates.length) {
          launchNext(); // fail over right away instead of waiting for the hedge
        } else if (failures >= candidates.length) {
          hedgeTimer?.cancel();
          completer.completeError(
            Exception('All stream sources failed to fetch ${song.playableId}'),
          );
        }
      });

      if (launched < candidates.length) {
        hedgeTimer = Timer(_hedgeDelay, launchNext);
      }
    }

    launchNext();
    return completer.future;
  }

  StreamSource _mapResolverToSource(String resolverName) {
    switch (resolverName) {
      case 'jiosaavn':
        return StreamSource.jioSaavn;
      case 'youtube_explode':
        return StreamSource.youtubeExplode;
      case 'innertube_ladder':
        return StreamSource.innerTube;
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

  /// Check if cached stream for [song] is fresh (both TTL and URL expiry).
  /// Proactively invalidates cache if stale.
  bool isStreamFresh(Song song, {AudioQuality preferredQuality = AudioQuality.high}) {
    return _cache.isFresh(song.playableId, preferredQuality);
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
      if (e is GeoRestrictionException) {
        _geoRestrictionController.add(e);
      }
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
      final consecutiveErrors = _reliability.getSourceConsecutiveErrors(source);

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
        case 'innertube_ladder':
          displayName = 'YouTube InnerTube Direct';
          break;
        case 'piped':
          displayName = 'Piped Audio Proxy Pool';
          isQuarantined = !healthService.hasHealthyPipedApi;
          break;
        case 'invidious':
          displayName = 'Invidious Instance Network';
          isQuarantined = !healthService.hasHealthyInvidious;
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

  void dispose() {
    _geoRestrictionController.close();
  }
}
