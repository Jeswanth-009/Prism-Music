import 'package:flutter/foundation.dart';
import 'package:prism_music/core/services/audio_effects_channel.dart';
import 'package:prism_music/core/models/reverb_preset.dart';

/// Service to manage audio equalizer and effects with real platform-specific audio processing
class EqualizerService {
  bool _isInitialized = false;
  
  // Current settings
  double _bassBoostLevel = 0.5;
  double _trebleLevel = 0.5;
  bool _bassBoostEnabled = false;
  ReverbPreset _reverbPreset = ReverbPreset.none;
  String _currentPresetName = 'Normal';

  // EQ presets with bass boost and reverb configurations
  static const Map<String, EqualizerPreset> presets = {
    'Normal': EqualizerPreset(
      name: 'Normal',
      bassBoost: 0.0,
      treble: 0.5,
      reverb: ReverbPreset.none,
    ),
    'Bass Boost': EqualizerPreset(
      name: 'Bass Boost',
      bassBoost: 0.8,
      treble: 0.4,
      reverb: ReverbPreset.none,
    ),
    'Treble Boost': EqualizerPreset(
      name: 'Treble Boost',
      bassBoost: 0.2,
      treble: 0.9,
      reverb: ReverbPreset.none,
    ),
    'Rock': EqualizerPreset(
      name: 'Rock',
      bassBoost: 0.65,
      treble: 0.7,
      reverb: ReverbPreset.largeRoom,
    ),
    'Pop': EqualizerPreset(
      name: 'Pop',
      bassBoost: 0.55,
      treble: 0.65,
      reverb: ReverbPreset.mediumRoom,
    ),
    'Classical': EqualizerPreset(
      name: 'Classical',
      bassBoost: 0.3,
      treble: 0.6,
      reverb: ReverbPreset.largeHall,
    ),
    'Jazz': EqualizerPreset(
      name: 'Jazz',
      bassBoost: 0.5,
      treble: 0.55,
      reverb: ReverbPreset.smallRoom,
    ),
    'Electronic': EqualizerPreset(
      name: 'Electronic',
      bassBoost: 0.75,
      treble: 0.8,
      reverb: ReverbPreset.plate,
    ),
  };
  
  EqualizerService();

  /// Initialize audio effects with player's audio session
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Get audio session ID from just_audio player
      // Note: just_audio doesn't expose audioSessionId directly
      // We'll use 0 which creates a new session in Android
      await AudioEffectsChannel.initialize(0);
      _isInitialized = true;
      debugPrint('EqualizerService: Initialized audio effects');
    } catch (e) {
      debugPrint('EqualizerService: Failed to initialize: $e');
    }
  }
  
  /// Get current preset name
  String get currentPreset => _currentPresetName;

  /// Get current bass boost level (0.0 - 1.0)
  double get bassBoostLevel => _bassBoostLevel;

  /// Get current treble level (0.0 - 1.0)
  double get trebleLevel => _trebleLevel;

  /// Get current reverb preset
  ReverbPreset get reverbPreset => _reverbPreset;

  /// Check if bass boost is enabled
  bool get isBassBoostEnabled => _bassBoostEnabled;
  
  /// Apply an equalizer preset
  Future<void> applyPreset(String presetName) async {
    final preset = presets[presetName];
    if (preset == null) return;

    await initialize();
    
    try {
      _currentPresetName = presetName;
      _bassBoostLevel = preset.bassBoost;
      _trebleLevel = preset.treble;
      _reverbPreset = preset.reverb;
      _bassBoostEnabled = preset.bassBoost > 0.0;

      // Apply bass boost
      await AudioEffectsChannel.setBassBoost(_bassBoostLevel, _bassBoostEnabled);
      
      // Apply reverb
      await AudioEffectsChannel.setReverb(_reverbPreset.value);
      
      debugPrint('EqualizerService: Applied preset: $presetName (Bass: $_bassBoostLevel, Reverb: ${_reverbPreset.displayName})');
    } catch (e) {
      debugPrint('EqualizerService: Failed to apply preset: $e');
    }
  }

  /// Set bass boost level manually (0.0 - 1.0)
  Future<void> setBassBoost(double level, bool enabled) async {
    await initialize();
    
    try {
      _bassBoostLevel = level.clamp(0.0, 1.0);
      _bassBoostEnabled = enabled;
      _currentPresetName = 'Custom';
      
      await AudioEffectsChannel.setBassBoost(_bassBoostLevel, _bassBoostEnabled);
      debugPrint('EqualizerService: Set bass boost: $level (enabled: $enabled)');
    } catch (e) {
      debugPrint('EqualizerService: Failed to set bass boost: $e');
    }
  }

  /// Set treble level manually (0.0 - 1.0)
  /// Note: Treble adjustment requires a different audio effect API
  /// This is a placeholder for future implementation
  Future<void> setTreble(double level) async {
    _trebleLevel = level.clamp(0.0, 1.0);
    _currentPresetName = 'Custom';
    debugPrint('EqualizerService: Set treble: $level (not yet implemented in platform)');
  }

  /// Set reverb preset manually
  Future<void> setReverb(ReverbPreset preset) async {
    await initialize();
    
    try {
      _reverbPreset = preset;
      _currentPresetName = 'Custom';
      
      await AudioEffectsChannel.setReverb(preset.value);
      debugPrint('EqualizerService: Set reverb: ${preset.displayName}');
    } catch (e) {
      debugPrint('EqualizerService: Failed to set reverb: $e');
    }
  }
  
  /// Reset to normal
  Future<void> reset() async {
    await applyPreset('Normal');
  }

  /// Release audio effects resources
  Future<void> dispose() async {
    try {
      await AudioEffectsChannel.release();
      _isInitialized = false;
      debugPrint('EqualizerService: Disposed audio effects');
    } catch (e) {
      debugPrint('EqualizerService: Failed to dispose: $e');
    }
  }
}

/// Equalizer preset configuration
class EqualizerPreset {
  final String name;
  final double bassBoost; // 0.0 - 1.0
  final double treble; // 0.0 - 1.0
  final ReverbPreset reverb;
  
  const EqualizerPreset({
    required this.name,
    required this.bassBoost,
    required this.treble,
    required this.reverb,
  });
}

