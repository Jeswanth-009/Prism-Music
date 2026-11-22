import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/dsp/biquad_equalizer.dart';

void main() {
  group('Biquad Equalizer', () {
    test('flat gains pass audio samples through transparently', () {
      final eq = BiquadEqualizer(sampleRate: 44100);
      final input = Float32List(100);
      for (int i = 0; i < 100; i++) {
        input[i] = 0.5 * math.sin(2.0 * math.pi * 1000.0 * (i / 44100.0));
      }

      final output = eq.process(input);
      expect(output.length, equals(input.length));
      for (int i = 0; i < 100; i++) {
        expect(output[i], closeTo(input[i], 1e-4));
      }
    });

    test('boosting 1 kHz band amplifies 1 kHz tone', () {
      final eq = BiquadEqualizer(sampleRate: 44100);
      // Band index 5 is 1000 Hz
      eq.setBandGain(5, 6.0); // +6 dB boost (~2x amplitude)

      final input = Float32List(1000);
      for (int i = 0; i < 1000; i++) {
        input[i] = 0.2 * math.sin(2.0 * math.pi * 1000.0 * (i / 44100.0));
      }

      final output = eq.process(input);

      // Measure RMS of input vs output after filter settles
      double inSum = 0.0;
      double outSum = 0.0;
      for (int i = 200; i < 1000; i++) {
        inSum += input[i] * input[i];
        outSum += output[i] * output[i];
      }

      final inRms = math.sqrt(inSum / 800);
      final outRms = math.sqrt(outSum / 800);

      expect(outRms, greaterThan(inRms * 1.5));
    });

    test('cutting 1 kHz band attenuates 1 kHz tone', () {
      final eq = BiquadEqualizer(sampleRate: 44100);
      eq.setBandGain(5, -9.0); // -9 dB cut

      final input = Float32List(1000);
      for (int i = 0; i < 1000; i++) {
        input[i] = 0.4 * math.sin(2.0 * math.pi * 1000.0 * (i / 44100.0));
      }

      final output = eq.process(input);

      double inSum = 0.0;
      double outSum = 0.0;
      for (int i = 200; i < 1000; i++) {
        inSum += input[i] * input[i];
        outSum += output[i] * output[i];
      }

      final inRms = math.sqrt(inSum / 800);
      final outRms = math.sqrt(outSum / 800);

      expect(outRms, lessThan(inRms * 0.7));
    });
  });
}
