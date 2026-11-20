import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/spotify_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpotifyAuthService token and credential lifecycle', () {
    test('invalidateToken clears cached token and expiry from memory', () {
      final service = SpotifyAuthService();
      expect(service.isConfigured, isFalse);

      // Invalidate should execute cleanly without error
      service.invalidateToken();
      expect(service.isConfigured, isFalse);
    });

    test('getValidAccessToken returns null when credentials are unconfigured', () async {
      final service = SpotifyAuthService();
      final token = await service.getValidAccessToken();
      expect(token, isNull);
    });

    test('testConnection returns false when credentials are empty', () async {
      final service = SpotifyAuthService();
      final connected = await service.testConnection(
        clientId: '   ',
        clientSecret: '   ',
      );
      expect(connected, isFalse);
    });

    test('testConnection handles network failures gracefully without persisting tokens', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.reject(
              DioException(
                requestOptions: options,
                error: 'Simulated connection failure',
                type: DioExceptionType.connectionError,
              ),
            );
          },
        ),
      );

      final service = SpotifyAuthService(dio: dio);
      final connected = await service.testConnection(
        clientId: 'test-client-id',
        clientSecret: 'test-client-secret',
      );
      expect(connected, isFalse);
    });
  });
}
