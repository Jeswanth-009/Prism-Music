import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/diagnostics_service.dart';
import 'package:prism_music/presentation/widgets/settings/about_diagnostics_sheet.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DiagnosticsService', () {
    test('collectDiagnostics collects valid system metadata', () async {
      final data = await DiagnosticsService.instance.collectDiagnostics();

      expect(data.containsKey('app'), isTrue);
      expect(data.containsKey('platform'), isTrue);
      expect(data.containsKey('audioSettings'), isTrue);
      expect(data.containsKey('storage'), isTrue);

      final app = data['app'] as Map<String, dynamic>;
      expect(app['name'], isNotNull);
      expect(app['buildMode'], isNotNull);

      final platform = data['platform'] as Map<String, dynamic>;
      expect(platform['os'], isNotNull);
    });

    test('formatDiagnosticsText produces readable markdown report', () async {
      final text = await DiagnosticsService.instance.formatDiagnosticsText();

      expect(text.contains('### Prism Music Diagnostics'), isTrue);
      expect(text.contains('**App Version:**'), isTrue);
      expect(text.contains('**Operating System:**'), isTrue);
      expect(text.contains('**Audio Quality:**'), isTrue);
    });
  });

  group('About Diagnostics Sheet', () {
    testWidgets('displays diagnostics modal with copy button', (tester) async {
      final mockData = {
        'app': {
          'name': 'Prism Music',
          'version': '1.0.0',
          'buildNumber': '1',
          'packageName': 'com.prism.music',
          'buildMode': 'Debug',
        },
        'platform': {
          'os': 'android',
          'osVersion': '14',
          'dartVersion': '3.5.0',
        },
        'audioSettings': {
          'quality': 'high',
          'fastStart': true,
          'autoPlay': true,
          'crossfade': false,
          'equalizerPreset': 'Normal',
          'bassBoost': false,
        },
        'storage': {
          'cacheUsage': '12.5 MB',
          'backupItems': 42,
          'latestBackup': 'Oct 22, 2026',
        },
      };

      await tester.pumpWidget(
        wrapForTests(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showPrismDiagnosticsSheet(
                context,
                initialData: mockData,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('System Diagnostics'), findsOneWidget);
      expect(find.text('App Version'), findsOneWidget);
      expect(find.text('Audio Quality'), findsOneWidget);
      expect(find.text('Copy diagnostics to clipboard'), findsOneWidget);
    });
  });
}
