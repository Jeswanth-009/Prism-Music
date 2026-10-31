import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/spotify_auth_service.dart';
import 'package:prism_music/core/utils/cancellation_token.dart';
import 'package:prism_music/data/datasources/remote/spotify/spotify_datasource.dart';

class FakeSpotifyAuthService implements SpotifyAuthService {
  String? token = 'valid_test_token';
  bool invalidated = false;

  @override
  Future<String?> getValidAccessToken() async => token;

  @override
  void invalidateToken() {
    invalidated = true;
    token = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class QueueDioAdapter implements HttpClientAdapter {
  final Map<String, List<ResponseBody Function(RequestOptions options)>> queues =
      {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.toString();
    for (final entry in queues.entries) {
      if (path.contains(entry.key)) {
        final list = entry.value;
        if (list.isNotEmpty) {
          final handler = list.removeAt(0);
          return handler(options);
        }
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

  group('SpotifyDataSourceImpl backoff & retry tests', () {
    late Dio dio;
    late QueueDioAdapter adapter;
    late FakeSpotifyAuthService authService;
    late SpotifyDataSourceImpl dataSource;

    setUp(() {
      dio = Dio();
      adapter = QueueDioAdapter();
      dio.httpClientAdapter = adapter;
      authService = FakeSpotifyAuthService();
      dataSource = SpotifyDataSourceImpl(
        dio: dio,
        authService: authService,
        batchPacing: Duration.zero,
        initialBackoff: const Duration(milliseconds: 10),
        maxRetries: 3,
      );
    });

    test('recovers from HTTP 429 with retry-after header and imports tracks',
        () async {
      // 1. Metadata response (200 OK)
      adapter.queues['api.spotify.com/v1/playlists/37i9dQZEVXbMDoHDwVN2t1'] = [
        (opts) => ResponseBody.fromString(
              '{"name": "Big Playlist", "tracks": {"total": 2}}',
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            ),
      ];

      // 2. Tracks response queue: first 429 with Retry-After, then 200 OK
      adapter.queues['api.spotify.com/v1/playlists/37i9dQZEVXbMDoHDwVN2t1/tracks'] = [
        (opts) => ResponseBody.fromString(
              '{"error": {"status": 429, "message": "Rate limit exceeded"}}',
              429,
              headers: {
                'retry-after': ['1'],
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            ),
        (opts) => ResponseBody.fromString(
              '''{
                "items": [
                  {"track": {"id": "t1", "name": "Track One", "duration_ms": 180000, "artists": [{"name": "Artist 1"}]}},
                  {"track": {"id": "t2", "name": "Track Two", "duration_ms": 200000, "artists": [{"name": "Artist 2"}]}}
                ]
              }''',
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            ),
      ];

      final details = await dataSource
          .getPlaylistDetails('https://open.spotify.com/playlist/37i9dQZEVXbMDoHDwVN2t1');

      expect(details, isNotNull);
      expect(details!.tracks.length, 2);
      expect(details.tracks[0].title, 'Track One');
      expect(details.tracks[1].title, 'Track Two');
      expect(details.isEmbedFallback, isFalse);
    });

    test('recovers from 503 transient error via exponential backoff',
        () async {
      adapter.queues['api.spotify.com/v1/playlists/37i9dQZEVXbMDoHDwVN2t2'] = [
        (opts) => ResponseBody.fromString(
              '{"name": "503 Playlist", "tracks": {"total": 1}}',
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            ),
      ];

      adapter.queues['api.spotify.com/v1/playlists/37i9dQZEVXbMDoHDwVN2t2/tracks'] = [
        (opts) => ResponseBody.fromString(
              '{"error": "Service Unavailable"}',
              503,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            ),
        (opts) => ResponseBody.fromString(
              '''{
                "items": [
                  {"track": {"id": "t503", "name": "Recovered Track", "duration_ms": 150000, "artists": [{"name": "Resilient Artist"}]}}
                ]
              }''',
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            ),
      ];

      final details = await dataSource
          .getPlaylistDetails('https://open.spotify.com/playlist/37i9dQZEVXbMDoHDwVN2t2');

      expect(details, isNotNull);
      expect(details!.tracks.length, 1);
      expect(details.tracks.first.title, 'Recovered Track');
    });

    test('cancels gracefully mid-import when ImportCancellationToken is triggered',
        () async {
      final cancelToken = ImportCancellationToken();

      adapter.queues['api.spotify.com/v1/playlists/37i9dQZEVXbMDoHDwVN2t3'] = [
        (opts) => ResponseBody.fromString(
              '{"name": "Huge Playlist", "tracks": {"total": 300}}',
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            ),
      ];

      // Batch 1 succeeds, then cancel token is invoked
      adapter.queues['api.spotify.com/v1/playlists/37i9dQZEVXbMDoHDwVN2t3/tracks'] = [
        (opts) {
          cancelToken.cancel();
          return ResponseBody.fromString(
            '''{
              "items": [
                {"track": {"id": "t1", "name": "First Batch Track", "duration_ms": 120000, "artists": [{"name": "A"}]}}
              ]
            }''',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      ];

      final details = await dataSource.getPlaylistDetails(
        'https://open.spotify.com/playlist/37i9dQZEVXbMDoHDwVN2t3',
        cancelToken: cancelToken,
      );

      expect(details, isNotNull);
      expect(details!.tracks.length, 1);
      expect(details.hasMoreTracks, isTrue);
    });
  });
}
