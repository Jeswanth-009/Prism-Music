import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/presentation/pages/settings_page.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('download_settings_widget_test_');
    Hive.init(tempDir.path);
    await SettingsService.instance.initialize();
    PackageInfo.setMockInitialValues(
      appName: 'Prism Music',
      packageName: 'com.prism.music',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('SettingsPage displays Wi-Fi only, data saver, and offline artwork options',
      (tester) async {
    await pumpTestWidget(
      tester,
      const SettingsPage(),
      size: const Size(600, 2400),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Download over Wi-Fi only'), findsOneWidget);
    expect(find.text('Cellular Data Saver'), findsOneWidget);
    expect(find.text('Save Offline Artwork'), findsOneWidget);
  });
}
