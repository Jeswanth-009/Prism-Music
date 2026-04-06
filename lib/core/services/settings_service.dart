import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/logger.dart';

/// Country information for music region selection
class CountryInfo {
  final String code;
  final String name;
  final String flag;

  const CountryInfo({
    required this.code,
    required this.name,
    required this.flag,
  });
}

/// List of supported countries for music recommendations
const List<CountryInfo> supportedCountries = [
  CountryInfo(code: 'US', name: 'United States', flag: '🇺🇸'),
  CountryInfo(code: 'GB', name: 'United Kingdom', flag: '🇬🇧'),
  CountryInfo(code: 'IN', name: 'India', flag: '🇮🇳'),
  CountryInfo(code: 'CA', name: 'Canada', flag: '🇨🇦'),
  CountryInfo(code: 'AU', name: 'Australia', flag: '🇦🇺'),
  CountryInfo(code: 'DE', name: 'Germany', flag: '🇩🇪'),
  CountryInfo(code: 'FR', name: 'France', flag: '🇫🇷'),
  CountryInfo(code: 'JP', name: 'Japan', flag: '🇯🇵'),
  CountryInfo(code: 'KR', name: 'South Korea', flag: '🇰🇷'),
  CountryInfo(code: 'BR', name: 'Brazil', flag: '🇧🇷'),
  CountryInfo(code: 'MX', name: 'Mexico', flag: '🇲🇽'),
  CountryInfo(code: 'ES', name: 'Spain', flag: '🇪🇸'),
  CountryInfo(code: 'IT', name: 'Italy', flag: '🇮🇹'),
  CountryInfo(code: 'NL', name: 'Netherlands', flag: '🇳🇱'),
  CountryInfo(code: 'SE', name: 'Sweden', flag: '🇸🇪'),
  CountryInfo(code: 'NO', name: 'Norway', flag: '🇳🇴'),
  CountryInfo(code: 'RU', name: 'Russia', flag: '🇷🇺'),
  CountryInfo(code: 'PL', name: 'Poland', flag: '🇵🇱'),
  CountryInfo(code: 'TR', name: 'Turkey', flag: '🇹🇷'),
  CountryInfo(code: 'ID', name: 'Indonesia', flag: '🇮🇩'),
  CountryInfo(code: 'PH', name: 'Philippines', flag: '🇵🇭'),
  CountryInfo(code: 'TH', name: 'Thailand', flag: '🇹🇭'),
  CountryInfo(code: 'VN', name: 'Vietnam', flag: '🇻🇳'),
  CountryInfo(code: 'MY', name: 'Malaysia', flag: '🇲🇾'),
  CountryInfo(code: 'SG', name: 'Singapore', flag: '🇸🇬'),
  CountryInfo(code: 'ZA', name: 'South Africa', flag: '🇿🇦'),
  CountryInfo(code: 'EG', name: 'Egypt', flag: '🇪🇬'),
  CountryInfo(code: 'NG', name: 'Nigeria', flag: '🇳🇬'),
  CountryInfo(code: 'AE', name: 'United Arab Emirates', flag: '🇦🇪'),
  CountryInfo(code: 'SA', name: 'Saudi Arabia', flag: '🇸🇦'),
  CountryInfo(code: 'PK', name: 'Pakistan', flag: '🇵🇰'),
  CountryInfo(code: 'BD', name: 'Bangladesh', flag: '🇧🇩'),
  CountryInfo(code: 'AR', name: 'Argentina', flag: '🇦🇷'),
  CountryInfo(code: 'CL', name: 'Chile', flag: '🇨🇱'),
  CountryInfo(code: 'CO', name: 'Colombia', flag: '🇨🇴'),
  CountryInfo(code: 'NZ', name: 'New Zealand', flag: '🇳🇿'),
  CountryInfo(code: 'IE', name: 'Ireland', flag: '🇮🇪'),
  CountryInfo(code: 'PT', name: 'Portugal', flag: '🇵🇹'),
  CountryInfo(code: 'BE', name: 'Belgium', flag: '🇧🇪'),
  CountryInfo(code: 'AT', name: 'Austria', flag: '🇦🇹'),
  CountryInfo(code: 'CH', name: 'Switzerland', flag: '🇨🇭'),
];

/// Available layouts for the full screen player
enum PlayerUiStyle { classic, modern }

extension PlayerUiStyleX on PlayerUiStyle {
  String get label => switch (this) {
        PlayerUiStyle.classic => 'Classic',
        PlayerUiStyle.modern => 'Modern',
      };

  static PlayerUiStyle fromValue(String? value) {
    return PlayerUiStyle.values.firstWhere(
      (style) => style.name == value,
      orElse: () => PlayerUiStyle.classic,
    );
  }
}

