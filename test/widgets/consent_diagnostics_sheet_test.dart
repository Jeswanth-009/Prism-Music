import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/presentation/widgets/settings/about_diagnostics_sheet.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('consent_sheet_test_');
    Hive.init(tempDir.path);
    await SettingsService.instance.initialize();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('DiagnosticsSheetContent displays consent switch and local export button',
      (tester) async {
    final fakeData = {
      'app': {
        'name': 'Prism Music',
        'version': '1.0.0',
        'buildNumber': '10',
        'packageName': 'com.prism.music',
        'buildMode': 'Debug',
      },
      'platform': {
        'os': 'Android',
        'osVersion': '14',
        'dartVersion': '3.38.0',
      },
      'audioSettings': {
        'quality': 'high',
        'fastStart': true,
        'autoPlay': false,
        'crossfade': false,
        'equalizerPreset': 'Default',
        'bassBoost': false,
      },
      'storage': {
        'cacheUsage': '12 MB',
        'backupItems': 4,
        'latestBackup': 'Today',
      },
    };

    await pumpTestWidget(
      tester,
      SingleChildScrollView(
        child: DiagnosticsSheetContent(initialData: fakeData),
      ),
      size: const Size(500, 1200),
    );
    await tester.pump();

    expect(find.text('System Diagnostics'), findsOneWidget);
    expect(find.text('Anonymous Diagnostics Consent'), findsOneWidget);
    expect(
      find.text('Export Sanitized Diagnostics (Local Only)'),
      findsOneWidget,
    );
  });
}
