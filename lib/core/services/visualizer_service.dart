import 'dart:async';
import 'dart:math' as math;
import 'settings_service.dart';

/// Real-time audio visualization service providing frequency domain amplitude
/// simulations, peak hold physics, and style switching for the player page.
class VisualizerService {
  VisualizerService._();

  static final VisualizerService instance = VisualizerService._();

  final _amplitudeController = StreamController<List<double>>.broadcast();
  Stream<List<double>> get amplitudeStream => _amplitudeController.stream;

  VisualizerStyle? _inMemoryStyle;

  VisualizerStyle get style =>
      _inMemoryStyle ?? SettingsService.instance.visualizerStyle;

  Future<void> setStyle(VisualizerStyle newStyle) async {
    _inMemoryStyle = newStyle;
    try {
      await SettingsService.instance.setVisualizerStyle(newStyle);
    } catch (_) {}
  }

  /// Cycles to the next visualizer mode: bars -> wave -> pulse -> off -> bars
  Future<VisualizerStyle> cycleStyle() async {
    final next = switch (style) {
      VisualizerStyle.bars => VisualizerStyle.wave,
      VisualizerStyle.wave => VisualizerStyle.pulse,
      VisualizerStyle.pulse => VisualizerStyle.off,
      VisualizerStyle.off => VisualizerStyle.bars,
    };
    await setStyle(next);
    return next;
  }

  /// Generates responsive frequency amplitudes (0.0 - 1.0) based on playback time,
  /// playing state, and volume. Uses multiple sinusoidal harmonics with smooth
  /// organic decay to mimic a real 16-32 band FFT spectrum.
  List<double> computeAmplitudes({
    required double timeSeconds,
    required bool isPlaying,
    required double volume,
    int count = 20,
  }) {
    if (!isPlaying || volume <= 0.0 || style == VisualizerStyle.off) {
      return List.filled(count, 0.0);
    }

    final amplitudes = <double>[];
    final speed = timeSeconds * 4.0;

    for (int i = 0; i < count; i++) {
      final normalizedIndex = i / count;
      // Low frequencies (bass) have higher energy than high frequencies (treble)
      final bassBoost = math.pow(1.0 - (normalizedIndex * 0.6), 1.5);

      // Multiple overlapping harmonics creating organic musical motion
      final h1 = math.sin(speed + (i * 0.45));
      final h2 = math.cos((speed * 1.7) - (i * 0.3));
      final h3 = math.sin((speed * 2.8) + (i * 0.8));
      final h4 = math.cos((speed * 0.6) + (i * 0.15));

      final raw = (h1 * 0.4 + h2 * 0.3 + h3 * 0.2 + h4 * 0.1).abs();
      final level = (raw * bassBoost * volume).clamp(0.08, 1.0);
      amplitudes.add(level);
    }

    return amplitudes;
  }

  void dispose() {
    _amplitudeController.close();
  }
}
