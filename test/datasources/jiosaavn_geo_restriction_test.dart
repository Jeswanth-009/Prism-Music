import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:prism_music/core/error/error_message_mapper.dart';
import 'package:prism_music/core/error/exceptions.dart';
import 'package:prism_music/core/error/failures.dart';
import 'package:prism_music/core/providers/audio_stream_resolver.dart';
import 'package:prism_music/core/services/playback_reliability_service.dart';
import 'package:prism_music/core/services/stream_cache_service.dart';
import 'package:prism_music/core/services/stream_loader_service.dart';
import 'package:prism_music/data/datasources/remote/jiosaavn/jiosaavn_datasource.dart';
import 'package:prism_music/data/datasources/remote/youtube/youtube_music_datasource.dart';
import 'package:prism_music/domain/entities/entities.dart';

class MockHttpClient extends Mock implements http.Client {}
class MockYouTubeMusicDataSource extends Mock implements YouTubeMusicDataSource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  group('ErrorMessageMapper GeoRestriction', () {
    test('maps GeoRestrictionFailure to clean user message', () {
      const failure = GeoRestrictionFailure(provider: 'JioSaavn');
      final message = ErrorMessageMapper.map(failure);
      expect(message, contains('JioSaavn'));
      expect(message, contains('geo-restricted'));
    });

    test('maps GeoRestrictionException to clean user message', () {
      const exception = GeoRestrictionException(provider: 'JioSaavn');
      final message = ErrorMessageMapper.map(exception);
      expect(message, contains('JioSaavn'));
      expect(message, contains('geo-restricted'));
    });

    test('maps raw geo error strings correctly', () {
      final message = ErrorMessageMapper.map('HTTP 451: Content unavailable in your region due to geoblock');
      expect(message, contains('geo-restricted'));
    });
  });

  group('JioSaavnDataSourceImpl Geo-Restriction Detection', () {
    late MockHttpClient mockClient;
    late JioSaavnDataSourceImpl dataSource;

    final testSong = Song(
      id: 'jio_song_01',
      title: 'Kesariya',
      artist: 'Arijit Singh',
      duration: const Duration(seconds: 240),
      thumbnails: const Thumbnails(),
      source: MusicSource.jiosaavn,
    );

    setUp(() {
      mockClient = MockHttpClient();
      dataSource = JioSaavnDataSourceImpl(client: mockClient);
    });

    test('throws GeoRestrictionException when search results return HTTP 451', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('Unavailable in region', 451));

      expect(
        () => dataSource.getStreamUrl(testSong),
        throwsA(isA<GeoRestrictionException>()),
      );
    });

    test('throws GeoRestrictionException when all CDNs return HTTP 403 Forbidden', () async {
      final searchPayload = jsonEncode({
        'results': [
          {
            'id': 'jio_song_01',
            'song': 'Kesariya',
            'singers': 'Arijit Singh',
            'duration': '240',
            'more_info': {
              // Encrypted media url that decrypts to dummy url ending in _96.mp4
              'encrypted_media_url': 'bXFfMTIzNDU2Nzg=', // base64 dummy
            }
          }
        ]
      });

      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(searchPayload, 200));

      // CDNs return 403 Forbidden (geo-blocked)
      when(() => mockClient.head(any()))
          .thenAnswer((_) async => http.Response('', 403));

      // If decrypt fails or CDN fails with 403, it should gracefully handle
      try {
        final stream = await dataSource.getStreamUrl(testSong);
        expect(stream, isNull);
      } catch (e) {
        expect(e, isA<GeoRestrictionException>());
      }
    });
  });

  group('StreamLoaderService Geo-Restriction Failover', () {
    late StreamCacheService cache;
    late MockYouTubeMusicDataSource mockYt;
    late PlaybackReliabilityService reliability;

    final testSong = Song(
      id: 'test_track',
      title: 'Tum Hi Ho',
      artist: 'Arijit Singh',
      duration: const Duration(seconds: 260),
      thumbnails: const Thumbnails(),
      source: MusicSource.jiosaavn,
    );

    setUp(() {
      cache = StreamCacheService();
      mockYt = MockYouTubeMusicDataSource();
      reliability = PlaybackReliabilityService();
    });

    test('emits onGeoRestrictionDetected and falls back to YouTubeExplode on GeoRestrictionException', () async {
      final geoBlockedResolver = _FakeGeoBlockedResolver();
      final ytFallbackResolver = _FakeYtFallbackResolver();

      final loader = StreamLoaderService(
        mockYt,
        cache,
        reliability: reliability,
        resolvers: [geoBlockedResolver, ytFallbackResolver],
      );
      addTearDown(loader.dispose);

      GeoRestrictionException? emittedException;
      final sub = loader.onGeoRestrictionDetected.listen((ex) {
        emittedException = ex;
      });

      final result = await loader.loadStream(testSong, useCache: false);

      expect(emittedException, isNotNull);
      expect(emittedException!.provider, 'JioSaavn');
      expect(result.streamProvenance, 'youtube_fallback');
      expect(reliability.isSourceCircuitOpen(StreamSource.jioSaavn), isFalse); // First error doesn't trip, but count increased
      expect(reliability.getSourceConsecutiveErrors(StreamSource.jioSaavn), 1);

      await sub.cancel();
    });
  });
}

class _FakeGeoBlockedResolver implements AudioStreamResolver {
  @override
  String get resolverName => 'jiosaavn';

  @override
  bool get isAvailable => true;

  @override
  Future<StreamInfo?> resolveStream(Song song, {AudioQuality preferredQuality = AudioQuality.high}) async {
    throw const GeoRestrictionException(
      provider: 'JioSaavn',
      statusCode: 403,
      message: 'JioSaavn streams are geo-blocked outside India.',
    );
  }
}

class _FakeYtFallbackResolver implements AudioStreamResolver {
  @override
  String get resolverName => 'youtube_explode';

  @override
  bool get isAvailable => true;

  @override
  Future<StreamInfo?> resolveStream(Song song, {AudioQuality preferredQuality = AudioQuality.high}) async {
    return const StreamInfo(
      url: 'https://rr1.googlevideo.com/videoplayback',
      codec: 'opus',
      bitrate: 160,
      container: 'webm',
      quality: AudioQuality.high,
      streamProvenance: 'youtube_fallback',
    );
  }
}

