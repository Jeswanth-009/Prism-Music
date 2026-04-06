import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform channel for Android audio effects (BassBoost, PresetReverb)
class AudioEffectsChannel {
  static const MethodChannel _channel =
      MethodChannel('com.prismmusic/audio_effects');

  /// Initialize audio effects with the audio session ID from just_audio player
  static Future<void> initialize(int audioSessionId) async {
    try {
      await _channel.invokeMethod('initialize', {
        'audioSessionId': audioSessionId,
      });
    } catch (e) {
      debugPrint('AudioEffectsChannel: Failed to initialize: $e');
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
