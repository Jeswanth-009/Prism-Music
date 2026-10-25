import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prism_music/core/services/diagnostics_service.dart';
import 'package:prism_music/core/services/settings_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('consent_diag_test_');
    Hive.init(tempDir.path);
    await SettingsService.instance.initialize();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Consent Diagnostics & Privacy Preserving Sanitization', () {
    test('telemetryConsent defaults to false and requires explicit opt-in', () async {
      final settings = SettingsService.instance;
      expect(settings.telemetryConsent, isFalse);
      expect(DiagnosticsService.instance.hasTelemetryConsent, isFalse);

      await settings.setTelemetryConsent(true);
      expect(settings.telemetryConsent, isTrue);
      expect(DiagnosticsService.instance.hasTelemetryConsent, isTrue);

      await settings.setTelemetryConsent(false);
      expect(settings.telemetryConsent, isFalse);
    });

    test('sanitizeText redacts sensitive user paths, IPs, and tokens', () {
      // 1. Windows path
      const winInput = 'Error in C:\\Users\\Alice\\AppData\\Local\\PrismMusic\\cache.db';
      expect(
        DiagnosticsService.sanitizeText(winInput),
        'Error in [REDACTED_USER_PATH]',
      );

      // 2. Android path
      const androidInput = 'Failed reading /data/user/0/com.prism.music/databases/prism.hive';
      expect(
        DiagnosticsService.sanitizeText(androidInput),
        'Failed reading [REDACTED_USER_PATH]',
      );

      // 3. IP address
      const ipInput = 'Connected to gateway 192.168.1.45 on port 8080';
      expect(
        DiagnosticsService.sanitizeText(ipInput),
        'Connected to gateway [REDACTED_IP] on port 8080',
      );

      // 4. Client secrets
      const tokenInput = 'Auth request client_secret=9876543210abcdef failed';
      expect(
        DiagnosticsService.sanitizeText(tokenInput),
        'Auth request client_secret=[REDACTED_SECRET] failed',
      );
    });

    test('generateSanitizedLocalBundle creates structured non-PII export', () async {
      final bundle = await DiagnosticsService.instance.generateSanitizedLocalBundle();
      expect(bundle['diagnosticsVersion'], 1);
      expect(bundle['privacy'], isA<Map>());
      final privacy = bundle['privacy'] as Map<String, dynamic>;
      expect(privacy['piiSanitized'], isTrue);
      expect(privacy['mode'], 'local_export_only');
      expect(bundle['system'], isA<Map>());
    });

    test('exportSanitizedLocalBundleJson returns formatted valid JSON', () async {
      final jsonStr = await DiagnosticsService.instance.exportSanitizedLocalBundleJson();
      expect(jsonStr, isNotEmpty);
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;
      expect(decoded['privacy']['piiSanitized'], isTrue);
    });
  });
}
