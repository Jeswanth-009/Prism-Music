import 'dart:math' as math;
import 'dart:typed_data';

/// A single second-order IIR peaking filter band.
class BiquadBand {
  final double centerFrequency;
  final double sampleRate;
  final double q;

  double _gainDb = 0.0;
  double _b0 = 1.0;
  double _b1 = 0.0;
  double _b2 = 0.0;
  double _a1 = 0.0;
  double _a2 = 0.0;

  // Filter state per channel (Direct Form II Transposed)
  double _s1 = 0.0;
  double _s2 = 0.0;
  double _s1R = 0.0;
  double _s2R = 0.0;

  BiquadBand({
    required this.centerFrequency,
    this.sampleRate = 44100,
    this.q = 1.414,
  }) {
    _updateCoefficients();
  }

  double get gainDb => _gainDb;

  set gainDb(double value) {
    final clamped = value.clamp(-12.0, 12.0);
    if ((clamped - _gainDb).abs() > 0.01) {
      _gainDb = clamped;
      _updateCoefficients();
    }
  }

  void _updateCoefficients() {
    if ((_gainDb).abs() < 0.05) {
      // Flat bypass
      _b0 = 1.0;
      _b1 = 0.0;
      _b2 = 0.0;
      _a1 = 0.0;
      _a2 = 0.0;
      return;
    }

    final nyquist = sampleRate / 2.0;
    final f0 = centerFrequency.clamp(10.0, nyquist - 100.0);
    final w0 = 2.0 * math.pi * f0 / sampleRate;
    final alpha = math.sin(w0) / (2.0 * q);
    final a = math.pow(10.0, _gainDb / 40.0).toDouble();

    final b0 = 1.0 + alpha * a;
    final b1 = -2.0 * math.cos(w0);
    final b2 = 1.0 - alpha * a;
    final a0 = 1.0 + alpha / a;
    final a1 = -2.0 * math.cos(w0);
    final a2 = 1.0 - alpha / a;

    _b0 = b0 / a0;
    _b1 = b1 / a0;
    _b2 = b2 / a0;
    _a1 = a1 / a0;
    _a2 = a2 / a0;
  }

  /// Processes a single left/mono audio sample through the filter.
  @pragma('vm:prefer-inline')
  double processSample(double x) {
    final y = _b0 * x + _s1;
    _s1 = _b1 * x - _a1 * y + _s2;
    _s2 = _b2 * x - _a2 * y;
    return y;
  }

  /// Processes a single right-channel audio sample with isolated stereo state.
  @pragma('vm:prefer-inline')
  double processSampleRight(double x) {
    final y = _b0 * x + _s1R;
    _s1R = _b1 * x - _a1 * y + _s2R;
    _s2R = _b2 * x - _a2 * y;
    return y;
  }

  /// Resets filter history/state.
  void reset() {
    _s1 = 0.0;
    _s2 = 0.0;
    _s1R = 0.0;
    _s2R = 0.0;
  }
}

/// Pure-Dart 10-band second-order IIR peaking filter cascade.
/// Center frequencies: 31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000 Hz.
class BiquadEqualizer {
  static const List<double> standardCenterFrequencies = [
    31.25,
    62.5,
    125.0,
    250.0,
    500.0,
    1000.0,
    2000.0,
    4000.0,
    8000.0,
    16000.0,
  ];

  final int sampleRate;
  late final List<BiquadBand> bands;

  BiquadEqualizer({
    this.sampleRate = 44100,
    List<double>? frequencies,
  }) {
    final freqs = frequencies ?? standardCenterFrequencies;
    bands = freqs
        .map((f) => BiquadBand(centerFrequency: f, sampleRate: sampleRate.toDouble()))
        .toList();
  }

  int get bandCount => bands.length;

  /// Sets the gain in dB for a specific band index.
  void setBandGain(int bandIndex, double gainDb) {
    if (bandIndex >= 0 && bandIndex < bands.length) {
      bands[bandIndex].gainDb = gainDb;
    }
  }

  /// Sets gains for all bands simultaneously.
  void setGains(List<double> gainsDb) {
    for (int i = 0; i < bands.length && i < gainsDb.length; i++) {
      bands[i].gainDb = gainsDb[i];
    }
  }

  /// Retrieves current band gains.
  List<double> getGains() => bands.map((b) => b.gainDb).toList();

  /// Processes mono audio samples through the 10-band cascade.
  Float32List process(Float32List samples) {
    final output = Float32List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      double s = samples[i];
      for (int b = 0; b < bands.length; b++) {
        s = bands[b].processSample(s);
      }
      // Soft saturation clamp to prevent harsh digital distortion
      output[i] = s.clamp(-1.0, 1.0);
    }
    return output;
  }

  /// Processes interleaved stereo `[L, R, L, R, ...]` samples with isolated channel states.
  Float32List processStereo(Float32List interleaved) {
    final output = Float32List(interleaved.length);
    for (int i = 0; i + 1 < interleaved.length; i += 2) {
      double l = interleaved[i];
      double r = interleaved[i + 1];
      for (int b = 0; b < bands.length; b++) {
        l = bands[b].processSample(l);
        r = bands[b].processSampleRight(r);
      }
      output[i] = l.clamp(-1.0, 1.0);
      output[i + 1] = r.clamp(-1.0, 1.0);
    }
    return output;
  }

  /// Resets all filter delay states.
  void reset() {
    for (final band in bands) {
      band.reset();
    }
  }
}
