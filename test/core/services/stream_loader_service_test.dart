import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/providers/audio_stream_resolver.dart';
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
  });
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
