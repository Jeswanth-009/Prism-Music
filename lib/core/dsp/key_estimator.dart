import 'dart:math' as math;
import 'dart:typed_data';
import 'audio_math.dart';

/// Result of musical key estimation.
class KeyAnalysisResult {
  final String keyName; // e.g. "C Major", "A Minor"
  final String camelotCode; // e.g. "8B", "8A"
  final double confidence; // Pearson correlation [0.0 - 1.0]

  const KeyAnalysisResult({
    required this.keyName,
    required this.camelotCode,
    required this.confidence,
  });

  @override
  String toString() => '$keyName ($camelotCode, conf: ${(confidence * 100).toStringAsFixed(1)}%)';
}

/// Estimates musical key and Camelot wheel code from audio PCM using 12-band Chroma features.
class KeyEstimator {
  final int windowSize;
  final int hopSize;
  final int sampleRate;

  // Krumhansl-Schmuckler Key Profiles
  static const List<double> _majorProfile = [
    6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88
  ];
  static const List<double> _minorProfile = [
    6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17
  ];

  static const List<String> _pitchClassNames = [
    'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'
  ];

  static const List<String> _majorCamelot = [
    '8B',  // C
    '3B',  // Db / C#
    '10B', // D
    '5B',  // Eb
    '12B', // E
    '7B',  // F
    '2B',  // F#
    '9B',  // G
    '4B',  // Ab
    '11B', // A
    '6B',  // Bb
    '1B',  // B
  ];

  static const List<String> _minorCamelot = [
    '5A',  // C
    '12A', // C#
    '7A',  // D
    '2A',  // Eb / D#
    '9A',  // E
    '4A',  // F
    '11A', // F#
    '6A',  // G
    '1A',  // G# / Ab
    '8A',  // A
    '3A',  // Bb
    '10A', // B
  ];

  KeyEstimator({
    this.windowSize = 4096,
    this.hopSize = 2048,
    this.sampleRate = 44100,
  });

  /// Estimates the key of mono PCM samples.
  KeyAnalysisResult estimate(Float32List samples) {
    if (samples.length < windowSize) {
      return const KeyAnalysisResult(
        keyName: 'C Major',
        camelotCode: '8B',
        confidence: 0.5,
      );
    }

    final chroma = _extractChroma(samples);

    double bestCorr = -2.0;
    String bestKey = 'C Major';
    String bestCamelot = '8B';

    // Test all 12 major keys
    for (int shift = 0; shift < 12; shift++) {
      final shifted = _rotateList(_majorProfile, shift);
      final corr = _pearsonCorrelation(chroma, shifted);
      if (corr > bestCorr) {
        bestCorr = corr;
        bestKey = '${_pitchClassNames[shift]} Major';
        bestCamelot = _majorCamelot[shift];
      }
    }

    // Test all 12 minor keys
    for (int shift = 0; shift < 12; shift++) {
      final shifted = _rotateList(_minorProfile, shift);
      final corr = _pearsonCorrelation(chroma, shifted);
      if (corr > bestCorr) {
        bestCorr = corr;
        bestKey = '${_pitchClassNames[shift]} Minor';
        bestCamelot = _minorCamelot[shift];
      }
    }

    return KeyAnalysisResult(
      keyName: bestKey,
      camelotCode: bestCamelot,
      confidence: bestCorr.clamp(0.0, 1.0),
    );
  }

  List<double> _extractChroma(Float32List samples) {
    final chroma = List<double>.filled(12, 0.0);
    final window = hannWindow(windowSize);
    final numFrames = (samples.length - windowSize) ~/ hopSize;
    if (numFrames <= 0) return chroma;

    final freqResolution = sampleRate / windowSize;
    final minBin = (65.0 / freqResolution).floor().clamp(1, windowSize ~/ 2);
    final maxBin = (2000.0 / freqResolution).ceil().clamp(minBin, windowSize ~/ 2);

    for (int f = 0; f < numFrames; f++) {
      final offset = f * hopSize;
      final inputComplex = List<Complex>.generate(windowSize, (i) {
        return Complex(samples[offset + i].toDouble() * window[i], 0.0);
      });

      final spectrum = fft(inputComplex);

      for (int k = minBin; k <= maxBin; k++) {
        final freq = k * freqResolution;
        // Pitch class: 12 * log2(f / 440) + 69
        final midiNote = 12.0 * (math.log(freq / 440.0) / math.ln2) + 69.0;
        final pitchClass = (midiNote.round() % 12 + 12) % 12;
        chroma[pitchClass] += spectrum[k].power;
      }
    }

    // L2 Normalize
    double sumSq = 0.0;
    for (final val in chroma) {
      sumSq += val * val;
    }
    final norm = math.sqrt(sumSq);
    if (norm > 1e-9) {
      for (int i = 0; i < 12; i++) {
        chroma[i] /= norm;
      }
    }

    return chroma;
  }

  List<double> _rotateList(List<double> list, int shift) {
    final n = list.length;
    final result = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      result[(i + shift) % n] = list[i];
    }
    return result;
  }

  double _pearsonCorrelation(List<double> x, List<double> y) {
    final n = x.length;
    double meanX = x.reduce((a, b) => a + b) / n;
    double meanY = y.reduce((a, b) => a + b) / n;

    double num = 0.0;
    double denX = 0.0;
    double denY = 0.0;

    for (int i = 0; i < n; i++) {
      final dx = x[i] - meanX;
      final dy = y[i] - meanY;
      num += dx * dy;
      denX += dx * dx;
      denY += dy * dy;
    }

    final den = math.sqrt(denX * denY);
    if (den <= 1e-12) return 0.0;
    return num / den;
  }
}
