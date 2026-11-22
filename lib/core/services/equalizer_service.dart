import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:prism_music/core/models/reverb_preset.dart';
import 'package:prism_music/core/services/audio_effects_channel.dart';
import 'package:prism_music/core/services/desktop_audio_support.dart';
import 'package:prism_music/core/services/settings_service.dart';

import '../dsp/biquad_equalizer.dart';

/// Service to manage audio equalizer and effects with real 10-band biquad DSP
/// and platform-specific audio processing.
class EqualizerService {
  bool _isInitialized = false;

  // Current settings
  double _bassBoostLevel = 0.5;
  double _trebleLevel = 0.5;
  bool _bassBoostEnabled = false;
  ReverbPreset _reverbPreset = ReverbPreset.none;
  String _currentPresetName = 'Normal';
  final Map<String, EqualizerPreset> _customPresets = {};

  // 10-band pure-Dart Biquad Equalizer instance
  final BiquadEqualizer _biquadFilter = BiquadEqualizer();
  final List<double> _bandGains = List.filled(10, 0.0);

  List<double> get bandGains => List.unmodifiable(_bandGains);
  BiquadEqualizer get biquadFilter => _biquadFilter;

  static const List<double> bandFrequencies = [
    31.0, 62.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0
  ];

  static const List<String> bandLabels = [
    '31Hz', '62Hz', '125Hz', '250Hz', '500Hz', '1kHz', '2kHz', '4kHz', '8kHz', '16kHz'
  ];

  // EQ presets with 10-band gains, bass boost and reverb configurations
  static const Map<String, EqualizerPreset> presets = {
    'Normal': EqualizerPreset(
      name: 'Normal',
      bassBoost: 0.0,
      treble: 0.5,
      reverb: ReverbPreset.none,
      bandGains: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    ),
    'Bass Boost': EqualizerPreset(
      name: 'Bass Boost',
      bassBoost: 0.8,
      treble: 0.4,
      reverb: ReverbPreset.none,
      bandGains: [6.0, 5.0, 3.5, 1.5, 0.0, 0.0, 0.0, 0.0, -0.5, -1.0],
    ),
    'Treble Boost': EqualizerPreset(
      name: 'Treble Boost',
      bassBoost: 0.2,
      treble: 0.9,
      reverb: ReverbPreset.none,
      bandGains: [-1.0, -0.5, 0.0, 0.0, 0.5, 1.5, 3.0, 5.0, 6.0, 6.5],
    ),
    'Rock': EqualizerPreset(
      name: 'Rock',
      bassBoost: 0.65,
      treble: 0.7,
      reverb: ReverbPreset.largeRoom,
      bandGains: [5.0, 3.5, 2.0, -1.0, -0.5, 1.0, 2.5, 4.0, 5.0, 5.5],
    ),
    'Pop': EqualizerPreset(
      name: 'Pop',
      bassBoost: 0.55,
      treble: 0.65,
      reverb: ReverbPreset.mediumRoom,
      bandGains: [2.0, 3.5, 4.0, 2.0, 0.0, 1.5, 3.0, 3.5, 3.0, 2.5],
    ),
    'Classical': EqualizerPreset(
      name: 'Classical',
      bassBoost: 0.3,
      treble: 0.6,
      reverb: ReverbPreset.largeHall,
      bandGains: [4.0, 3.0, 2.0, 0.5, -0.5, -0.5, 1.0, 2.5, 4.0, 4.5],
    ),
    'Jazz': EqualizerPreset(
      name: 'Jazz',
      bassBoost: 0.5,
      treble: 0.55,
      reverb: ReverbPreset.smallRoom,
      bandGains: [3.0, 2.0, 1.0, 1.5, -0.5, -0.5, 1.0, 2.0, 3.0, 3.5],
    ),
    'Electronic': EqualizerPreset(
      name: 'Electronic',
      bassBoost: 0.75,
      treble: 0.8,
      reverb: ReverbPreset.plate,
      bandGains: [6.5, 5.0, 3.0, 0.5, -1.0, 1.0, 2.5, 4.5, 5.5, 6.0],
    ),
  };

  int _audioSessionId = 0;
  bool _isSupported = false;

  int get audioSessionId => _audioSessionId;

  EqualizerService() {
    _loadPersistedSettings();
  }

  void _loadPersistedSettings() {
    try {
      final s = SettingsService.instance;
      _currentPresetName = s.equalizerPreset;
      _bassBoostLevel = s.equalizerBassBoostLevel;
      _trebleLevel = s.equalizerTrebleLevel;
      _bassBoostEnabled = s.bassBoostEnabled;
      final reverbName = s.equalizerReverb;
      _reverbPreset = ReverbPreset.values.firstWhere(
        (r) => r.name == reverbName,
        orElse: () => ReverbPreset.none,
      );
      final customSaved = s.customEqualizerPresets;
      _customPresets.clear();
      for (final entry in customSaved.entries) {
        _customPresets[entry.key] = EqualizerPreset.fromMap(entry.value);
      }

      // Reapply preset band gains if found
      final preset = allPresets[_currentPresetName];
      if (preset?.bandGains != null && preset!.bandGains!.isNotEmpty) {
        for (int i = 0; i < math.min(preset.bandGains!.length, _bandGains.length); i++) {
          _bandGains[i] = preset.bandGains![i];
          _biquadFilter.setBandGain(i, _bandGains[i]);
        }
      }
    } catch (_) {}
  }

