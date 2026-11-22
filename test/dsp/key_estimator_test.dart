import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/dsp/key_estimator.dart';

void main() {
  group('Key Estimator', () {
    test('short buffer fallback defaults to C Major / 8B', () {
      final estimator = KeyEstimator();
      final result = estimator.estimate(Float32List(100));
      expect(result.keyName, equals('C Major'));
      expect(result.camelotCode, equals('8B'));
    });

    test('analyzes A440 tone and identifies key with high confidence', () {
      final estimator = KeyEstimator(sampleRate: 44100);
      const durationSeconds = 1.0;
      final numSamples = (44100 * durationSeconds).round();
      final samples = Float32List(numSamples);

      // A4 = 440 Hz
      for (int i = 0; i < numSamples; i++) {
        samples[i] = math.sin(2.0 * math.pi * 440.0 * (i / 44100.0));
      }

      final result = estimator.estimate(samples);
      expect(result.confidence, greaterThan(0.3));
      expect(result.camelotCode, isNotEmpty);
      expect(result.keyName, contains(RegExp(r'A|F#|D')));
    });
  });
}
