import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/settings_service.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService defaults (before initialization)', () {
    test('every getter falls back to a sensible default', () {
      final settings = SettingsService.instance;
      // No Hive box yet — getters must not throw.
      expect(settings.audioQuality, 'medium');
      expect(settings.crossfadeDuration, 0.0);
      expect(settings.autoShuffle, isFalse);
      expect(settings.fastStartEnabled, isTrue);
      expect(settings.prefetchLookahead, 3);
      expect(settings.onboardingComplete, isFalse);
      expect(settings.countryCode, 'US');
      expect(settings.downloadFolderPath, isNull);
      expect(settings.autoBackupEnabled, isTrue);
      expect(settings.sharedBackupEnabled, isFalse);
    });
  });

  group('SettingsService round-trips', () {
    setUp(() async {
      initTestHive('settings');
      SettingsService.resetForTesting(secureStorage: FakeSecureStorage());
      await SettingsService.instance.initialize();
    });

    test('audio quality persists', () async {
      await SettingsService.instance.setAudioQuality('lossless');
      expect(SettingsService.instance.audioQuality, 'lossless');
    });

    test('crossfade persists', () async {
      await SettingsService.instance.setCrossfadeDuration(3.5);
      expect(SettingsService.instance.crossfadeDuration, 3.5);
    });

    test('prefetch lookahead clamps to 0–5', () async {
      await SettingsService.instance.setPrefetchLookahead(9);
      expect(SettingsService.instance.prefetchLookahead, 5);

      await SettingsService.instance.setPrefetchLookahead(-2);
      expect(SettingsService.instance.prefetchLookahead, 0);
    });

    test('country and onboarding flags persist', () async {
      await SettingsService.instance.setCountryCode('IN');
      expect(SettingsService.instance.countryCode, 'IN');
      expect(
        SettingsService.instance.selectedCountry.name,
        isNotEmpty,
      );

      await SettingsService.instance.setOnboardingComplete();
      expect(SettingsService.instance.onboardingComplete, isTrue);
    });

    test('download folder persists and clears back to default', () async {
      await SettingsService.instance.setDownloadFolderPath('/tmp/music');
      expect(SettingsService.instance.downloadFolderPath, '/tmp/music');

      await SettingsService.instance.setDownloadFolderPath(null);
      expect(SettingsService.instance.downloadFolderPath, isNull);
    });

    test('theme mode round-trips by name', () async {
      await SettingsService.instance.setThemeMode(ThemeMode.dark);
      expect(SettingsService.instance.themeMode, ThemeMode.dark);
    });

    test('backup settings persist: auto-backup on, shared copy off', () async {
      // Defaults are the privacy-safe pair: private auto-backup enabled,
      // shared-storage copy strictly opt-in.
      expect(SettingsService.instance.autoBackupEnabled, isTrue);
      expect(SettingsService.instance.sharedBackupEnabled, isFalse);

      await SettingsService.instance.setAutoBackupEnabled(false);
      expect(SettingsService.instance.autoBackupEnabled, isFalse);

      await SettingsService.instance.setSharedBackupEnabled(true);
      expect(SettingsService.instance.sharedBackupEnabled, isTrue);
    });

    test('Spotify credentials persist in secure storage and clear', () async {
      final fakeStorage = FakeSecureStorage();
      SettingsService.instance.setSecureStorageForTesting(fakeStorage);

      expect(SettingsService.instance.spotifyClientId, isNull);
      expect(SettingsService.instance.spotifyClientSecret, isNull);

      await SettingsService.instance.setSpotifyClientId('test-client-id');
      await SettingsService.instance.setSpotifyClientSecret('test-client-secret');

      expect(SettingsService.instance.spotifyClientId, 'test-client-id');
      expect(SettingsService.instance.spotifyClientSecret, 'test-client-secret');
      expect(fakeStorage.values['spotify_client_id'], 'test-client-id');
      expect(fakeStorage.values['spotify_client_secret'], 'test-client-secret');

      // Clearing credentials
      await SettingsService.instance.setSpotifyClientId(null);
      await SettingsService.instance.setSpotifyClientSecret('');

      expect(SettingsService.instance.spotifyClientId, isNull);
      expect(SettingsService.instance.spotifyClientSecret, isNull);
      expect(fakeStorage.values.containsKey('spotify_client_id'), isFalse);
      expect(fakeStorage.values.containsKey('spotify_client_secret'), isFalse);
    });

    test('Spotify credentials migrate from legacy Hive box to secure storage', () async {
      final fakeStorage = FakeSecureStorage();
      SettingsService.resetForTesting(secureStorage: fakeStorage);

      // Pre-populate legacy plaintext keys into Hive
      final box = Hive.box('app_settings');
      await box.put('spotify_client_id', 'legacy-client-id');
      await box.put('spotify_client_secret', 'legacy-client-secret');

      // Initialize service - should trigger migration
      await SettingsService.instance.initialize();

      expect(SettingsService.instance.spotifyClientId, 'legacy-client-id');
      expect(SettingsService.instance.spotifyClientSecret, 'legacy-client-secret');
      expect(fakeStorage.values['spotify_client_id'], 'legacy-client-id');
      expect(fakeStorage.values['spotify_client_secret'], 'legacy-client-secret');

      // Confirm legacy keys were purged from Hive
      expect(box.get('spotify_client_id'), isNull);
      expect(box.get('spotify_client_secret'), isNull);
    });
  });
}

