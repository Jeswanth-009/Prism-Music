import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/dsp/onset_detector.dart';

void main() {
  group('Onset Detector', () {
    test('handles empty or short buffer safely', () {
      final detector = OnsetDetector();
      final emptyResult = detector.analyze(Float32List(0));
      expect(emptyResult.bpm, equals(120.0));
      expect(emptyResult.onsetTimestamps, isEmpty);
    });

    test('detects simulated beat pulses and estimates BPM in musical range', () {
      final detector = OnsetDetector(sampleRate: 44100);
      const durationSeconds = 3.0;
      final numSamples = (44100 * durationSeconds).round();
      final samples = Float32List(numSamples);

      // 120 BPM = 2 beats per second (every 0.5s)
      final beatIntervalSamples = (44100 * 0.5).round();
      for (int i = 0; i < numSamples; i += beatIntervalSamples) {
        // Short burst of high frequency energy
        for (int b = 0; b < 256 && (i + b) < numSamples; b++) {
          samples[i + b] = math.sin(2.0 * math.pi * 800.0 * (b / 44100.0));
        }
      }

      final result = detector.analyze(samples);
      expect(result.bpm, inInclusiveRange(60.0, 200.0));
      expect(result.bestPartStartSeconds, greaterThanOrEqualTo(0.0));
      expect(result.bestPartEndSeconds, greaterThanOrEqualTo(result.bestPartStartSeconds));
    });
  });
}
