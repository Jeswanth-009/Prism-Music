import 'dart:math' as math;
import 'dart:typed_data';

/// Represents a complex number for audio frequency domain analysis.
class Complex {
  final double real;
  final double imag;

  const Complex(this.real, [this.imag = 0.0]);

  Complex operator +(Complex other) =>
      Complex(real + other.real, imag + other.imag);

  Complex operator -(Complex other) =>
      Complex(real - other.real, imag - other.imag);

  Complex operator *(Complex other) => Complex(
        real * other.real - imag * other.imag,
        real * other.imag + imag * other.real,
      );

  Complex scale(double scalar) => Complex(real * scalar, imag * scalar);

  double get magnitude => math.sqrt(real * real + imag * imag);

  double get phase => math.atan2(imag, real);

  double get power => real * real + imag * imag;

  @override
  String toString() => 'Complex($real, $imag)';
}

/// Computes Cooley-Tukey Radix-2 Fast Fourier Transform.
/// Padded to the next power of 2 if length is not already a power of 2.
List<Complex> fft(List<Complex> input) {
  final n = input.length;
  if (n <= 1) return input;

  // Check if n is power of 2; if not, pad with zeros
  final powerOfTwo = _nextPowerOfTwo(n);
  List<Complex> padded;
  if (powerOfTwo != n) {
    padded = List<Complex>.filled(powerOfTwo, const Complex(0.0, 0.0));
    for (int i = 0; i < n; i++) {
      padded[i] = input[i];
    }
  } else {
    padded = List<Complex>.from(input);
  }

  return _fftRadix2(padded);
}

/// Recursive radix-2 Decimation-In-Time FFT implementation.
List<Complex> _fftRadix2(List<Complex> x) {
  final n = x.length;
  if (n <= 1) return x;

  final even = List<Complex>.generate(n ~/ 2, (i) => x[i * 2]);
  final odd = List<Complex>.generate(n ~/ 2, (i) => x[i * 2 + 1]);

  final dEven = _fftRadix2(even);
  final dOdd = _fftRadix2(odd);

  final result = List<Complex>.filled(n, const Complex(0.0, 0.0));
  for (int k = 0; k < n ~/ 2; k++) {
    final angle = -2.0 * math.pi * k / n;
    final wk = Complex(math.cos(angle), math.sin(angle));
    final t = wk * dOdd[k];
    result[k] = dEven[k] + t;
    result[k + n ~/ 2] = dEven[k] - t;
  }
  return result;
}

/// Computes the Inverse Fast Fourier Transform (IFFT).
List<Complex> ifft(List<Complex> input) {
  final n = input.length;
  if (n <= 1) return input;

  // Conjugate the complex numbers
  final conj = input.map((c) => Complex(c.real, -c.imag)).toList();

  // Forward FFT on conjugate
  final transformed = fft(conj);

  // Conjugate again and divide by n
  final scaleFactor = 1.0 / transformed.length;
  return transformed
      .map((c) => Complex(c.real * scaleFactor, -c.imag * scaleFactor))
      .toList();
}

/// Generates a Hann (Hanning) window of specified [length].
Float64List hannWindow(int length) {
  final window = Float64List(length);
  if (length <= 1) {
    if (length == 1) window[0] = 1.0;
    return window;
  }
  final denom = length - 1;
  for (int i = 0; i < length; i++) {
    window[i] = 0.5 * (1.0 - math.cos(2.0 * math.pi * i / denom));
  }
  return window;
}

/// Calculates power spectrum $|X[k]|^2 / N$ for non-negative frequencies up to Nyquist.
Float64List powerSpectrum(List<Complex> fftOutput) {
  final n = fftOutput.length;
  final half = n ~/ 2 + 1;
  final spectrum = Float64List(half);
  final norm = 1.0 / n;
  for (int i = 0; i < half; i++) {
    spectrum[i] = fftOutput[i].power * norm;
  }
  return spectrum;
}

int _nextPowerOfTwo(int x) {
  if (x <= 1) return 1;
  int p = 1;
  while (p < x) {
    p <<= 1;
  }
  return p;
}
