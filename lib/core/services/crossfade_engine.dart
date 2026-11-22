import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Manages dual-player equal-power audio crossfading between outgoing and incoming tracks.
///
/// Uses trigonometric constant-power panning curves:
/// Outgoing: cos(pi/2 * t/T)
/// Incoming: sin(pi/2 * t/T)
///
/// Prevents the 3dB dip in perceived acoustic energy that occurs with linear crossfading.
class CrossfadeEngine {
  final Duration defaultDuration;
  bool _isCrossfading = false;
  Timer? _fadeTimer;

  CrossfadeEngine({
    this.defaultDuration = const Duration(seconds: 5),
  });

  bool get isCrossfading => _isCrossfading;

  /// Calculates equal-power gains for [elapsed] time within [totalDuration].
  /// Returns (outgoingGain, incomingGain) where outgoing^2 + incoming^2 ~= 1.0.
  static (double outgoingGain, double incomingGain) computeEqualPowerGains(
    Duration elapsed,
    Duration totalDuration,
  ) {
    if (totalDuration.inMilliseconds <= 0) {
      return (0.0, 1.0);
    }

    final progress = (elapsed.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0);
    final theta = (math.pi / 2.0) * progress;

    final outgoing = math.cos(theta);
    final incoming = math.sin(theta);

    return (outgoing, incoming);
  }

  /// Executes equal-power crossfade between [outgoingPlayer] and [incomingPlayer].
  Future<void> crossfade({
    required AudioPlayer outgoingPlayer,
    required AudioPlayer incomingPlayer,
    Duration? duration,
    VoidCallback? onComplete,
  }) async {
    final fadeDuration = duration ?? defaultDuration;
    if (fadeDuration.inMilliseconds <= 0) {
      await outgoingPlayer.stop();
      await incomingPlayer.setVolume(1.0);
      onComplete?.call();
      return;
    }

    _fadeTimer?.cancel();
    _isCrossfading = true;

    // Start incoming player at 0.0 volume
    await incomingPlayer.setVolume(0.0);
    if (!incomingPlayer.playing) {
      unawaited(incomingPlayer.play());
    }

    final completer = Completer<void>();
    final stopwatch = Stopwatch()..start();
    const tickInterval = Duration(milliseconds: 50);

    _fadeTimer = Timer.periodic(tickInterval, (timer) async {
      final elapsed = stopwatch.elapsed;
      final (outGain, inGain) = computeEqualPowerGains(elapsed, fadeDuration);

      try {
        await outgoingPlayer.setVolume(outGain);
        await incomingPlayer.setVolume(inGain);
      } catch (e) {
        debugPrint('CrossfadeEngine: Error adjusting volumes: $e');
      }

      if (elapsed >= fadeDuration) {
        timer.cancel();
        _isCrossfading = false;
        try {
          await outgoingPlayer.stop();
          await outgoingPlayer.setVolume(1.0); // Reset for next use
          await incomingPlayer.setVolume(1.0);
        } catch (_) {}
        onComplete?.call();
        completer.complete();
      }
    });

    return completer.future;
  }

  /// Cancels any active crossfade operation immediately.
  void cancel() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _isCrossfading = false;
  }
}
