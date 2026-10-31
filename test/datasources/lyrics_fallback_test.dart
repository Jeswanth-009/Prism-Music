import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/data/datasources/remote/lyrics/fallback_lyrics_provider.dart';
import 'package:prism_music/data/datasources/remote/lyrics/lyrics_datasource.dart';
import 'package:prism_music/data/datasources/remote/lyrics/lyrics_local_cache.dart';

import '../helpers/fakes.dart';

class FakeFallbackProvider implements FallbackLyricsProvider {
  String? result;
  int callCount = 0;
  String? lastTitle;
  String? lastArtist;

  @override
  Future<String?> fetchLyrics(String title, String artist) async {
    callCount++;
    lastTitle = title;
    lastArtist = artist;
    return result;
  }
}

class FakeDioAdapter implements HttpClientAdapter {
  final Map<String, ResponseBody Function(RequestOptions options)> handlers = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.toString();
    for (final entry in handlers.entries) {
      if (path.contains(entry.key)) {
        return entry.value(options);
      }
    }
    return ResponseBody.fromString(
      '{"error": "Not Found"}',
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    initTestHive('lyrics_fallback_test');
  });

  group('LyricsOvhFallbackProvider', () {
    late Dio dio;
    late FakeDioAdapter adapter;
    late LyricsOvhFallbackProvider provider;

    setUp(() {
      dio = Dio();
      adapter = FakeDioAdapter();
      dio.httpClientAdapter = adapter;
      provider = LyricsOvhFallbackProvider(dio: dio);
    });

    test('fetches and trims plain lyrics on HTTP 200', () async {
      adapter.handlers['lyrics.ovh'] = (options) => ResponseBody.fromString(
            '{"lyrics": "  Is this the real life?\\nIs this just fantasy?  "}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );

      final result =
          await provider.fetchLyrics('Bohemian Rhapsody', 'Queen');
      expect(result, 'Is this the real life?\nIs this just fantasy?');
    });

    test('returns null on HTTP 404 or missing lyrics', () async {
      adapter.handlers['lyrics.ovh'] = (options) => ResponseBody.fromString(
            '{"error": "No lyrics found"}',
            404,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );

      final result =
          await provider.fetchLyrics('Unknown Song', 'Unknown Artist');
      expect(result, isNull);
    });

    test('returns null gracefully on empty artist or title', () async {
      final result = await provider.fetchLyrics('', '  ');
      expect(result, isNull);
    });
  });

  group('LyricsDataSourceImpl fallback integration', () {
    late Dio dio;
    late FakeDioAdapter adapter;
    late LyricsLocalCache cache;
    late FakeFallbackProvider fakeFallback;
    late LyricsDataSourceImpl dataSource;

    setUp(() {
      dio = Dio();
      adapter = FakeDioAdapter();
      dio.httpClientAdapter = adapter;
      cache = LyricsLocalCache();
      fakeFallback = FakeFallbackProvider();
      dataSource = LyricsDataSourceImpl(
        dio: dio,
        cache: cache,
        fallbackProvider: fakeFallback,
      );
    });

    test('returns LRCLIB lyrics when LRCLIB has match without calling fallback',
        () async {
      adapter.handlers['lrclib.net/api/get'] = (options) =>
          ResponseBody.fromString(
            '{"trackName": "Song A", "artistName": "Artist A", "plainLyrics": "Hello from LRCLIB", "syncedLyrics": "[00:01.00]Hello from LRCLIB"}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );

      final result = await dataSource.getSyncedLyrics('Song A', 'Artist A');
      expect(result, isNotNull);
      expect(result!.source, 'LRCLIB');
      expect(result.plainLyrics, 'Hello from LRCLIB');
      expect(fakeFallback.callCount, 0);
    });

    test('falls back to secondary provider when LRCLIB returns 404 and caches it',
        () async {
      adapter.handlers['lrclib.net/api/get'] = (options) =>
          ResponseBody.fromString('{"message": "Not found"}', 404);
      adapter.handlers['lrclib.net/api/search'] =
          (options) => ResponseBody.fromString('[]', 200, headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              });

      fakeFallback.result = 'Fallback lyrics from lyrics.ovh';

      final result =
          await dataSource.getSyncedLyrics('Fallback Track', 'Indie Artist');
      expect(result, isNotNull);
      expect(result!.source, 'lyrics.ovh');
      expect(result.plainLyrics, 'Fallback lyrics from lyrics.ovh');
      expect(fakeFallback.callCount, 1);

      // Verify second call is served from cache without calling fallback provider again
      final cachedResult =
          await dataSource.getSyncedLyrics('Fallback Track', 'Indie Artist');
      expect(cachedResult, isNotNull);
      expect(cachedResult!.source, 'lyrics.ovh');
      expect(fakeFallback.callCount, 1);
    });

    test('recovers via fallback provider even if LRCLIB suffers an outage (500)',
        () async {
      adapter.handlers['lrclib.net/api/get'] = (options) =>
          ResponseBody.fromString('{"error": "Internal Server Error"}', 500);

      fakeFallback.result = 'Resilient fallback lyrics';

      final result =
          await dataSource.getSyncedLyrics('Server Down Song', 'Band');
      expect(result, isNotNull);
      expect(result!.source, 'lyrics.ovh');
      expect(result.plainLyrics, 'Resilient fallback lyrics');
      expect(fakeFallback.callCount, 1);
    });

    test('marks not found when both LRCLIB and fallback fail', () async {
      adapter.handlers['lrclib.net/api/get'] = (options) =>
          ResponseBody.fromString('{"message": "Not found"}', 404);
      adapter.handlers['lrclib.net/api/search'] =
          (options) => ResponseBody.fromString('[]', 200, headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              });

      fakeFallback.result = null;

      final result =
          await dataSource.getSyncedLyrics('Nonexistent', 'Nobody');
      expect(result, isNull);
      expect(fakeFallback.callCount, 1);

      // Verify marked not found: next call shouldn't query fallback again
      final second =
          await dataSource.getSyncedLyrics('Nonexistent', 'Nobody');
      expect(second, isNull);
      expect(fakeFallback.callCount, 1);
    });
  });
}
