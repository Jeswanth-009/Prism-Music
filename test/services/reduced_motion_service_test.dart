import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prism_music/core/services/settings_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('reduced_motion_service_test_');
    Hive.init(tempDir.path);
    await SettingsService.instance.initialize();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Reduced Motion Options', () {
    test('SettingsService reducedMotionMode defaults to false and toggles', () async {
      final settings = SettingsService.instance;
      expect(settings.reducedMotionMode, isFalse);

      await settings.setReducedMotionMode(true);
      expect(settings.reducedMotionMode, isTrue);

      await settings.setReducedMotionMode(false);
      expect(settings.reducedMotionMode, isFalse);
    });

    test('PrismMotion respects reduced motion mode state', () async {
      final settings = SettingsService.instance;
      await settings.setReducedMotionMode(true);
      expect(settings.reducedMotionMode, isTrue);

      await settings.setReducedMotionMode(false);
      expect(settings.reducedMotionMode, isFalse);
    });
  });
}