  void _persistSettings() {
    try {
      final s = SettingsService.instance;
      s.setEqualizerPreset(_currentPresetName);
      s.setEqualizerBassBoostLevel(_bassBoostLevel);
      s.setEqualizerTrebleLevel(_trebleLevel);
      s.setBassBoost(_bassBoostEnabled);
      s.setEqualizerReverb(_reverbPreset.name);
      final customMap = <String, Map<String, dynamic>>{};
      for (final entry in _customPresets.entries) {
        customMap[entry.key] = entry.value.toMap();
      }
      s.setCustomEqualizerPresets(customMap);
    } catch (_) {}
  }

  /// Whether audio effects are supported on this device/platform
  bool get isSupported => _isSupported;

  /// Check if equalizer is initialized
  bool get isInitialized => _isInitialized;

  /// Bind to a new audio session ID (called when playback starts or changes session)
  Future<bool> bindAudioSession(int sessionId) async {
    _audioSessionId = sessionId;

    if (!DesktopAudioSupport.instance.supportsNativeEffects) {
      _isSupported = false;
      _isInitialized = true;
      return true;
    }

    try {
      final success = await AudioEffectsChannel.initialize(sessionId);
      _isSupported = success;
      _isInitialized = true;

      if (success) {
        await _reapplyEffects();
      }

      return success;
    } catch (e) {
      _isSupported = false;
      _isInitialized = false;
      return false;
    }
  }

  /// Initialize audio effects with current or provided session
  Future<bool> initialize([int? sessionId]) async {
    final targetSessionId = sessionId ?? _audioSessionId;
    if (targetSessionId > 0) {
      return bindAudioSession(targetSessionId);
    }
    return false;
  }

