import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/core/services/spotify_auth_service.dart';

import '../../helpers/fakes.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpotifyAuthService', () {
    late SettingsService settings;
    late Dio dio;
    late MockDioAdapter adapter;
    late SpotifyAuthService authService;

    setUp(() async {
      initTestHive('spotify_auth_test');
      settings = SettingsService.instance;
      await settings.initialize();
      await settings.setSpotifyClientId(null);
      await settings.setSpotifyClientSecret(null);

      dio = Dio();
      adapter = MockDioAdapter();
      dio.httpClientAdapter = adapter;

      authService = SpotifyAuthService(
        dio: dio,
        settingsService: settings,
      );
    });

    test('isConfigured is false when credentials are empty', () {
      expect(authService.isConfigured, isFalse);
    });

    test('isConfigured is true when both client ID and secret are set', () async {
      await settings.setSpotifyClientId('test_client_id');
      await settings.setSpotifyClientSecret('test_client_secret');

      expect(authService.isConfigured, isTrue);
    });

    test('getValidAccessToken returns null when not configured', () async {
      final token = await authService.getValidAccessToken();
      expect(token, isNull);
    });

    test('fetches and caches access token successfully', () async {
      await settings.setSpotifyClientId('valid_id');
      await settings.setSpotifyClientSecret('valid_secret');

      int requestCount = 0;
      adapter.handler = (options) {
        requestCount++;
        expect(options.path, 'https://accounts.spotify.com/api/token');
        expect(options.headers['Authorization'], startsWith('Basic '));

        final body = jsonEncode({
          'access_token': 'mock_bearer_token_123',
          'token_type': 'Bearer',
          'expires_in': 3600,
        });
        return ResponseBody.fromString(body, 200, headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
      };

      final token1 = await authService.getValidAccessToken();
      expect(token1, 'mock_bearer_token_123');
      expect(requestCount, 1);

      // Second call should return cached token without new HTTP request
      final token2 = await authService.getValidAccessToken();
      expect(token2, 'mock_bearer_token_123');
      expect(requestCount, 1);
    });

    test('invalidateToken causes next call to request new token', () async {
      await settings.setSpotifyClientId('valid_id');
      await settings.setSpotifyClientSecret('valid_secret');

      int requestCount = 0;
      adapter.handler = (options) {
        requestCount++;
        final body = jsonEncode({
          'access_token': 'token_$requestCount',
          'expires_in': 3600,
        });
        return ResponseBody.fromString(body, 200, headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
      };

      final token1 = await authService.getValidAccessToken();
      expect(token1, 'token_1');
      expect(requestCount, 1);

      authService.invalidateToken();

      final token2 = await authService.getValidAccessToken();
      expect(token2, 'token_2');
      expect(requestCount, 2);
    });

    test('returns null when Spotify API returns HTTP 400 or 401', () async {
      await settings.setSpotifyClientId('bad_id');
      await settings.setSpotifyClientSecret('bad_secret');

      adapter.handler = (options) {
        final body = jsonEncode({
          'error': 'invalid_client',
          'error_description': 'Invalid client secret',
        });
        return ResponseBody.fromString(body, 400, headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
      };

      final token = await authService.getValidAccessToken();
      expect(token, isNull);
    });

    test('testConnection returns true on valid credentials and false on failure', () async {
      adapter.handler = (options) {
        final authHeader = options.headers['Authorization'] as String? ?? '';
        final encoded = authHeader.replaceFirst('Basic ', '');
        final decoded = utf8.decode(base64Decode(encoded));

        if (decoded == 'good_id:good_secret') {
          return ResponseBody.fromString(
            jsonEncode({'access_token': 'valid', 'expires_in': 3600}),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        } else {
          return ResponseBody.fromString(
            jsonEncode({'error': 'invalid_client'}),
            401,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
      };

      final good = await authService.testConnection(
        clientId: 'good_id',
        clientSecret: 'good_secret',
      );
      expect(good, isTrue);

      final bad = await authService.testConnection(
        clientId: 'bad_id',
        clientSecret: 'bad_secret',
      );
      expect(bad, isFalse);
    });
  });
}
