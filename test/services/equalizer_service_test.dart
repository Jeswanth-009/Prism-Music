import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/models/reverb_preset.dart';
import 'package:prism_music/core/services/equalizer_service.dart';
import 'package:prism_music/core/services/settings_service.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    initTestHive('equalizer');
    await SettingsService.instance.initialize();
  });

  group('EqualizerService', () {
    test('loads defaults on clean state', () {
      final service = EqualizerService();
      expect(service.currentPreset, 'Normal');
      expect(service.audioSessionId, 0);
      expect(service.isInitialized, isFalse);
    });

    test('persists preset selection across instances', () async {
      final service1 = EqualizerService();
      await service1.applyPreset('Bass Boost');
      expect(service1.currentPreset, 'Bass Boost');
      expect(service1.bassBoostLevel, 0.8);
      expect(service1.isBassBoostEnabled, isTrue);

      // Next instance restores persisted preset
      final service2 = EqualizerService();
      expect(service2.currentPreset, 'Bass Boost');
      expect(service2.bassBoostLevel, 0.8);
      expect(service2.isBassBoostEnabled, isTrue);
    });

    test('persists manual adjustments as Custom preset', () async {
      final service = EqualizerService();
      await service.setBassBoost(0.9, true);
      await service.setTreble(0.75);
      await service.setReverb(ReverbPreset.largeHall);

      expect(service.currentPreset, 'Custom');
      expect(service.bassBoostLevel, 0.9);
      expect(service.isBassBoostEnabled, isTrue);
      expect(service.trebleLevel, 0.75);
      expect(service.reverbPreset, ReverbPreset.largeHall);

      final service2 = EqualizerService();
      expect(service2.currentPreset, 'Custom');
      expect(service2.bassBoostLevel, 0.9);
      expect(service2.trebleLevel, 0.75);
      expect(service2.reverbPreset, ReverbPreset.largeHall);
    });

    test('reset restores Normal preset defaults and persists', () async {
      final service = EqualizerService();
      await service.applyPreset('Electronic');
      expect(service.currentPreset, 'Electronic');

      await service.reset();
      expect(service.currentPreset, 'Normal');
      expect(service.bassBoostLevel, 0.0);
      expect(service.isBassBoostEnabled, isFalse);
      expect(service.reverbPreset, ReverbPreset.none);

      final service2 = EqualizerService();
      expect(service2.currentPreset, 'Normal');
    });

    test('bindAudioSession ignores non-positive session IDs safely', () async {
      final service = EqualizerService();
      final bound = await service.bindAudioSession(0);
      expect(bound, isFalse);
      expect(service.audioSessionId, 0);
      expect(service.isSupported, isFalse);
    });
  });
}
