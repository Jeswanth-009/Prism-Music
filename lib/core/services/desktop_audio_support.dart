import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Platform-specific audio handling and desktop platform detection service.
/// Ensures seamless playback and stability across Linux, macOS, and Windows.
class DesktopAudioSupport {
  DesktopAudioSupport._();

  static final DesktopAudioSupport instance = DesktopAudioSupport._();

  /// Whether current environment is a desktop OS (Windows, Linux, or macOS)
  bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  /// Whether running on Linux
  bool get isLinux => !kIsWeb && Platform.isLinux;

  /// Whether running on macOS
  bool get isMacOS => !kIsWeb && Platform.isMacOS;

  /// Whether running on Windows
  bool get isWindows => !kIsWeb && Platform.isWindows;

  /// Human-readable platform name
  String get platformName {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  /// Returns platform-tuned audio load configuration.
  /// On Android, configures optimized low-latency AndroidLoadControl buffers.
  /// On desktop and iOS, returns null to allow the platform native engine
  /// (Media Foundation on Windows, AVPlayer on macOS, GStreamer/Pulse on Linux)
  /// to manage its native pipeline without invalid Android parameters.
  AudioLoadConfiguration? getPlatformAudioLoadConfiguration() {
    if (!kIsWeb && Platform.isAndroid) {
      return AudioLoadConfiguration(
        androidLoadControl: AndroidLoadControl(
          minBufferDuration: const Duration(seconds: 30),
          maxBufferDuration: const Duration(seconds: 120),
          bufferForPlaybackDuration: const Duration(seconds: 2),
          bufferForPlaybackAfterRebufferDuration: const Duration(seconds: 3),
        ),
      );
    }
    return null;
  }

  /// Calculates adjusted volume with desktop volume step increments (+5% / -5%)
  double stepVolume(double currentVolume, bool increase, {double step = 0.05}) {
    final next = increase ? currentVolume + step : currentVolume - step;
    return next.clamp(0.0, 1.0);
  }
}
