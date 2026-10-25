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
    tempDir = await Directory.systemTemp.createTemp('artifact_sheet_test_');
    Hive.init(tempDir.path);
    await SettingsService.instance.initialize();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('DiagnosticsSheetContent displays Artifact & Checksum Verification button and opens dialog',
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
    );

    await tester.pumpAndSettle();

    final verifyButton = find.text('Artifact & Checksum Verification');
    expect(verifyButton, findsOneWidget);

    await tester.tap(verifyButton);
    await tester.pumpAndSettle();

    expect(find.text('Verified Artifact Downloads'), findsOneWidget);
    expect(find.textContaining('Detected Architecture:'), findsOneWidget);
    expect(find.text('Verify SHA-256 Checksum Command:'), findsOneWidget);
    expect(find.text('Copy Command'), findsOneWidget);
    expect(find.text('View Releases'), findsOneWidget);
  });
}
