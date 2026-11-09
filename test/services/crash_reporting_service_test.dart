import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/crash_reporting_service.dart';
import 'package:prism_music/core/services/settings_service.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    initTestHive('crash_reporting_test');
    await SettingsService.instance.initialize();
    await CrashReportingService.instance.initialize();
    await CrashReportingService.instance.clearReports();
  });

  tearDown(() async {
    await CrashReportingService.instance.clearReports();
  });

  group('Privacy-First Crash Reporting Tests', () {
    test('sanitizes PII from error messages and stack traces', () {
      const rawText = 'Error connecting to 192.168.1.100 with query https://api.service.com/stream?v=private_user_query&auth=token123 from user@domain.com at C:\\Users\\Developer\\Prism';
      final sanitized = CrashReportingService.sanitizeText(rawText);

      expect(sanitized, isNot(contains('192.168.1.100')));
      expect(sanitized, contains('[REDACTED_IP]'));

      expect(sanitized, isNot(contains('private_user_query')));
      expect(sanitized, contains('[REDACTED_PARAMS]'));

      expect(sanitized, isNot(contains('user@domain.com')));
      expect(sanitized, contains('[REDACTED_EMAIL]'));

      expect(sanitized, isNot(contains('C:\\Users\\Developer')));
      expect(sanitized, contains('[USER_DIR]'));
    });

    test('records local crash reports and retrieves them', () async {
      expect(CrashReportingService.instance.getReports(), isEmpty);

      await CrashReportingService.instance.recordError(
        Exception('Network stream buffer overflow at 10.0.0.1'),
        StackTrace.current,
        context: 'AudioPlayerService.setUrl',
      );

      final reports = CrashReportingService.instance.getReports();
      expect(reports.length, 1);
      expect(reports.first.error, contains('[REDACTED_IP]'));
      expect(reports.first.context, 'AudioPlayerService.setUrl');

      final exported = CrashReportingService.instance.exportReportsAsText();
      expect(exported, contains('=== Prism Music Diagnostic Reports ==='));
      expect(exported, contains('Total entries: 1'));

      await CrashReportingService.instance.clearReports();
      expect(CrashReportingService.instance.getReports(), isEmpty);
    });

    test('crash reporting opt-in toggle persists in SettingsService', () async {
      await SettingsService.instance.setCrashReportingEnabled(false);
      expect(SettingsService.instance.crashReportingEnabled, isFalse);

      await SettingsService.instance.setCrashReportingEnabled(true);
      expect(SettingsService.instance.crashReportingEnabled, isTrue);

      await SettingsService.instance.setSentryDsn('https://public@sentry.example.com/42');
      expect(SettingsService.instance.sentryDsn, 'https://public@sentry.example.com/42');
    });
  });
}

