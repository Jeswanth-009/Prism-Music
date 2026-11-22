import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/dsp/audio_math.dart';

void main() {
  group('Complex Numbers', () {
    test('addition, subtraction, and multiplication', () {
      const a = Complex(3.0, 4.0);
      const b = Complex(1.0, 2.0);

      final sum = a + b;
      expect(sum.real, equals(4.0));
      expect(sum.imag, equals(6.0));

      final diff = a - b;
      expect(diff.real, equals(2.0));
      expect(diff.imag, equals(2.0));

      // (3 + 4i)(1 + 2i) = 3 + 6i + 4i - 8 = -5 + 10i
      final prod = a * b;
      expect(prod.real, equals(-5.0));
      expect(prod.imag, equals(10.0));
    });

    test('magnitude and phase', () {
      const c = Complex(3.0, 4.0);
      expect(c.magnitude, closeTo(5.0, 1e-9));
      expect(c.power, closeTo(25.0, 1e-9));
      expect(c.phase, closeTo(math.atan2(4.0, 3.0), 1e-9));
    });
  });

  group('Radix-2 FFT and IFFT', () {
    test('impulse response yields flat spectrum', () {
      final input = [
        const Complex(1.0, 0.0),
        const Complex(0.0, 0.0),
        const Complex(0.0, 0.0),
        const Complex(0.0, 0.0),
      ];

      final output = fft(input);
      expect(output.length, equals(4));
      for (final val in output) {
        expect(val.magnitude, closeTo(1.0, 1e-9));
      }
    });

    test('round-trip FFT then IFFT reconstructs input', () {
      final input = [
        const Complex(1.0, 0.5),
        const Complex(-2.0, 1.2),
        const Complex(0.5, -0.8),
        const Complex(3.14, 0.0),
      ];

      final transformed = fft(input);
      final reconstructed = ifft(transformed);

      expect(reconstructed.length, equals(input.length));
      for (int i = 0; i < input.length; i++) {
        expect(reconstructed[i].real, closeTo(input[i].real, 1e-6));
        expect(reconstructed[i].imag, closeTo(input[i].imag, 1e-6));
      }
    });

    test('pads non-power-of-2 input to next power of 2', () {
      final input = [
        const Complex(1.0, 0.0),
        const Complex(2.0, 0.0),
        const Complex(3.0, 0.0),
      ];

      final output = fft(input);
      expect(output.length, equals(4));
    });
  });

  group('Hann Window & Power Spectrum', () {
    test('hann window has correct endpoints and symmetry', () {
      final window = hannWindow(8);
      expect(window.length, equals(8));
      expect(window[0], closeTo(0.0, 1e-9));
      expect(window[7], closeTo(0.0, 1e-9));
      expect(window[1], closeTo(window[6], 1e-9));
      expect(window[2], closeTo(window[5], 1e-9));
      expect(window[3], closeTo(window[4], 1e-9));
    });

    test('power spectrum is non-negative and has length N/2 + 1', () {
      final input = List.generate(8, (i) => Complex(math.sin(i.toDouble()), 0.0));
      final spectrum = powerSpectrum(fft(input));
      expect(spectrum.length, equals(5));
      for (final p in spectrum) {
        expect(p, greaterThanOrEqualTo(0.0));
      }
    });
  });
}
