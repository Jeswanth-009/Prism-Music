import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/dsp/ebu_r128.dart';

void main() {
  group('EBU R128 Loudness Meter', () {
    test('silent buffer returns -70.0 LUFS and low peak', () {
      final meter = EbuR128LoudnessMeter(sampleRate: 44100);
      final silence = Float32List(44100); // 1 second of silence

      final lufs = meter.calculateIntegratedLufs(silence);
      final peak = meter.calculateTruePeakDbfs(silence);

      expect(lufs, equals(-70.0));
      expect(peak, equals(-100.0));
    });

    test('1 kHz full-scale sine wave measures expected loudness and 0 dBFS peak', () {
      final meter = EbuR128LoudnessMeter(sampleRate: 44100);
      const durationSeconds = 1.0;
      final numSamples = (44100 * durationSeconds).round();
      final samples = Float32List(numSamples);

      for (int i = 0; i < numSamples; i++) {
        final t = i / 44100.0;
        // 1 kHz sine at 1.0 peak
        samples[i] = math.sin(2.0 * math.pi * 1000.0 * t);
      }

      final lufs = meter.calculateIntegratedLufs(samples);
      final peak = meter.calculateTruePeakDbfs(samples);

      // Peak should be 0.0 dBFS
      expect(peak, closeTo(0.0, 0.2));
      // Full scale 1 kHz sine with K-weighting measures ~ -3.0 LUFS
      expect(lufs, inInclusiveRange(-6.0, 0.0));
    });

    test('halved amplitude drops peak by approximately 6 dB', () {
      final meter = EbuR128LoudnessMeter(sampleRate: 44100);
      final samples = Float32List(44100);

      for (int i = 0; i < 44100; i++) {
        final t = i / 44100.0;
        samples[i] = 0.5 * math.sin(2.0 * math.pi * 1000.0 * t);
      }

      final peak = meter.calculateTruePeakDbfs(samples);
      expect(peak, closeTo(-6.0, 0.2));
    });
  });
}
