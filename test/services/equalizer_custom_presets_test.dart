import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/models/reverb_preset.dart';
import 'package:prism_music/core/services/equalizer_service.dart';
import 'package:prism_music/core/services/settings_service.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    initTestHive('equalizer_custom');
    await SettingsService.instance.initialize();
  });

  group('Equalizer Custom Presets & Per-Song EQ', () {
    test('EqualizerPreset serialization roundtrip works', () {
      const preset = EqualizerPreset(
        name: 'My V-Shape',
        bassBoost: 0.85,
        treble: 0.75,
        reverb: ReverbPreset.smallRoom,
        isCustom: true,
      );

      final map = preset.toMap();
      expect(map['name'], 'My V-Shape');
      expect(map['bassBoost'], 0.85);
      expect(map['treble'], 0.75);
      expect(map['reverb'], 'smallRoom');
      expect(map['isCustom'], isTrue);

      final decoded = EqualizerPreset.fromMap(map);
      expect(decoded.name, 'My V-Shape');
      expect(decoded.bassBoost, 0.85);
      expect(decoded.treble, 0.75);
      expect(decoded.reverb, ReverbPreset.smallRoom);
      expect(decoded.isCustom, isTrue);
    });

    test('saves and deletes custom user preset', () async {
      final service = EqualizerService();
      await service.setBassBoost(0.9, true);
      await service.setTreble(0.8);
      await service.setReverb(ReverbPreset.plate);

      await service.saveCustomPreset('Heavy Bass');

      expect(service.currentPreset, 'Heavy Bass');
      expect(service.customPresets.containsKey('Heavy Bass'), isTrue);
      expect(service.allPresets.containsKey('Heavy Bass'), isTrue);

      // Verify persistence in a new instance
      final service2 = EqualizerService();
      expect(service2.customPresets.containsKey('Heavy Bass'), isTrue);
      final loaded = service2.customPresets['Heavy Bass']!;
      expect(loaded.bassBoost, 0.9);
      expect(loaded.treble, 0.8);
      expect(loaded.reverb, ReverbPreset.plate);

      // Delete custom preset
      await service2.deleteCustomPreset('Heavy Bass');
      expect(service2.customPresets.containsKey('Heavy Bass'), isFalse);
      expect(service2.allPresets.containsKey('Heavy Bass'), isFalse);
    });

    test('persists and recalls per-song EQ settings', () async {
      final service = EqualizerService();
      const songId = 'test_song_123';

      expect(service.hasSongEqualizer(songId), isFalse);

      await service.setBassBoost(0.7, true);
      await service.setTreble(0.65);
      await service.setReverb(ReverbPreset.mediumRoom);
      await service.saveCurrentForSong(songId);

      expect(service.hasSongEqualizer(songId), isTrue);

      // Switch to different global preset
      await service.applyPreset('Rock');
      expect(service.currentPreset, 'Rock');

      // Now apply song-specific EQ
      final applied = await service.applyPresetForSong(songId);
      expect(applied, isTrue);
      expect(service.bassBoostLevel, 0.7);
      expect(service.trebleLevel, 0.65);
      expect(service.reverbPreset, ReverbPreset.mediumRoom);

      // Clear for song
      await service.clearForSong(songId);
      expect(service.hasSongEqualizer(songId), isFalse);
    });
  });
}
