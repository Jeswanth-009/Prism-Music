import 'dart:math' as math;
import 'dart:typed_data';

/// Implements ITU-R BS.1770-4 / EBU R128 loudness measurement in pure Dart.
///
/// Computes:
/// - Integrated Loudness (LUFS) with dual gating (-70 LUFS absolute and -10 LU relative).
/// - True Peak estimation (dBFS).
class EbuR128LoudnessMeter {
  final int sampleRate;

  // Biquad coefficients for K-weighting Stage 1 (High shelf, ~1.5 kHz)
  late final double _b0Hs, _b1Hs, _b2Hs, _a1Hs, _a2Hs;

  // Biquad coefficients for K-weighting Stage 2 (High pass RLB, ~38 Hz)
  late final double _b0Hp, _b1Hp, _b2Hp, _a1Hp, _a2Hp;

  EbuR128LoudnessMeter({this.sampleRate = 44100}) {
    _initFilters();
  }

  void _initFilters() {
    final fs = sampleRate.toDouble();

    // Stage 1: High shelf filter (~4.0 dB boost at 1.5 kHz)
    final f0Hs = 1681.9744509555319;
    final gHs = 3.99984385397;
    final qHs = 0.7071752369554193;

    final kHs = math.tan(math.pi * f0Hs / fs);
    final vh = math.pow(10.0, gHs / 20.0).toDouble();
    final vb = math.pow(vh, 0.499666774155).toDouble();

    final a0Hs = 1.0 + kHs / qHs + kHs * kHs;
    _b0Hs = (vh + vb * kHs / qHs + kHs * kHs) / a0Hs;
    _b1Hs = 2.0 * (kHs * kHs - vh) / a0Hs;
    _b2Hs = (vh - vb * kHs / qHs + kHs * kHs) / a0Hs;
    _a1Hs = 2.0 * (kHs * kHs - 1.0) / a0Hs;
    _a2Hs = (1.0 - kHs / qHs + kHs * kHs) / a0Hs;

    // Stage 2: High pass filter (RLB, ~38 Hz)
    final f0Hp = 38.13547087613982;
    final qHp = 0.5003270373253953;
    final kHp = math.tan(math.pi * f0Hp / fs);

    final a0Hp = 1.0 + kHp / qHp + kHp * kHp;
    _b0Hp = 1.0 / a0Hp;
    _b1Hp = -2.0 / a0Hp;
    _b2Hp = 1.0 / a0Hp;
    _a1Hp = 2.0 * (kHp * kHp - 1.0) / a0Hp;
    _a2Hp = (1.0 - kHp / qHp + kHp * kHp) / a0Hp;
  }

  /// Filters mono PCM samples through the K-weighting filter cascade.
  Float64List _applyKWeighting(Float32List input) {
    final n = input.length;
    final stage1 = Float64List(n);

    // Direct Form II transposed for Stage 1
    double s1 = 0.0, s2 = 0.0;
    for (int i = 0; i < n; i++) {
      final x = input[i].toDouble();
      final y = _b0Hs * x + s1;
      s1 = _b1Hs * x - _a1Hs * y + s2;
      s2 = _b2Hs * x - _a2Hs * y;
      stage1[i] = y;
    }

    // Direct Form II transposed for Stage 2
    final stage2 = Float64List(n);
    s1 = 0.0;
    s2 = 0.0;
    for (int i = 0; i < n; i++) {
      final x = stage1[i];
      final y = _b0Hp * x + s1;
      s1 = _b1Hp * x - _a1Hp * y + s2;
      s2 = _b2Hp * x - _a2Hp * y;
      stage2[i] = y;
    }

    return stage2;
  }

  /// Computes integrated loudness in LUFS according to ITU-R BS.1770-4.
  /// Returns -70.0 LUFS if audio is completely silent or empty.
  double calculateIntegratedLufs(Float32List samples) {
    if (samples.isEmpty) return -70.0;

    final filtered = _applyKWeighting(samples);

    // 400ms rectangular window with 75% overlap (100ms hop)
    final blockSize = (0.400 * sampleRate).round();
    final hopSize = (0.100 * sampleRate).round();

    if (filtered.length < blockSize) {
      // For very short buffers, calculate un-gated loudness
      double sumSquares = 0.0;
      for (int i = 0; i < filtered.length; i++) {
        sumSquares += filtered[i] * filtered[i];
      }
      final meanSquare = sumSquares / filtered.length;
      if (meanSquare <= 1e-12) return -70.0;
      return -0.691 + 10.0 * (math.log(meanSquare) / math.ln10);
    }

    final blockPowers = <double>[];
    for (int start = 0; start + blockSize <= filtered.length; start += hopSize) {
      double sumSquares = 0.0;
      for (int i = 0; i < blockSize; i++) {
        final val = filtered[start + i];
        sumSquares += val * val;
      }
      final z = sumSquares / blockSize;
      blockPowers.add(z);
    }

    if (blockPowers.isEmpty) return -70.0;

    // Step 1: Absolute threshold gating at -70 LUFS
    final absoluteThreshold = math.pow(10.0, (-70.0 + 0.691) / 10.0).toDouble();
    final aboveAbsolute = blockPowers.where((z) => z > absoluteThreshold).toList();

    if (aboveAbsolute.isEmpty) return -70.0;

    // Mean power of blocks above absolute threshold
    final meanAboveAbs = aboveAbsolute.reduce((a, b) => a + b) / aboveAbsolute.length;

    // Step 2: Relative threshold gating at 10 LU below the absolute-gated loudness
    final relativeThreshold = meanAboveAbs * 0.1;
    final aboveRelative = aboveAbsolute.where((z) => z > relativeThreshold).toList();

    if (aboveRelative.isEmpty) return -70.0;

    final finalMean = aboveRelative.reduce((a, b) => a + b) / aboveRelative.length;
    if (finalMean <= 1e-12) return -70.0;

    final lufs = -0.691 + 10.0 * (math.log(finalMean) / math.ln10);
    return (lufs * 10).roundToDouble() / 10.0;
  }

  /// Calculates true peak in dBFS.
  double calculateTruePeakDbfs(Float32List samples) {
    if (samples.isEmpty) return -100.0;

    double maxSample = 0.0;
    for (int i = 0; i < samples.length; i++) {
      final abs = samples[i].abs();
      if (abs > maxSample) {
        maxSample = abs;
      }
    }

    if (maxSample <= 1e-6) return -100.0;
    final dbfs = 20.0 * (math.log(maxSample) / math.ln10);
    return (dbfs * 10).roundToDouble() / 10.0;
  }
}
