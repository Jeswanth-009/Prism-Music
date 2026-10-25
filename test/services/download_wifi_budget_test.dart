import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prism_music/core/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('download_wifi_budget_test_');
    Hive.init(tempDir.path);
    await SettingsService.instance.initialize();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Download Wi-Fi and Data Budget Settings', () {
    test('downloadWifiOnly defaults to true and can be updated', () async {
      final settings = SettingsService.instance;
      expect(settings.downloadWifiOnly, isTrue);

      await settings.setDownloadWifiOnly(false);
      expect(settings.downloadWifiOnly, isFalse);

      await settings.setDownloadWifiOnly(true);
      expect(settings.downloadWifiOnly, isTrue);
    });

    test('cellularDataSaver defaults to false and can be updated', () async {
      final settings = SettingsService.instance;
      expect(settings.cellularDataSaver, isFalse);

      await settings.setCellularDataSaver(true);
      expect(settings.cellularDataSaver, isTrue);

      await settings.setCellularDataSaver(false);
      expect(settings.cellularDataSaver, isFalse);
    });

    test('offlineArtworkPersistence defaults to true and can be updated', () async {
      final settings = SettingsService.instance;
      expect(settings.offlineArtworkPersistence, isTrue);

      await settings.setOfflineArtworkPersistence(false);
      expect(settings.offlineArtworkPersistence, isFalse);

      await settings.setOfflineArtworkPersistence(true);
      expect(settings.offlineArtworkPersistence, isTrue);
    });
  });
}
