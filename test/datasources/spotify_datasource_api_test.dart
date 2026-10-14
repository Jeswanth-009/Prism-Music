import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/spotify_auth_service.dart';
import 'package:prism_music/core/utils/cancellation_token.dart';
import 'package:prism_music/data/datasources/remote/spotify/spotify_datasource.dart';

class MockDioAdapter implements HttpClientAdapter {
  ResponseBody Function(RequestOptions options)? handler;

  MockDioAdapter([this.handler]);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (handler != null) {
      return handler!(options);
    }
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

class FakeSpotifyAuthService extends SpotifyAuthService {
  String? mockToken;
  bool invalidated = false;

  FakeSpotifyAuthService({this.mockToken});

  @override
  bool get isConfigured => mockToken != null;

  @override
  Future<String?> getValidAccessToken() async => mockToken;

  @override
  void invalidateToken() {
    invalidated = true;
    mockToken = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpotifyDataSourceImpl Web API & Fallback', () {
    late Dio dio;
    late MockDioAdapter adapter;

    setUp(() {
      dio = Dio();
      adapter = MockDioAdapter();
      dio.httpClientAdapter = adapter;
    });

    test('paginates 150 tracks and extracts ISRC from Web API when authenticated', () async {
      final fakeAuth = FakeSpotifyAuthService(mockToken: 'valid_bearer_token');
      final dataSource = SpotifyDataSourceImpl(
        dio: dio,
        authService: fakeAuth,
      );

      adapter.handler = (options) {
        expect(options.headers['Authorization'], 'Bearer valid_bearer_token');

        if (options.path.contains('/v1/playlists/37i9dQZEVXbMDoHDwVN2t1') && !options.path.contains('/tracks')) {
          return ResponseBody.fromString(
            jsonEncode({
              'id': '37i9dQZEVXbMDoHDwVN2t1',
              'name': 'My Massive Playlist',
              'description': 'A playlist with >100 tracks',
              'owner': {'display_name': 'MusicFan'},
              'images': [{'url': 'https://img.spotify.com/cover.jpg'}],
              'tracks': {'total': 150},
            }),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }

        if (options.path.contains('/tracks')) {
          final offset = options.queryParameters['offset'] as int? ?? 0;
          final count = offset == 0 ? 100 : 50;

          final items = List.generate(count, (i) {
            final idx = offset + i;
            return {
              'track': {
                'id': 'sp_track_$idx',
                'name': 'Track $idx',
                'artists': [{'name': 'Artist $idx'}],
                'album': {
                  'name': 'Album $idx',
                  'images': [{'url': 'https://img.spotify.com/t$idx.jpg'}],
                },
                'duration_ms': 180000 + idx * 1000,
                'external_ids': {'isrc': 'USPRISM${idx.toString().padLeft(5, '0')}'},
              },
            };
          });

          return ResponseBody.fromString(
            jsonEncode({'items': items}),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }

        return ResponseBody.fromString('{}', 404);
      };

      final progressEvents = <int>[];
      final details = await dataSource.getPlaylistDetails(
        'https://open.spotify.com/playlist/37i9dQZEVXbMDoHDwVN2t1',
        onProgress: (loaded, total) {
          progressEvents.add(loaded);
        },
      );

      expect(details, isNotNull);
      expect(details!.name, 'My Massive Playlist');
      expect(details.totalTracks, 150);
      expect(details.tracks.length, 150);
      expect(details.isEmbedFallback, isFalse);

      // Verify ISRC extracted correctly
      expect(details.tracks.first.isrc, 'USPRISM00000');
      expect(details.tracks[149].isrc, 'USPRISM00149');

      // Verify pagination progress events
      expect(progressEvents, containsAll([100, 150]));
    });

    test('honors cancellation token and stops paginating mid-flight', () async {
      final fakeAuth = FakeSpotifyAuthService(mockToken: 'valid_bearer_token');
      final dataSource = SpotifyDataSourceImpl(
        dio: dio,
        authService: fakeAuth,
      );

      final cancelToken = ImportCancellationToken();

      adapter.handler = (options) {
        if (!options.path.contains('/tracks')) {
          return ResponseBody.fromString(
            jsonEncode({
              'id': 'test_pl_cancel',
              'name': 'Cancelled Playlist',
              'tracks': {'total': 300},
            }),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }

        // Cancel token after receiving first 100 tracks
        cancelToken.cancel();

        final items = List.generate(100, (i) {
          return {
            'track': {
              'id': 't_$i',
              'name': 'Track $i',
              'artists': [{'name': 'Artist'}],
              'duration_ms': 120000,
            },
          };
        });

        return ResponseBody.fromString(
          jsonEncode({'items': items}),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      final details = await dataSource.getPlaylistDetails(
        'https://open.spotify.com/playlist/test_pl_cancel',
        cancelToken: cancelToken,
      );

      expect(details, isNotNull);
      // Stopped after first batch of 100 instead of fetching all 300
      expect(details!.tracks.length, 100);
      expect(cancelToken.isCancelled, isTrue);
    });

    test('falls back to embed scraping when authService is null or token missing', () async {
      final dataSource = SpotifyDataSourceImpl(
        dio: dio,
        authService: null,
      );

      final embedHtmlFixture = '''
<!DOCTYPE html>
<html>
<head>
<script id="__NEXT_DATA__" type="application/json">
{
  "props": {
    "pageProps": {
      "state": {
        "data": {
          "entity": {
            "type": "playlist",
            "name": "Zero Auth Fallback Playlist",
            "subtitle": "Created by TestUser",
            "trackList": [
              {
                "uri": "spotify:track:embed1",
                "title": "Embed Scraped Song",
                "subtitle": "Independent Artist",
                "duration": 210000
              }
            ]
          }
        }
      }
    }
  }
}
</script>
</head>
<body></body>
</html>
''';

      adapter.handler = (options) {
        expect(options.path, contains('/embed/playlist/37i9dQZEVXbMDoHDwVN2t2'));
        return ResponseBody.fromString(embedHtmlFixture, 200);
      };

      final details = await dataSource.getPlaylistDetails(
        'https://open.spotify.com/playlist/37i9dQZEVXbMDoHDwVN2t2',
      );

      expect(details, isNotNull);
      expect(details!.name, 'Zero Auth Fallback Playlist');
      expect(details.isEmbedFallback, isTrue);
      expect(details.tracks.length, 1);
      expect(details.tracks.first.title, 'Embed Scraped Song');
      expect(details.tracks.first.artist, 'Independent Artist');
    });

    test('invalidates token and falls back to embed on 401 Unauthorized', () async {
      final fakeAuth = FakeSpotifyAuthService(mockToken: 'expired_token');
      final dataSource = SpotifyDataSourceImpl(
        dio: dio,
        authService: fakeAuth,
      );

      final embedHtmlFixture = '''
<script id="__NEXT_DATA__" type="application/json">
{
  "props": {
    "pageProps": {
      "state": {
        "data": {
          "entity": {
            "type": "playlist",
            "name": "Recovered via Embed",
            "trackList": [
              {
                "uri": "spotify:track:recovered1",
                "title": "Recovered Track",
                "subtitle": "Artist",
                "duration": 180000
              }
            ]
          }
        }
      }
    }
  }
}
</script>
''';

      adapter.handler = (options) {
        if (options.path.contains('api.spotify.com')) {
          return ResponseBody.fromString(
            jsonEncode({'error': {'status': 401, 'message': 'The access token expired'}}),
            401,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        } else {
          return ResponseBody.fromString(embedHtmlFixture, 200);
        }
      };

      final details = await dataSource.getPlaylistDetails(
        'https://open.spotify.com/playlist/37i9dQZEVXbMDoHDwVN2t3',
      );

      expect(fakeAuth.invalidated, isTrue);
      expect(details, isNotNull);
      expect(details!.name, 'Recovered via Embed');
      expect(details.isEmbedFallback, isTrue);
    });
  });
}
