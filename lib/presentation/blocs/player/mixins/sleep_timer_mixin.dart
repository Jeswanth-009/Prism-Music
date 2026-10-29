import 'dart:async';
import 'package:flutter/foundation.dart';

/// Mixin providing isolated sleep timer scheduling and cancellation mechanics.
mixin SleepTimerMixin {
  Timer? _sleepTimer;

  /// Whether a timer is currently active and counting down.
  bool get isSleepTimerActive => _sleepTimer != null;

  /// Start a one-shot sleep timer that triggers [onElapsed] when duration expires.
  void startSleepTimer(
    Duration duration, {
    required VoidCallback onElapsed,
  }) {
    cancelSleepTimer();
    _sleepTimer = Timer(duration, onElapsed);
  }

  /// Cancel any pending sleep timer without executing callback.
  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
  }
}