/// Service for managing app settings with persistence
class SettingsService {
  static const String _boxName = 'app_settings';
  static const String _playerUiStyleKey = 'player_ui_style';
  static const String _fastStartKey = 'fast_start_enabled';
  static const String _prefetchLookaheadKey = 'prefetch_lookahead';
  static const String _downloadFolderKey = 'download_folder_path';
  static SettingsService? _instance;
  
  Box? _settingsBox;
  bool _initialized = false;

  // Private constructor for singleton
  SettingsService._();

  /// Get singleton instance
  static SettingsService get instance {
    _instance ??= SettingsService._();
    return _instance!;
  }

  /// Initialize the settings service
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      if (Hive.isBoxOpen(_boxName)) {
        _settingsBox = Hive.box(_boxName);
      } else {
        _settingsBox = await Hive.openBox(_boxName);
      }
      _initialized = true;
      logDebug('SettingsService: Initialized successfully');
    } catch (e, stack) {
      logError('SettingsService: Initialization error', e, stack);
      rethrow;
    }
  }

  /// Get the selected country code (default: US)
  String get countryCode {
    try {
      return _settingsBox?.get('country_code', defaultValue: 'US') ?? 'US';
    } catch (e, stack) {
      logError('SettingsService: Error getting country code', e, stack);
      return 'US';
    }
  }

  /// Get the CountryInfo for the selected country
  CountryInfo get selectedCountry {
    final code = countryCode;
    return supportedCountries.firstWhere(
      (c) => c.code == code,
      orElse: () => supportedCountries.first,
    );
  }

  /// Set the country code
  Future<void> setCountryCode(String code) async {
    await _settingsBox?.put('country_code', code);
    logDebug('SettingsService: Country set to $code');
  }

  /// Get audio quality setting
  String get audioQuality {
    try {
      return _settingsBox?.get('audio_quality', defaultValue: 'medium') ?? 'medium';
    } catch (e) {
      return 'medium';
    }
  }

  /// Set audio quality
  Future<void> setAudioQuality(String quality) async {
    await _settingsBox?.put('audio_quality', quality);
  }

  /// Get crossfade duration in seconds
  double get crossfadeDuration {
    try {
      return _settingsBox?.get('crossfade_duration', defaultValue: 0.0) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Set crossfade duration
  Future<void> setCrossfadeDuration(double seconds) async {
    await _settingsBox?.put('crossfade_duration', seconds);
  }

  /// Get auto shuffle setting
  bool get autoShuffle {
    try {
      return _settingsBox?.get('auto_shuffle', defaultValue: false) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Set auto shuffle
  Future<void> setAutoShuffle(bool enabled) async {
    await _settingsBox?.put('auto_shuffle', enabled);
  }

  /// Get bass boost setting
  bool get bassBoostEnabled {
    try {
      return _settingsBox?.get('bass_boost', defaultValue: false) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Set bass boost
  Future<void> setBassBoost(bool enabled) async {
    await _settingsBox?.put('bass_boost', enabled);
  }

  /// Enable faster startup by initially using medium quality streams
  bool get fastStartEnabled {
    try {
      return _settingsBox?.get(_fastStartKey, defaultValue: true) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setFastStartEnabled(bool enabled) async {
    await _settingsBox?.put(_fastStartKey, enabled);
  }

  /// Number of upcoming tracks to prefetch
  int get prefetchLookahead {
    try {
      return _settingsBox?.get(_prefetchLookaheadKey, defaultValue: 3) ?? 3;
    } catch (_) {
      return 3;
    }
  }

  Future<void> setPrefetchLookahead(int lookahead) async {
    final clamped = lookahead.clamp(0, 5); // Allow up to 5 for aggressive prefetch
    await _settingsBox?.put(_prefetchLookaheadKey, clamped);
  }

  /// Selected player UI layout
  PlayerUiStyle get playerUiStyle {
    final stored = _settingsBox?.get(
      _playerUiStyleKey,
      defaultValue: PlayerUiStyle.classic.name,
    );
    return PlayerUiStyleX.fromValue(stored as String?);
  }

  /// Persist player UI layout preference
  Future<void> setPlayerUiStyle(PlayerUiStyle style) async {
    await _settingsBox?.put(_playerUiStyleKey, style.name);
  }

  /// Listen for player layout changes to update the UI reactively
  ValueListenable<Box<dynamic>>? playerUiStyleListenable() {
    return _settingsBox?.listenable(keys: [_playerUiStyleKey]);
  }

  /// Get custom download folder path (null means use default)
  String? get downloadFolderPath {
    try {
      return _settingsBox?.get(_downloadFolderKey) as String?;
    } catch (e) {
      return null;
    }
  }

  /// Set custom download folder path
  Future<void> setDownloadFolderPath(String? path) async {
    if (path == null) {
      await _settingsBox?.delete(_downloadFolderKey);
    } else {
      await _settingsBox?.put(_downloadFolderKey, path);
    }
    logDebug('SettingsService: Download folder set to ${path ?? "default"}');
  }
}
