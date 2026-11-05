import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/presentation/blocs/player/mixins/sleep_timer_mixin.dart';
import 'package:prism_music/presentation/blocs/player/player_event.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';

class _TestSleepTimerConsumer with SleepTimerMixin {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('sleep_timer_bedtime_test_');
    Hive.init(tempDir.path);
    await SettingsService.instance.initialize();
  });

  group('SleepTimerMixin Bedtime Mode', () {
    late _TestSleepTimerConsumer consumer;

    setUp(() {
      consumer = _TestSleepTimerConsumer();
    });

    tearDown(() {
      consumer.cancelSleepTimer();
    });

    test('standard sleep timer executes onElapsed callback', () async {
      bool elapsed = false;
      consumer.startSleepTimer(
        const Duration(milliseconds: 50),
        onElapsed: () => elapsed = true,
      );

      expect(consumer.isSleepTimerActive, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(elapsed, isTrue);
      expect(consumer.isSleepTimerActive, isFalse);
    });

    test('bedtime mode steps down volume factor smoothly', () async {
      final fadeFactors = <double>[];
      bool restored = false;
      bool elapsed = false;

      consumer.startSleepTimer(
        const Duration(milliseconds: 150),
        bedtimeMode: true,
        fadeDuration: const Duration(milliseconds: 120),
        onVolumeFade: (factor) {
          fadeFactors.add(factor);
        },
        onRestoreVolume: () {
          restored = true;
        },
        onElapsed: () {
          elapsed = true;
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(elapsed, isTrue);
      expect(restored, isTrue);
      expect(fadeFactors, isNotEmpty);
      // Verify volume monotonically decreases
      for (int i = 0; i < fadeFactors.length - 1; i++) {
        expect(fadeFactors[i], greaterThanOrEqualTo(fadeFactors[i + 1]));
      }
    });

    test('cancelSleepTimer cancels timer and triggers onRestoreVolume', () async {
      bool restored = false;
      bool elapsed = false;

      consumer.startSleepTimer(
        const Duration(seconds: 10),
        bedtimeMode: true,
        onRestoreVolume: () {
          restored = true;
        },
        onElapsed: () {
          elapsed = true;
        },
      );

      expect(consumer.isSleepTimerActive, isTrue);
      consumer.cancelSleepTimer(onRestoreVolume: () => restored = true);
      expect(consumer.isSleepTimerActive, isFalse);
      expect(restored, isTrue);
      expect(elapsed, isFalse);
    });
  });

  group('SettingsService sleepTimerBedtimeMode', () {
    test('defaults to true', () {
      final settings = SettingsService.instance;
      expect(settings.sleepTimerBedtimeMode, isTrue);
    });

    test('persists updated bedtime mode value', () async {
      final settings = SettingsService.instance;
      await settings.setSleepTimerBedtimeMode(false);
      expect(settings.sleepTimerBedtimeMode, isFalse);

      await settings.setSleepTimerBedtimeMode(true);
      expect(settings.sleepTimerBedtimeMode, isTrue);
    });
  });

  group('SetSleepTimerEvent & PlayerState Bedtime Mode props', () {
    test('SetSleepTimerEvent carries bedtimeMode property', () {
      const eventWithBedtime = SetSleepTimerEvent(
        Duration(minutes: 30),
        bedtimeMode: true,
      );
      expect(eventWithBedtime.bedtimeMode, isTrue);
      expect(eventWithBedtime.props, contains(true));

      const eventWithoutBedtime = SetSleepTimerEvent(
        Duration(minutes: 30),
        bedtimeMode: false,
      );
      expect(eventWithoutBedtime.bedtimeMode, isFalse);
    });

    test('PlayerState updates sleepTimerBedtimeMode cleanly in copyWith', () {
      const initial = PlayerState();
      expect(initial.sleepTimerBedtimeMode, isFalse);

      final withBedtime = initial.copyWith(sleepTimerBedtimeMode: true);
      expect(withBedtime.sleepTimerBedtimeMode, isTrue);

      final cleared = withBedtime.copyWith(clearSleepTimer: true);
      expect(cleared.sleepTimerBedtimeMode, isFalse);
    });
  });
}