  Future<void> _reapplyEffects() async {
    if (!_isSupported) return;
    try {
      await AudioEffectsChannel.setBassBoost(_bassBoostLevel, _bassBoostEnabled);
      await AudioEffectsChannel.setTreble(_trebleLevel);
      await AudioEffectsChannel.setReverb(_reverbPreset.value);
      await AudioEffectsChannel.setBandGains(_bandGains);
    } catch (e) {
      debugPrint('EqualizerService: Failed to reapply effects: $e');
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

  /// Combined presets (built-in + user custom)
  Map<String, EqualizerPreset> get allPresets => {
    ...presets,
    ..._customPresets,
  };

  /// User-created presets only
  Map<String, EqualizerPreset> get customPresets => Map.unmodifiable(_customPresets);

  /// Apply an equalizer preset
  Future<void> applyPreset(String presetName) async {
    final preset = allPresets[presetName];
    if (preset == null) return;

    _currentPresetName = presetName;
    _bassBoostLevel = preset.bassBoost;
    _trebleLevel = preset.treble;
    _reverbPreset = preset.reverb;
    _bassBoostEnabled = preset.bassBoost > 0.0;

    if (preset.bandGains != null && preset.bandGains!.isNotEmpty) {
      for (int i = 0; i < math.min(preset.bandGains!.length, _bandGains.length); i++) {
        _bandGains[i] = preset.bandGains![i];
        _biquadFilter.setBandGain(i, _bandGains[i]);
      }
    }

    _persistSettings();

    if (_isSupported) {
      await _reapplyEffects();
    }
  }

  /// Set gain in dB (-12.0 to +12.0) for a specific frequency band index (0..9)
  Future<void> setBandGain(int bandIndex, double gainDb) async {
    if (bandIndex < 0 || bandIndex >= _bandGains.length) return;
    _bandGains[bandIndex] = gainDb.clamp(-12.0, 12.0);
    _biquadFilter.setBandGain(bandIndex, _bandGains[bandIndex]);
    _currentPresetName = 'Custom';
    _persistSettings();

    if (_isSupported) {
      await AudioEffectsChannel.setBandGains(_bandGains);
    }
  }

  /// Set all 10 band gains at once
  Future<void> setAllBandGains(List<double> gainsDb) async {
    for (int i = 0; i < math.min(gainsDb.length, _bandGains.length); i++) {
      _bandGains[i] = gainsDb[i].clamp(-12.0, 12.0);
      _biquadFilter.setBandGain(i, _bandGains[i]);
    }
    _currentPresetName = 'Custom';
    _persistSettings();

    if (_isSupported) {
      await AudioEffectsChannel.setBandGains(_bandGains);
    }
  }

  /// Set bass boost level manually (0.0 - 1.0)
  Future<void> setBassBoost(double level, bool enabled) async {
    _bassBoostLevel = level.clamp(0.0, 1.0);
    _bassBoostEnabled = enabled;
    _currentPresetName = 'Custom';
    _persistSettings();

    if (_isSupported) {
      try {
        await AudioEffectsChannel.setBassBoost(_bassBoostLevel, _bassBoostEnabled);
      } catch (e) {
        debugPrint('EqualizerService: Failed to set bass boost: $e');
      }
    }
  }

  /// Set treble level manually (0.0 - 1.0); 0.5 is neutral
  Future<void> setTreble(double level) async {
    _trebleLevel = level.clamp(0.0, 1.0);
    _currentPresetName = 'Custom';
    _persistSettings();

    if (_isSupported) {
      try {
        await AudioEffectsChannel.setTreble(_trebleLevel);
      } catch (e) {
        debugPrint('EqualizerService: Failed to set treble: $e');
      }
    }
  }

  /// Set reverb preset manually
  Future<void> setReverb(ReverbPreset preset) async {
    _reverbPreset = preset;
    _currentPresetName = 'Custom';
    _persistSettings();

    if (_isSupported) {
      try {
        await AudioEffectsChannel.setReverb(_reverbPreset.value);
      } catch (e) {
        debugPrint('EqualizerService: Failed to set reverb: $e');
      }
    }
  }

  /// Save current configuration as a custom preset
  Future<void> saveCustomPreset(String name) async {
    final preset = EqualizerPreset(
      name: name,
      bassBoost: _bassBoostLevel,
      treble: _trebleLevel,
      reverb: _reverbPreset,
      isCustom: true,
      bandGains: List.of(_bandGains),
    );
    _customPresets[name] = preset;
    _currentPresetName = name;
    _persistSettings();
  }

  /// Delete a custom preset
  Future<void> deleteCustomPreset(String name) async {
    if (!_customPresets.containsKey(name)) return;
    _customPresets.remove(name);
    if (_currentPresetName == name) {
      await applyPreset('Normal');
    } else {
      _persistSettings();
    }
  }

  /// Save current settings for a specific song
  Future<void> saveCurrentForSong(String songId) async {
    final s = SettingsService.instance;
    await s.setSongEqualizer(songId, {
      'preset': _currentPresetName,
      'bassBoost': _bassBoostLevel,
      'treble': _trebleLevel,
      'bassBoostEnabled': _bassBoostEnabled,
      'reverb': _reverbPreset.name,
      'bandGains': _bandGains,
    });
  }

  /// Load and apply song-specific settings if they exist
  Future<bool> loadForSong(String songId) async {
    final s = SettingsService.instance;
    final map = s.getSongEqualizer(songId);
    if (map == null) return false;

    try {
      _bassBoostLevel = (map['bassBoost'] as num?)?.toDouble() ?? 0.5;
      _trebleLevel = (map['treble'] as num?)?.toDouble() ?? 0.5;
      _bassBoostEnabled = map['bassBoostEnabled'] as bool? ?? false;
      final reverbName = map['reverb'] as String?;
      _reverbPreset = ReverbPreset.values.firstWhere(
        (r) => r.name == reverbName,
        orElse: () => ReverbPreset.none,
      );
      _currentPresetName = map['preset'] as String? ?? 'Custom';

      final gains = map['bandGains'] as List?;
      if (gains != null && gains.isNotEmpty) {
        for (int i = 0; i < math.min(gains.length, _bandGains.length); i++) {
          _bandGains[i] = (gains[i] as num).toDouble();
          _biquadFilter.setBandGain(i, _bandGains[i]);
        }
      }

      _persistSettings();

      if (_isSupported) {
        await _reapplyEffects();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Alias for loadForSong
  Future<bool> applyPresetForSong(String songId) => loadForSong(songId);

  /// Remove song-specific equalizer configuration
  Future<void> removeForSong(String songId) async {
    await SettingsService.instance.setSongEqualizer(songId, null);
  }

  /// Alias for removeForSong
  Future<void> clearForSong(String songId) => removeForSong(songId);

  /// Check if a song has custom equalizer configuration
  bool hasSongEqualizer(String songId) {
    return SettingsService.instance.getSongEqualizer(songId) != null;
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
      _isSupported = false;
      _audioSessionId = 0;
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
  final bool isCustom;
  final List<double>? bandGains;

  const EqualizerPreset({
    required this.name,
    required this.bassBoost,
    required this.treble,
    required this.reverb,
    this.isCustom = false,
    this.bandGains,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'bassBoost': bassBoost,
    'treble': treble,
    'reverb': reverb.name,
    'isCustom': isCustom,
    if (bandGains != null) 'bandGains': bandGains,
  };

  factory EqualizerPreset.fromMap(Map<dynamic, dynamic> map) {
    final reverbName = map['reverb'] as String?;
    final gainsList = map['bandGains'] as List?;
    final bandGains = gainsList?.map((g) => (g as num).toDouble()).toList();

    return EqualizerPreset(
      name: map['name'] as String? ?? 'Custom',
      bassBoost: (map['bassBoost'] as num?)?.toDouble() ?? 0.5,
      treble: (map['treble'] as num?)?.toDouble() ?? 0.5,
      reverb: ReverbPreset.values.firstWhere(
        (r) => r.name == reverbName,
        orElse: () => ReverbPreset.none,
      ),
      isCustom: map['isCustom'] as bool? ?? true,
      bandGains: bandGains,
    );
  }
}
