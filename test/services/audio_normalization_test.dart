import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/audio_normalization_service.dart';
import 'package:prism_music/domain/entities/song.dart';

void main() {
  final service = AudioNormalizationService.instance;

  Song makeSong(String id, MusicSource source) {
    return Song(
      id: id,
      title: 'Title $id',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(seconds: 180),
      thumbnails: const Thumbnails(),
      source: source,
    );
  }

  group('AudioNormalizationService', () {
    test('returns 1.0 when normalization is disabled', () {
      final song = makeSong('s1', MusicSource.jiosaavn);
      final factor = service.computeGainFactor(song, enabled: false);
      expect(factor, 1.0);
    });

    test('balanced target normalizes hot tracks down and quiet tracks up', () {
      final youtubeSong = makeSong('yt', MusicSource.youtube);
      final jioSong = makeSong('jio', MusicSource.jiosaavn);
      final localSong = makeSong('local', MusicSource.local);

      // YouTube: estimated -14 LUFS -> 0 dB -> factor 1.0
      final ytFactor = service.computeGainFactor(youtubeSong, enabled: true, targetMode: 'balanced', preampDb: 0.0);
      expect(ytFactor, closeTo(1.0, 0.01));

      // JioSaavn: estimated -11.5 LUFS -> -2.5 dB -> factor ~0.75 (volume attenuated to avoid blasting)
      final jioFactor = service.computeGainFactor(jioSong, enabled: true, targetMode: 'balanced', preampDb: 0.0);
      expect(jioFactor, lessThan(1.0));
      expect(jioFactor, closeTo(0.75, 0.05));

      // Local: estimated -16 LUFS -> +2.0 dB -> factor ~1.25 (volume boosted)
      final localFactor = service.computeGainFactor(localSong, enabled: true, targetMode: 'balanced', preampDb: 0.0);
      expect(localFactor, greaterThan(1.0));
    });

    test('respects quiet and loud targets', () {
      final song = makeSong('s', MusicSource.youtube); // -14 LUFS

      // Quiet (-18 LUFS) -> -4 dB -> factor ~0.63
      final quietFactor = service.computeGainFactor(song, enabled: true, targetMode: 'quiet', preampDb: 0.0);
      expect(quietFactor, closeTo(0.63, 0.05));

      // Loud (-11 LUFS) -> +3 dB -> factor ~1.41 capped to max 1.25
      final loudFactor = service.computeGainFactor(song, enabled: true, targetMode: 'loud', preampDb: 0.0);
      expect(loudFactor, 1.25);
    });

    test('prevents hard clipping by clamping to 1.25 max factor', () {
      final quietSong = makeSong('q', MusicSource.local);
      // Extremely high preamp +12 dB
      final factor = service.computeGainFactor(quietSong, enabled: true, preampDb: 12.0);
      expect(factor, 1.25);
    });
  });
}
