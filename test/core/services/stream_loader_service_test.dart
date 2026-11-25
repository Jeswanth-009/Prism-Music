import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/providers/audio_stream_resolver.dart';
import 'package:prism_music/core/services/playback_reliability_service.dart';
import 'package:prism_music/core/services/stream_cache_service.dart';
import 'package:prism_music/core/services/stream_loader_service.dart';
import 'package:prism_music/data/datasources/remote/jiosaavn/jiosaavn_datasource.dart';
import 'package:prism_music/data/datasources/remote/youtube/youtube_music_datasource.dart';
import 'package:prism_music/domain/entities/song.dart';
import 'package:prism_music/domain/entities/stream_info.dart';

class MockYouTubeMusicDataSource implements YouTubeMusicDataSource {
  int getStreamUrlCalls = 0;
  StreamInfo? streamResult;
  Exception? streamError;

  @override
  Future<StreamInfo> getStreamUrl(
    String videoId, {
    AudioQuality preferredQuality = AudioQuality.high,
    bool forceRefresh = false,
  }) async {
    getStreamUrlCalls++;
    if (streamError != null) throw streamError!;
    return streamResult ??
        StreamInfo(
          url: 'https://youtube.cdn.example/audio.opus',
          codec: 'opus',
          bitrate: 160,
          container: 'webm',
          quality: preferredQuality,
          streamProvenance: 'youtube_explode',
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockJioSaavnDataSource implements JioSaavnDataSource {
  int getStreamUrlCalls = 0;
  StreamInfo? streamResult;
  Exception? streamError;

  @override
  Future<StreamInfo?> getStreamUrl(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    getStreamUrlCalls++;
    if (streamError != null) throw streamError!;
    return streamResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('StreamLoaderService', () {
    late StreamCacheService cache;
    late MockYouTubeMusicDataSource mockYt;
    late MockJioSaavnDataSource mockJio;
    late StreamLoaderService loader;

    final testSong = Song(
      id: 'test_123',
      title: 'Kesariya',
      artist: 'Arijit Singh',
      duration: const Duration(seconds: 240),
      thumbnails: const Thumbnails(),
      source: MusicSource.youtube,
      youtubeId: 'test_123',
    );

    setUp(() {
      cache = StreamCacheService();
      mockYt = MockYouTubeMusicDataSource();
      mockJio = MockJioSaavnDataSource();
      loader = StreamLoaderService(mockYt, cache, jioSaavn: mockJio);
    });

    test('returns cached stream immediately without calling any datasource', () async {
      final cachedStream = StreamInfo(
        url: 'https://cached.cdn.example/song.mp4',
        codec: 'mp4a',
        bitrate: 320,
        container: 'm4a',
        quality: AudioQuality.high,
      );
      cache.cache(testSong.playableId, cachedStream, quality: AudioQuality.high);

      final result = await loader.loadStream(testSong);

      expect(result.url, equals('https://cached.cdn.example/song.mp4'));
      expect(mockJio.getStreamUrlCalls, equals(0));
      expect(mockYt.getStreamUrlCalls, equals(0));
    });

    test('prioritizes JioSaavn high-confidence stream when available', () async {
      mockJio.streamResult = StreamInfo(
        url: 'https://jio.cdn.example/song.m4a',
        codec: 'mp4a',
        bitrate: 320,
        container: 'm4a',
        quality: AudioQuality.high,
        streamProvenance: 'jiosaavn_matched',
        matchConfidence: 0.95,
      );

      final result = await loader.loadStream(testSong);

      expect(result.url, equals('https://jio.cdn.example/song.m4a'));
      expect(result.streamProvenance, equals('jiosaavn_matched'));
      expect(result.matchConfidence, equals(0.95));
      expect(mockJio.getStreamUrlCalls, equals(1));
      expect(mockYt.getStreamUrlCalls, equals(0));
      // Verify stored in cache
      expect(cache.isCached(testSong.playableId, AudioQuality.high), isTrue);
    });

    test('falls back cleanly to YouTube Explode when JioSaavn returns null', () async {
      mockJio.streamResult = null; // No match
      mockYt.streamResult = StreamInfo(
        url: 'https://rr2---sn.googlevideo.com/videoplayback',
        codec: 'opus',
        bitrate: 160,
        container: 'webm',
        quality: AudioQuality.high,
      );

      final result = await loader.loadStream(testSong);

      expect(result.url, contains('googlevideo.com'));
      expect(mockJio.getStreamUrlCalls, equals(1));
      expect(mockYt.getStreamUrlCalls, equals(1));
    });

    test('circuit breaker trips after consecutive failures and skips provider', () async {
      mockJio.streamError = Exception('JioSaavn 503 Outage');

      // 3 consecutive calls
      for (int i = 0; i < 3; i++) {
        await loader.loadStream(testSong, useCache: false);
      }
      expect(mockJio.getStreamUrlCalls, equals(3));
      expect(mockYt.getStreamUrlCalls, equals(3));

      // 4th call: JioSaavn circuit should now be open, skipping it entirely
      await loader.loadStream(testSong, useCache: false);
      expect(mockJio.getStreamUrlCalls, equals(3)); // Still 3!
      expect(mockYt.getStreamUrlCalls, equals(4));   // YT Explode served directly
    });

    test('cache invalidation clears cached entry and pending state', () async {
      final stream = StreamInfo(
        url: 'https://yt.example/stream',
        codec: 'opus',
        bitrate: 160,
        container: 'webm',
        quality: AudioQuality.high,
      );
      cache.cache(testSong.playableId, stream);
      expect(cache.isCached(testSong.playableId), isTrue);

      loader.invalidateCache(testSong.playableId);
      expect(cache.isCached(testSong.playableId), isFalse);
    });

    test('supports custom injected AudioStreamResolver pipeline', () async {
      final customResolver = _FakeCustomResolver();
      final customLoader = StreamLoaderService(
        mockYt,
        cache,
        resolvers: [customResolver],
      );

      final result = await customLoader.loadStream(testSong, useCache: false);
      expect(result.url, equals('https://custom.stream/audio.mp3'));
      expect(result.streamProvenance, equals('custom_provider'));
      expect(customResolver.calls, equals(1));
    });

    test('unified stream cache: YouTubeMusicDataSourceImpl integrates with StreamCacheService', () async {
      final sharedCache = StreamCacheService();
      final ytSource = YouTubeMusicDataSourceImpl(cache: sharedCache);

      // Seed cache via shared cache service
      const seededStream = StreamInfo(
        url: 'https://cdn.example/cached.mp4',
        codec: 'mp4a',
        bitrate: 128,
        container: 'mp4',
        quality: AudioQuality.high,
      );
      sharedCache.cache('video_abc', seededStream, quality: AudioQuality.high);

      // Querying without forceRefresh returns cached stream without network call
      final hit = await ytSource.getStreamUrl('video_abc', preferredQuality: AudioQuality.high);
      expect(hit.url, equals('https://cdn.example/cached.mp4'));

      // Invalidation clears the unified entry
      sharedCache.invalidate('video_abc');
      expect(sharedCache.isCached('video_abc'), isFalse);
    });

    test('prioritizes preferredResolverName over default sequence', () async {
      mockJio.streamResult = const StreamInfo(
        url: 'https://jio.stream/audio.mp4',
        codec: 'mp4a',
        bitrate: 320,
        container: 'mp4',
        quality: AudioQuality.high,
        streamProvenance: 'jiosaavn_matched',
      );
      mockYt.streamResult = const StreamInfo(
        url: 'https://youtube.stream/audio.opus',
        codec: 'opus',
        bitrate: 160,
        container: 'webm',
        quality: AudioQuality.high,
        streamProvenance: 'youtube_explode',
      );

      // Without preferredResolver, JioSaavn runs first
      final defaultResult = await loader.loadStream(testSong, useCache: false);
      expect(defaultResult.streamProvenance, equals('jiosaavn_matched'));

      // With preferredResolver 'youtube_explode', YouTube runs first even though Jio is available
      final forcedResult = await loader.loadStream(
        testSong,
        useCache: false,
        preferredResolverName: 'youtube_explode',
      );
      expect(forcedResult.streamProvenance, equals('youtube_explode'));
    });

    test('markResolverFailedForPlayback excludes failing provenance on subsequent loadStream', () async {
      mockJio.streamResult = const StreamInfo(
        url: 'https://jio.stream/broken.mp4',
        codec: 'mp4a',
        bitrate: 320,
        container: 'mp4',
        quality: AudioQuality.high,
        streamProvenance: 'jiosaavn_matched',
      );
      mockYt.streamResult = const StreamInfo(
        url: 'https://innertube.stream/audio.mp4',
        codec: 'mp4a',
        bitrate: 128,
        container: 'mp4',
        quality: AudioQuality.high,
        streamProvenance: 'innertube_android',
      );

      final first = await loader.loadStream(testSong);
      expect(first.streamProvenance, equals('jiosaavn_matched'));
      expect(loader.hasUntriedResolvers(testSong.playableId), isTrue);

      // Simulate ExoPlayer failing to play the JioSaavn stream.
      loader.markResolverFailedForPlayback(
        testSong.playableId,
        first.streamProvenance,
      );
      expect(loader.hasUntriedResolvers(testSong.playableId), isTrue);

      // Subsequent resolution must skip jiosaavn & cache and fail over to YT/InnerTube.
      final second = await loader.loadStream(testSong);
      expect(second.streamProvenance, equals('innertube_android'));
      expect(mockJio.getStreamUrlCalls, equals(1));
      expect(mockYt.getStreamUrlCalls, equals(1));

      // loadStreamExcluding also honors explicit exclusions.
      mockYt.streamResult = const StreamInfo(
        url: 'https://direct.example/fallback.mp4',
        codec: 'mp4a',
        bitrate: 128,
        container: 'mp4',
        quality: AudioQuality.high,
        streamProvenance: 'youtube_explode',
      );
      final excl = await loader.loadStreamExcluding(
        testSong,
        excludedResolvers: const {'jiosaavn'},
        useCache: false,
      );
      expect(excl.streamProvenance, equals('youtube_explode'));
      expect(mockJio.getStreamUrlCalls, equals(1));
    });
  });

  group('StreamLoaderService resolver racing', () {
    late StreamCacheService cache;
    late MockYouTubeMusicDataSource mockYt;
    late PlaybackReliabilityService reliability;

    const jioStream = StreamInfo(
      url: 'https://jio.cdn.example/song.m4a',
      codec: 'mp4a',
      bitrate: 320,
      container: 'm4a',
      quality: AudioQuality.high,
      streamProvenance: 'jiosaavn_matched',
    );
    const ytStream = StreamInfo(
      url: 'https://rr1---sn.googlevideo.com/videoplayback',
      codec: 'opus',
      bitrate: 160,
      container: 'webm',
      quality: AudioQuality.high,
      streamProvenance: 'youtube_explode',
    );

    final testSong = Song(
      id: 'race_123',
      title: 'Kesariya',
      artist: 'Arijit Singh',
      duration: const Duration(seconds: 240),
      thumbnails: const Thumbnails(),
      source: MusicSource.youtube,
      youtubeId: 'race_123',
    );

    StreamLoaderService buildLoader(
      List<AudioStreamResolver> resolvers, {
      Duration hedgeDelay = const Duration(milliseconds: 40),
    }) {
      return StreamLoaderService(
        mockYt,
        cache,
        reliability: reliability,
        resolvers: resolvers,
        hedgeDelay: hedgeDelay,
      );
    }

    setUp(() {
      cache = StreamCacheService();
      mockYt = MockYouTubeMusicDataSource();
      reliability = PlaybackReliabilityService();
    });

    test('starts the fallback after the hedge delay when the primary is slow',
        () async {
      final slowPrimary = _ScriptedResolver(
        'jiosaavn',
        delay: const Duration(seconds: 3),
        result: jioStream,
      );
      final fastFallback =
          _ScriptedResolver('youtube_explode', result: ytStream);
      final loader = buildLoader([slowPrimary, fastFallback]);

      final stopwatch = Stopwatch()..start();
      final result = await loader.loadStream(testSong, useCache: false);
      stopwatch.stop();

      // The fallback won without waiting for the slow primary to finish.
      expect(result.streamProvenance, equals('youtube_explode'));
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      expect(slowPrimary.calls, equals(1));
      expect(fastFallback.calls, equals(1));
    });

    test('never contacts the fallbacks when the primary answers in time',
        () async {
      final primary = _ScriptedResolver('jiosaavn', result: jioStream);
      final fallback = _ScriptedResolver('youtube_explode', result: ytStream);
      final loader = buildLoader([primary, fallback]);

      final result = await loader.loadStream(testSong, useCache: false);
      // Wait well past the hedge delay: a leaked hedge timer would fire now.
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(result.streamProvenance, equals('jiosaavn_matched'));
      expect(primary.calls, equals(1));
      expect(fallback.calls, equals(0));
    });

    test('fails over immediately when the primary finds no match', () async {
      final primary = _ScriptedResolver('jiosaavn'); // resolves to null
      final fallback = _ScriptedResolver('youtube_explode', result: ytStream);
      // A hedge delay this long would dominate the run time if the loader
      // waited for it instead of failing over right away.
      final loader = buildLoader(
        [primary, fallback],
        hedgeDelay: const Duration(seconds: 30),
      );

      final stopwatch = Stopwatch()..start();
      final result = await loader.loadStream(testSong, useCache: false);
      stopwatch.stop();

      expect(result.streamProvenance, equals('youtube_explode'));
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      expect(primary.calls, equals(1));
      expect(fallback.calls, equals(1));
    });

    test('walks the whole priority list when earlier resolvers fail',
        () async {
      final first = _ScriptedResolver('jiosaavn');
      final second = _ScriptedResolver('youtube_explode', shouldThrow: true);
      final third = _ScriptedResolver('piped', result: ytStream);
      final loader = buildLoader([first, second, third]);

      final result = await loader.loadStream(testSong, useCache: false);

      expect(result.url, equals(ytStream.url));
      expect(first.calls, equals(1));
      expect(second.calls, equals(1));
      expect(third.calls, equals(1));
    });

    test('throws once every resolver has failed', () async {
      final first = _ScriptedResolver('jiosaavn');
      final second = _ScriptedResolver('youtube_explode', shouldThrow: true);
      final loader = buildLoader([first, second]);

      await expectLater(
        loader.loadStream(testSong, useCache: false),
        throwsA(isA<Exception>()),
      );
      expect(first.calls, equals(1));
      expect(second.calls, equals(1));
    });

    test('an explicit preferred resolver is tried alone first, not raced',
        () async {
      final jio = _ScriptedResolver('jiosaavn', result: jioStream);
      final yt = _ScriptedResolver(
        'youtube_explode',
        delay: const Duration(milliseconds: 150),
        result: ytStream,
      );
      final loader = buildLoader(
        [jio, yt],
        hedgeDelay: const Duration(milliseconds: 10),
      );

      final result = await loader.loadStream(
        testSong,
        useCache: false,
        preferredResolverName: 'youtube_explode',
      );

      // The user's choice is honored even though JioSaavn would have won a race.
      expect(result.streamProvenance, equals('youtube_explode'));
      expect(jio.calls, equals(0));
      expect(yt.calls, equals(1));
    });

    test('a persistently slow primary still trips its circuit and is skipped',
        () async {
      // Never wins: always answers "no match", but only after the race is over.
      final slowPrimary = _ScriptedResolver(
        'jiosaavn',
        delay: const Duration(milliseconds: 120),
      );
      final fallback = _ScriptedResolver('youtube_explode', result: ytStream);
      final loader = buildLoader(
        [slowPrimary, fallback],
        hedgeDelay: const Duration(milliseconds: 20),
      );

      for (var i = 0; i < 3; i++) {
        final result = await loader.loadStream(testSong, useCache: false);
        expect(result.streamProvenance, equals('youtube_explode'));
        // Let the primary's late failure arrive after the race was decided.
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      // Late failures of race losers still feed the circuit breaker...
      expect(reliability.isSourceCircuitOpen(StreamSource.jioSaavn), isTrue);

      // ...so the dead primary is no longer contacted at all.
      final callsBefore = slowPrimary.calls;
      await loader.loadStream(testSong, useCache: false);
      expect(slowPrimary.calls, equals(callsBefore));
    });

    test('never returns a prefetch result invalidated while waiting', () async {
      // The in-flight prefetch resolves to a URL that is invalidated (e.g.
      // by a 403 expiry recovery) before the awaiting load can consume it.
      final staleStream = StreamInfo(
        url: 'https://stale.cdn.example/videoplayback',
        codec: 'opus',
        bitrate: 160,
        container: 'webm',
        quality: AudioQuality.high,
        streamProvenance: 'youtube_explode',
      );
      final fallback = _ScriptedResolver(
        'youtube_explode',
        delay: const Duration(milliseconds: 120),
        results: [staleStream, ytStream],
      );
      final primary = _ScriptedResolver('jiosaavn'); // never matches
      final loader = buildLoader([primary, fallback]);

      // Warm the song in the background.
      loader.prefetch(testSong);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // A real load attaches to the in-flight prefetch...
      final loadFuture = loader.loadStream(testSong, useCache: false);
      // ...and the song is invalidated while that load is waiting on it.
      loader.invalidateCache(testSong.playableId);

      final result = await loadFuture;

      // The stale prefetch result must be discarded, not served.
      expect(result.url, equals(ytStream.url));
      expect(fallback.calls, equals(2));
    });
  });
}

/// Scripted [AudioStreamResolver]: optionally waits [delay], then either
/// throws, or resolves to [result] (null means "no match"). A [results]
/// queue hands out one entry per call, falling back to [result] once empty.
class _ScriptedResolver implements AudioStreamResolver {
  _ScriptedResolver(
    this.resolverName, {
    this.delay = Duration.zero,
    this.result,
    this.shouldThrow = false,
    List<StreamInfo?>? results,
  }) : _results = results;

  @override
  final String resolverName;
  final Duration delay;
  final StreamInfo? result;
  final bool shouldThrow;
  final List<StreamInfo?>? _results;
  int _resultIndex = 0;
  int calls = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<StreamInfo?> resolveStream(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    calls++;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (shouldThrow) {
      throw Exception('$resolverName failed');
    }
    final queue = _results;
    if (queue != null && _resultIndex < queue.length) {
      return queue[_resultIndex++];
    }
    return result;
  }
}

class _FakeCustomResolver implements AudioStreamResolver {
  int calls = 0;

  @override
  String get resolverName => 'custom';

  @override
  bool get isAvailable => true;

  @override
  Future<StreamInfo?> resolveStream(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    calls++;
    return const StreamInfo(
      url: 'https://custom.stream/audio.mp3',
      codec: 'mp3',
      bitrate: 320,
      container: 'mp3',
      quality: AudioQuality.high,
      streamProvenance: 'custom_provider',
    );
  }
}
