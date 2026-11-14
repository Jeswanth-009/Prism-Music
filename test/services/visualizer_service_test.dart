import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/core/services/visualizer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VisualizerService', () {
    test('computes zero amplitudes when paused or muted', () {
      final service = VisualizerService.instance;

      final pausedAmps = service.computeAmplitudes(
        timeSeconds: 1.5,
        isPlaying: false,
        volume: 1.0,
        count: 16,
      );
      expect(pausedAmps.length, equals(16));
      expect(pausedAmps.every((a) => a == 0.0), isTrue);

      final mutedAmps = service.computeAmplitudes(
        timeSeconds: 1.5,
        isPlaying: true,
        volume: 0.0,
        count: 16,
      );
      expect(mutedAmps.every((a) => a == 0.0), isTrue);
    });

    test('computes dynamic amplitudes when playing with volume', () {
      final service = VisualizerService.instance;

      final amps = service.computeAmplitudes(
        timeSeconds: 2.0,
        isPlaying: true,
        volume: 0.8,
        count: 24,
      );

      expect(amps.length, equals(24));
      expect(amps.any((a) => a > 0.0), isTrue);
      // All values bounded between 0.0 and 1.0
      expect(amps.every((a) => a >= 0.0 && a <= 1.0), isTrue);
    });

    test('cycleStyle transitions through visualizer modes', () async {
      final service = VisualizerService.instance;

      await service.setStyle(VisualizerStyle.bars);
      expect(service.style, equals(VisualizerStyle.bars));

      final next1 = await service.cycleStyle();
      expect(next1, equals(VisualizerStyle.wave));

      final next2 = await service.cycleStyle();
      expect(next2, equals(VisualizerStyle.pulse));

      final next3 = await service.cycleStyle();
      expect(next3, equals(VisualizerStyle.off));

      final next4 = await service.cycleStyle();
      expect(next4, equals(VisualizerStyle.bars));
    });
  });
}
