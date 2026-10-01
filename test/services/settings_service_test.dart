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
    });
  });

  group('SettingsService round-trips', () {
    setUp(() async {
      initTestHive('settings');
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
  });
}
