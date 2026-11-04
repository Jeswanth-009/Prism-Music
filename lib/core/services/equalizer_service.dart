import 'package:flutter/foundation.dart';
import 'package:prism_music/core/services/audio_effects_channel.dart';
import 'package:prism_music/core/models/reverb_preset.dart';
import 'package:prism_music/core/services/settings_service.dart';

/// Service to manage audio equalizer and effects with real platform-specific audio processing
class EqualizerService {
  bool _isInitialized = false;
  
  // Current settings
  double _bassBoostLevel = 0.5;
  double _trebleLevel = 0.5;
  bool _bassBoostEnabled = false;
  ReverbPreset _reverbPreset = ReverbPreset.none;
  String _currentPresetName = 'Normal';
  final Map<String, EqualizerPreset> _customPresets = {};

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
  
  int _audioSessionId = 0;
  bool _isSupported = false;

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
    } catch (_) {}
  }

  /// Whether native audio effects are supported and bound to a valid session
  bool get isSupported => _isSupported;

  /// Whether audio effects have been initialized
  bool get isInitialized => _isInitialized;

  /// The active audio session ID bound to this service
  int get audioSessionId => _audioSessionId;

  /// Bind audio effects to a specific player audio session ID.
  /// Reapplies active preset/custom effects when bound successfully.
  Future<bool> bindAudioSession(int sessionId) async {
    if (sessionId <= 0) {
      _audioSessionId = 0;
      _isSupported = false;
      _isInitialized = false;
      return false;
    }

    _audioSessionId = sessionId;
    try {
      final success = await AudioEffectsChannel.initialize(sessionId);
      _isSupported = success;
      _isInitialized = success;
      if (success) {
        debugPrint('EqualizerService: Bound audio effects to session $sessionId');
        await _reapplyEffects();
      } else {
        debugPrint('EqualizerService: Native effects unavailable for session $sessionId');
      }
      return success;
    } catch (e) {
      debugPrint('EqualizerService: Failed to bind session $sessionId: $e');
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
    _persistSettings();

    if (_isSupported) {
      await _reapplyEffects();
      debugPrint('EqualizerService: Applied preset: $presetName (Bass: $_bassBoostLevel, Treble: $_trebleLevel, Reverb: ${_reverbPreset.displayName})');
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
        debugPrint('EqualizerService: Set bass boost: $level (enabled: $enabled)');
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
        debugPrint('EqualizerService: Set treble: $_trebleLevel');
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
        await AudioEffectsChannel.setReverb(preset.value);
        debugPrint('EqualizerService: Set reverb: ${preset.displayName}');
      } catch (e) {
        debugPrint('EqualizerService: Failed to set reverb: $e');
      }
    }
  }
  
  /// Save current EQ configuration as a named custom preset
  Future<void> saveCustomPreset(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final preset = EqualizerPreset(
      name: trimmed,
      bassBoost: _bassBoostLevel,
      treble: _trebleLevel,
      reverb: _reverbPreset,
      isCustom: true,
    );
    _customPresets[trimmed] = preset;
    _currentPresetName = trimmed;
    await SettingsService.instance.saveCustomEqualizerPreset(trimmed, preset.toMap());
    _persistSettings();
  }

  /// Delete a user custom preset
  Future<void> deleteCustomPreset(String name) async {
    _customPresets.remove(name);
    await SettingsService.instance.deleteCustomEqualizerPreset(name);
    if (_currentPresetName == name) {
      await applyPreset('Normal');
    }
  }

  /// Save current EQ curve for a specific song
  Future<void> saveCurrentForSong(String songId) async {
    if (songId.isEmpty) return;
    final data = <String, dynamic>{
      'preset': _currentPresetName,
      'bassBoost': _bassBoostLevel,
      'treble': _trebleLevel,
      'reverb': _reverbPreset.name,
    };
    await SettingsService.instance.setSongEqualizer(songId, data);
  }

  /// Clear per-song EQ memory
  Future<void> clearForSong(String songId) async {
    if (songId.isEmpty) return;
    await SettingsService.instance.setSongEqualizer(songId, null);
  }

  /// Check if a song has an individual EQ profile
  bool hasSongEqualizer(String songId) {
    if (songId.isEmpty) return false;
    return SettingsService.instance.getSongEqualizer(songId) != null;
  }

  /// Recall and apply per-song EQ if saved; otherwise restore global active preset
  Future<bool> applyPresetForSong(String songId) async {
    if (songId.isEmpty) return false;
    final customData = SettingsService.instance.getSongEqualizer(songId);
    if (customData != null) {
      final presetName = customData['preset'] as String? ?? 'Custom';
      _currentPresetName = presetName;
      _bassBoostLevel = (customData['bassBoost'] as num?)?.toDouble() ?? 0.5;
      _trebleLevel = (customData['treble'] as num?)?.toDouble() ?? 0.5;
      _bassBoostEnabled = _bassBoostLevel > 0.0;
      final reverbName = customData['reverb'] as String?;
      _reverbPreset = ReverbPreset.values.firstWhere(
        (r) => r.name == reverbName,
        orElse: () => ReverbPreset.none,
      );
      if (_isSupported) {
        await _reapplyEffects();
      }
      return true;
    } else {
      _loadPersistedSettings();
      if (_isSupported) {
        await _reapplyEffects();
      }
      return false;
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
      _isSupported = false;
      _audioSessionId = 0;
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
  final bool isCustom;
  
  const EqualizerPreset({
    required this.name,
    required this.bassBoost,
    required this.treble,
    required this.reverb,
    this.isCustom = false,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'bassBoost': bassBoost,
    'treble': treble,
    'reverb': reverb.name,
    'isCustom': isCustom,
  };

  factory EqualizerPreset.fromMap(Map<dynamic, dynamic> map) {
    final reverbName = map['reverb'] as String?;
    return EqualizerPreset(
      name: map['name'] as String? ?? 'Custom',
      bassBoost: (map['bassBoost'] as num?)?.toDouble() ?? 0.5,
      treble: (map['treble'] as num?)?.toDouble() ?? 0.5,
      reverb: ReverbPreset.values.firstWhere(
        (r) => r.name == reverbName,
        orElse: () => ReverbPreset.none,
      ),
      isCustom: map['isCustom'] as bool? ?? true,
    );
  }
}

