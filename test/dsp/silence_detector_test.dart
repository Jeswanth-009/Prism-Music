import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/dsp/silence_detector.dart';

void main() {
  group('Silence Detector', () {
    test('detects lead-in and tail silence accurately', () {
      final detector = SilenceDetector(sampleRate: 44100, thresholdDbfs: -50.0);
      const totalSeconds = 2.0;
      final totalSamples = (44100 * totalSeconds).round();
      final samples = Float32List(totalSamples);

      // 0.5s silence at start (samples 0 .. 22050)
      // 1.0s active audio in middle (samples 22050 .. 66150)
      // 0.5s silence at tail (samples 66150 .. 88200)
      for (int i = 22050; i < 66150; i++) {
        samples[i] = 0.5 * math.sin(2.0 * math.pi * 440.0 * (i / 44100.0));
      }

      final result = detector.detect(samples);

      expect(result.leadSilenceSeconds, closeTo(0.5, 0.06));
      expect(result.tailSilenceSeconds, closeTo(0.5, 0.06));
      expect(result.trimStartSample, greaterThanOrEqualTo(20000));
      expect(result.trimEndSample, lessThanOrEqualTo(70000));
    });

    test('empty buffer handles gracefully', () {
      final detector = SilenceDetector();
      final result = detector.detect(Float32List(0));
      expect(result.leadSilenceSeconds, equals(0.0));
      expect(result.tailSilenceSeconds, equals(0.0));
    });
  });
}
