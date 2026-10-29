import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:prism_music/core/services/lastfm_service.dart';

import '../helpers/fakes.dart';


class FakeHttpClient extends http.BaseClient {
  http.BaseRequest? lastRequest;
  String? lastRequestBody;
  http.Response Function(http.BaseRequest request)? handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    if (request is http.Request) {
      lastRequestBody = request.body;
    }
    final response = handler != null
        ? handler!(request)
        : http.Response('{"session":{"key":"test_session_key"}}', 200);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    // Reset any static custom credentials between test groups
    final storage = FakeSecureStorage();
    final service = LastFmService(secureStorage: storage);
    service.clearCustomCredentials();
  });

  group('LastFmService credential gating', () {
    test('isConfigured is false by default when dart-define is absent', () {
      expect(LastFmService.isConfigured, isFalse);
    });

    test('service reports unauthenticated when unconfigured', () {
      final storage = FakeSecureStorage();
      final service = LastFmService(secureStorage: storage);
      expect(service.isAuthenticated, isFalse);
    });
  });

  group('LastFmService custom credentials management', () {
    late FakeSecureStorage storage;

    setUp(() {
      storage = FakeSecureStorage();
    });

    test('saves and loads user-configured API credentials securely', () async {
      final service = LastFmService(secureStorage: storage);
      await service.initialize();
      expect(service.hasCustomCredentials, isFalse);
      expect(service.hasValidCredentials, isFalse);

      await service.setCustomCredentials(
        apiKey: 'custom_api_key_12345',
        apiSecret: 'custom_secret_67890',
      );

      expect(service.hasCustomCredentials, isTrue);
      expect(service.hasValidCredentials, isTrue);
      expect(service.apiKey, 'custom_api_key_12345');
      expect(service.apiSecret, 'custom_secret_67890');
      expect(storage.values[LastFmService.secureKeyCustomApiKey], 'custom_api_key_12345');
      expect(storage.values[LastFmService.secureKeyCustomApiSecret], 'custom_secret_67890');

      // Subsequent instance initialized from secure storage retrieves keys
      final freshInstance = LastFmService(secureStorage: storage);
      await freshInstance.initialize();
      expect(freshInstance.hasCustomCredentials, isTrue);
      expect(freshInstance.hasValidCredentials, isTrue);
      expect(freshInstance.apiKey, 'custom_api_key_12345');
    });

    test('clearCustomCredentials removes keys and logs out', () async {
      storage.values[LastFmService.secureKeyCustomApiKey] = 'key_to_delete';
      storage.values[LastFmService.secureKeyCustomApiSecret] = 'secret_to_delete';
      storage.values[LastFmService.secureKeySession] = 'session_to_delete';
      storage.values[LastFmService.secureKeyUsername] = 'user_to_delete';

      final service = LastFmService(secureStorage: storage);
      await service.initialize();
      expect(service.hasCustomCredentials, isTrue);

      await service.clearCustomCredentials();

      expect(service.hasCustomCredentials, isFalse);
      expect(service.hasValidCredentials, isFalse);
      expect(service.isAuthenticated, isFalse);
      expect(storage.values.containsKey(LastFmService.secureKeyCustomApiKey), isFalse);
      expect(storage.values.containsKey(LastFmService.secureKeyCustomApiSecret), isFalse);
      expect(storage.values.containsKey(LastFmService.secureKeySession), isFalse);
    });
  });

  group('LastFmService authenticated HTTP operations', () {
    late FakeSecureStorage storage;
    late FakeHttpClient httpClient;

    setUp(() async {
      storage = FakeSecureStorage();
      storage.values[LastFmService.secureKeyCustomApiKey] = 'test_api_key';
      storage.values[LastFmService.secureKeyCustomApiSecret] = 'test_secret';
      httpClient = FakeHttpClient();
    });

    test('authenticate exchanges credentials for session and saves to secure storage', () async {
      final service = LastFmService(
        secureStorage: storage,
        httpClient: httpClient,
      );
      await service.initialize();

      httpClient.handler = (req) {
        return http.Response(
          '{"session":{"key":"authenticated_session_999"}}',
          200,
        );
      };

      final ok = await service.authenticate('my_user', 'my_pass');

      expect(ok, isTrue);
      expect(service.isAuthenticated, isTrue);
      expect(service.username, 'my_user');
      expect(storage.values[LastFmService.secureKeySession], 'authenticated_session_999');
      expect(storage.values[LastFmService.secureKeyUsername], 'my_user');
      expect(httpClient.lastRequestBody, contains('auth.getMobileSession'));
      expect(httpClient.lastRequestBody, contains('test_api_key'));
    });

    test('scrobble sends signed track request when authenticated', () async {
      storage.values[LastFmService.secureKeySession] = 'session_ok';
      storage.values[LastFmService.secureKeyUsername] = 'my_user';

      final service = LastFmService(
        secureStorage: storage,
        httpClient: httpClient,
      );
      await service.initialize();

      httpClient.handler = (req) => http.Response('{"scrobbles":{"@attr":{"accepted":1}}}', 200);

      final ok = await service.scrobble(
        track: 'Bohemian Rhapsody',
        artist: 'Queen',
        album: 'A Night at the Opera',
      );

      expect(ok, isTrue);
      expect(httpClient.lastRequestBody, contains('track.scrobble'));
      expect(httpClient.lastRequestBody, contains('Bohemian+Rhapsody'));
      expect(httpClient.lastRequestBody, contains('api_sig='));
    });
  });

  group('LastFmService secure storage and migration', () {
    late FakeSecureStorage storage;

    setUp(() async {
      initTestHive('lastfm_test');
      storage = FakeSecureStorage();
    });

    test('reads existing session and username from secure storage', () async {
      storage.values[LastFmService.secureKeySession] = 'token_abc_123';
      storage.values[LastFmService.secureKeyUsername] = 'prism_user';

      final service = LastFmService(secureStorage: storage);
      await service.initialize();

      expect(service.username, 'prism_user');
    });

    test('migrates legacy credentials from plain Hive box to secure storage and deletes box', () async {
      // 1. Setup legacy Hive box with credentials
      final legacyBox = await Hive.openBox(LastFmService.legacySessionBoxName);
      await legacyBox.put('session_key', 'migrated_key_999');
      await legacyBox.put('username', 'legacy_user');
      await legacyBox.close();

      // 2. Initialize service with empty secure storage
      final service = LastFmService(secureStorage: storage);
      await service.initialize();

      // 3. Credentials migrated to secure storage
      expect(storage.values[LastFmService.secureKeySession], 'migrated_key_999');
      expect(storage.values[LastFmService.secureKeyUsername], 'legacy_user');
      expect(service.username, 'legacy_user');

      // 4. Hive box is cleared and deleted from disk
      if (Hive.isBoxOpen(LastFmService.legacySessionBoxName)) {
        final box = Hive.box(LastFmService.legacySessionBoxName);
        expect(box.get('session_key'), isNull);
        expect(box.get('username'), isNull);
      }
    });

    test('logout clears secure storage and in-memory state', () async {
      storage.values[LastFmService.secureKeySession] = 'active_key';
      storage.values[LastFmService.secureKeyUsername] = 'active_user';

      final service = LastFmService(secureStorage: storage);
      await service.initialize();
      expect(service.username, 'active_user');

      await service.logout();

      expect(service.username, isNull);
      expect(service.isAuthenticated, isFalse);
      expect(storage.values.containsKey(LastFmService.secureKeySession), isFalse);
      expect(storage.values.containsKey(LastFmService.secureKeyUsername), isFalse);
    });
  });
}
