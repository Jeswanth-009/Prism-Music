import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/crossfade_engine.dart';

void main() {
  group('CrossfadeEngine Equal-Power Curves', () {
    test('at progress 0.0, outgoing is 1.0 and incoming is 0.0', () {
      final (outGain, inGain) = CrossfadeEngine.computeEqualPowerGains(
        Duration.zero,
        const Duration(seconds: 5),
      );
      expect(outGain, closeTo(1.0, 1e-6));
      expect(inGain, closeTo(0.0, 1e-6));
    });

    test('at progress 1.0, outgoing is 0.0 and incoming is 1.0', () {
      final (outGain, inGain) = CrossfadeEngine.computeEqualPowerGains(
        const Duration(seconds: 5),
        const Duration(seconds: 5),
      );
      expect(outGain, closeTo(0.0, 1e-6));
      expect(inGain, closeTo(1.0, 1e-6));
    });

    test('at midpoint (0.5), sum of squares equals 1.0 (constant power)', () {
      final (outGain, inGain) = CrossfadeEngine.computeEqualPowerGains(
        const Duration(milliseconds: 2500),
        const Duration(seconds: 5),
      );
      // cos(pi/4) = sin(pi/4) = 1/sqrt(2) ~= 0.7071
      expect(outGain, closeTo(1.0 / math.sqrt(2.0), 1e-3));
      expect(inGain, closeTo(1.0 / math.sqrt(2.0), 1e-3));

      final totalPower = outGain * outGain + inGain * inGain;
      expect(totalPower, closeTo(1.0, 1e-6));
    });
  });
}
