import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prism_music/core/services/lastfm_service.dart';

import '../helpers/fakes.dart';

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.clear();
  }

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values.containsKey(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
