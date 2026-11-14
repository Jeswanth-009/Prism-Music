import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/settings_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsBackupService', () {
    test('exportSettingsToJson generates valid schema JSON', () {
      final jsonStr = SettingsBackupService.instance.exportSettingsToJson();
      expect(jsonStr, isNotEmpty);

      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded['identifier'], equals('prism_settings_backup'));
      expect(decoded['schema_version'], equals(1));
      expect(decoded['exported_at'], isNotEmpty);

      final settings = decoded['settings'] as Map<String, dynamic>;
      expect(settings, isNotNull);
      expect(settings.containsKey('theme_mode'), isTrue);
      expect(settings.containsKey('player_ui_style'), isTrue);
      expect(settings.containsKey('visualizer_style'), isTrue);
      expect(settings.containsKey('fast_start_enabled'), isTrue);
      expect(settings.containsKey('audio_normalization_enabled'), isTrue);
    });

    test('validateSettingsJson validates correct format and catches malformed JSON', () {
      final service = SettingsBackupService.instance;

      // 1. Valid export
      final validJson = service.exportSettingsToJson();
      final (isValid, error, settings) = service.validateSettingsJson(validJson);
      expect(isValid, isTrue);
      expect(error, isNull);
      expect(settings, isNotNull);

      // 2. Corrupted JSON syntax
      final (corruptValid, corruptError, _) =
          service.validateSettingsJson('{not_valid_json');
      expect(corruptValid, isFalse);
      expect(corruptError, contains('Corrupted JSON'));

      // 3. Wrong identifier
      final wrongIdentifierJson = jsonEncode({
        'identifier': 'random_backup',
        'schema_version': 1,
        'settings': {},
      });
      final (wrongValid, wrongError, _) =
          service.validateSettingsJson(wrongIdentifierJson);
      expect(wrongValid, isFalse);
      expect(wrongError, contains('not a Prism Music settings backup'));

      // 4. Missing settings key
      final missingSettingsJson = jsonEncode({
        'identifier': 'prism_settings_backup',
        'schema_version': 1,
      });
      final (missValid, missError, _) =
          service.validateSettingsJson(missingSettingsJson);
      expect(missValid, isFalse);
      expect(missError, contains('Backup contains no settings data'));
    });

    test('importSettingsFromJson restores valid settings and counts restored keys', () async {
      final service = SettingsBackupService.instance;

      final sampleBackup = jsonEncode({
        'identifier': 'prism_settings_backup',
        'schema_version': 1,
        'exported_at': '2026-11-14T23:00:00Z',
        'settings': {
          'theme_mode': 'dark',
          'dynamic_accent': true,
          'player_ui_style': 'vinyl',
          'visualizer_style': 'wave',
          'fast_start_enabled': false,
          'audio_normalization_enabled': true,
          'audio_normalization_target': 'balanced',
          'eq_preset': 'Rock',
          'app_language': 'en',
          'download_wifi_only': false,
        },
      });

      final result = await service.importSettingsFromJson(sampleBackup);
      expect(result.isSuccess, isTrue);
      expect(result.restoredCount, equals(10));
      expect(result.error, isNull);
      expect(result.settings?['theme_mode'], equals('dark'));
      expect(result.settings?['player_ui_style'], equals('vinyl'));
    });

    test('importSettingsFromJson fails gracefully on invalid JSON', () async {
      final service = SettingsBackupService.instance;
      final result = await service.importSettingsFromJson('invalid payload');
      expect(result.isSuccess, isFalse);
      expect(result.restoredCount, equals(0));
      expect(result.error, isNotNull);
    });
  });
}
