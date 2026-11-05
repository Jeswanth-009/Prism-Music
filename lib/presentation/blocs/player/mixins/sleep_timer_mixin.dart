import 'dart:async';
import 'package:flutter/foundation.dart';

/// Mixin providing isolated sleep timer scheduling and cancellation mechanics,
/// including optional bedtime mode with gradual volume fade-out.
mixin SleepTimerMixin {
  Timer? _sleepTimer;
  Timer? _fadeTimer;
  Timer? _fadeDelayTimer;

  /// Whether a timer is currently active and counting down.
  bool get isSleepTimerActive => _sleepTimer != null;

  /// Start a sleep timer with optional gradual volume fade (bedtime mode).
  void startSleepTimer(
    Duration duration, {
    required VoidCallback onElapsed,
    bool bedtimeMode = false,
    Duration fadeDuration = const Duration(seconds: 60),
    void Function(double factor)? onVolumeFade,
    VoidCallback? onRestoreVolume,
  }) {
    cancelSleepTimer(onRestoreVolume: onRestoreVolume);

    if (bedtimeMode && onVolumeFade != null) {
      final effectiveFade = duration > const Duration(minutes: 2)
          ? fadeDuration
          : Duration(milliseconds: (duration.inMilliseconds * 0.4).round());

      final fadeDelay = duration - effectiveFade;
      if (fadeDelay > Duration.zero) {
        _fadeDelayTimer = Timer(fadeDelay, () {
          if (!isSleepTimerActive) return;
          _startFadeOut(effectiveFade, onVolumeFade);
        });
      } else {
        _startFadeOut(duration, onVolumeFade);
      }
    }

    _sleepTimer = Timer(duration, () {
      cancelSleepTimer(onRestoreVolume: onRestoreVolume);
      onElapsed();
    });
  }

  void _startFadeOut(Duration fadeDuration, void Function(double factor) onVolumeFade) {
    _fadeTimer?.cancel();
    const totalSteps = 20;
    final stepInterval = (fadeDuration.inMilliseconds / totalSteps).round().clamp(50, 5000);
    int currentStep = 0;

    _fadeTimer = Timer.periodic(Duration(milliseconds: stepInterval), (timer) {
      currentStep++;
      final factor = (1.0 - (currentStep / totalSteps)).clamp(0.0, 1.0);
      onVolumeFade(factor);
      if (currentStep >= totalSteps) {
        timer.cancel();
        _fadeTimer = null;
      }
    });
  }

  /// Cancel any pending sleep timer without executing callback.
  void cancelSleepTimer({VoidCallback? onRestoreVolume}) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _fadeDelayTimer?.cancel();
    _fadeDelayTimer = null;
    _fadeTimer?.cancel();
    _fadeTimer = null;
    onRestoreVolume?.call();
  }
}
