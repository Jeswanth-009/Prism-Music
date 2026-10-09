import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform channel for Android audio effects (BassBoost, PresetReverb)
class AudioEffectsChannel {
  static const MethodChannel _channel =
      MethodChannel('com.prismmusic/audio_effects');

  /// Initialize audio effects with the audio session ID from just_audio player.
  /// Returns true if native effects were successfully initialized.
  static Future<bool> initialize(int audioSessionId) async {
    if (kIsWeb || !Platform.isAndroid || audioSessionId <= 0) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('initialize', {
        'audioSessionId': audioSessionId,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('AudioEffectsChannel: Failed to initialize: $e');
      return false;
    }
  }

  /// Set bass boost level (0.0 - 1.0)
  /// Internally converts to 0-1000 range for Android BassBoost API
  static Future<void> setBassBoost(double level, bool enabled) async {
    try {
      await _channel.invokeMethod('setBassBoost', {
        'level': level.clamp(0.0, 1.0),
        'enabled': enabled,
      });
    } catch (e) {
      debugPrint('AudioEffectsChannel: Failed to set bass boost: $e');
    }
  }

  /// Set treble level (0.0 - 1.0); 0.5 is neutral, above boosts the
  /// highest equalizer band, below cuts it.
  static Future<void> setTreble(double level) async {
    try {
      await _channel.invokeMethod('setTreble', {
        'level': level.clamp(0.0, 1.0),
      });
    } catch (e) {
      debugPrint('AudioEffectsChannel: Failed to set treble: $e');
    }
  }

  /// Set reverb preset
  static Future<void> setReverb(String preset) async {
    try {
      await _channel.invokeMethod('setReverb', {
        'preset': preset,
      });
    } catch (e) {
      debugPrint('AudioEffectsChannel: Failed to set reverb: $e');
    }
  }

  /// Release all audio effects
  static Future<void> release() async {
    try {
      await _channel.invokeMethod('release');
    } catch (e) {
      debugPrint('AudioEffectsChannel: Failed to release: $e');
    }
  }
}
