import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
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
enum PlayerUiStyle { classic, modern, vinyl }

extension PlayerUiStyleX on PlayerUiStyle {
  String get label => switch (this) {
        PlayerUiStyle.classic => 'Classic',
        PlayerUiStyle.modern => 'Modern',
        PlayerUiStyle.vinyl => 'Vinyl',
      };

  static PlayerUiStyle fromValue(String? value) {
    return PlayerUiStyle.values.firstWhere(
      (style) => style.name == value,
      orElse: () => PlayerUiStyle.modern,
    );
  }
}

/// Identifiers for customizable sections on the Home feed
enum HomeSectionId {
  hero('Quick Play & Greeting', 'Quick play hero banner at top'),
  jumpBackIn('Jump Back In', 'Continue from recently played tracks'),
  recommended('Recommended For You', 'Personalized algorithm picks'),
  newAlbums('From Your Artists', 'Fresh album releases from artists you play'),
  trending('Trending Now', 'Top trending tracks for your region'),
  charts('Top Charts', 'Billboard and regional charts'),
  curatedMoods('Made For Your Mood', 'Hand-picked mood and genre mixes'),
  historyPrompt('Listening History', 'Bottom shortcut to recent listening history');

  final String label;
  final String description;
  const HomeSectionId(this.label, this.description);
}

/// Service for managing app settings with persistence
class SettingsService {
  static const String _boxName = 'app_settings';
  static const String _homeSectionsConfigKey = 'home_sections_config';
  static const String _playerUiStyleKey = 'player_ui_style';
  static const String _fastStartKey = 'fast_start_enabled';
  static const String _prefetchLookaheadKey = 'prefetch_lookahead';
  static const String _downloadFolderKey = 'download_folder_path';
  static const String _themeModeKey = 'theme_mode';
  static const String _dynamicAccentKey = 'dynamic_accent';
  static const String _layoutModeKey = 'layout_mode';
  static const String _onboardingCompleteKey = 'onboarding_complete';
  static const String _autoBackupKey = 'auto_backup_enabled';
  static const String _sharedBackupKey = 'shared_backup_enabled';
  static const String _autoPlayKey = 'auto_play_enabled';
  static const String _preferredLanguagesKey = 'preferred_music_languages';
  static const String _notInterestedSongsKey = 'not_interested_songs';
  static const String _notInterestedArtistsKey = 'not_interested_artists';
  static const String _eqPresetKey = 'eq_preset';
  static const String _eqBassBoostLevelKey = 'eq_bass_boost_level';
  static const String _eqTrebleLevelKey = 'eq_treble_level';
  static const String _eqReverbKey = 'eq_reverb';
  static const String _spotifyClientIdKey = 'spotify_client_id';
  static const String _spotifyClientSecretKey = 'spotify_client_secret';
  static const String _restoreQueueOnLaunchKey = 'restore_queue_on_launch';
  static const String _excludeIncognitoQueueKey = 'exclude_incognito_queue';
  static const String _appLanguageKey = 'app_language';
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

  /// Whether infinite autoplay/recommendations is enabled when queue ends
  bool get autoPlay {
    try {
      return _settingsBox?.get(_autoPlayKey, defaultValue: true) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Persist autoplay preference
  Future<void> setAutoPlay(bool enabled) async {
    await _settingsBox?.put(_autoPlayKey, enabled);
  }

  /// Get user's preferred music languages (e.g. ['English', 'Hindi', 'Punjabi'])
  List<String> get preferredLanguages {
    try {
      final list = _settingsBox?.get(_preferredLanguagesKey);
      if (list is List) return List<String>.from(list);
      return const ['English', 'Hindi'];
    } catch (_) {
      return const ['English', 'Hindi'];
    }
  }

  /// Persist preferred music languages
  Future<void> setPreferredLanguages(List<String> languages) async {
    await _settingsBox?.put(_preferredLanguagesKey, languages);
  }

  /// Get set of songs marked "Not Interested"
  Set<String> get notInterestedSongs {
    try {
      final list = _settingsBox?.get(_notInterestedSongsKey);
      if (list is List) return Set<String>.from(list);
      return const {};
    } catch (_) {
      return const {};
    }
  }

  /// Mark song as not interested
  Future<void> markSongNotInterested(String songId) async {
    final set = notInterestedSongs.toSet()..add(songId);
    await _settingsBox?.put(_notInterestedSongsKey, set.toList());
  }

  /// Unmark song from not interested
  Future<void> unmarkSongNotInterested(String songId) async {
    final set = notInterestedSongs.toSet()..remove(songId);
    await _settingsBox?.put(_notInterestedSongsKey, set.toList());
  }

  /// Get set of artists marked "Not Interested"
  Set<String> get notInterestedArtists {
    try {
      final list = _settingsBox?.get(_notInterestedArtistsKey);
      if (list is List) return Set<String>.from(list);
      return const {};
    } catch (_) {
      return const {};
    }
  }

  /// Mark artist as not interested
  Future<void> markArtistNotInterested(String artist) async {
    final set = notInterestedArtists.toSet()..add(artist.trim().toLowerCase());
    await _settingsBox?.put(_notInterestedArtistsKey, set.toList());
  }

  /// Clear all not interested feedback
  Future<void> clearNotInterested() async {
    await _settingsBox?.delete(_notInterestedSongsKey);
    await _settingsBox?.delete(_notInterestedArtistsKey);
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

  /// Get active equalizer preset name (default: Normal)
  String get equalizerPreset {
    try {
      return _settingsBox?.get(_eqPresetKey, defaultValue: 'Normal') ?? 'Normal';
    } catch (_) {
      return 'Normal';
    }
  }

  /// Persist active equalizer preset name
  Future<void> setEqualizerPreset(String preset) async {
    await _settingsBox?.put(_eqPresetKey, preset);
  }

  /// Get active equalizer bass boost level (0.0 to 1.0)
  double get equalizerBassBoostLevel {
    try {
      return (_settingsBox?.get(_eqBassBoostLevelKey, defaultValue: 0.5) as num?)?.toDouble() ?? 0.5;
    } catch (_) {
      return 0.5;
    }
  }

  /// Persist active equalizer bass boost level
  Future<void> setEqualizerBassBoostLevel(double level) async {
    await _settingsBox?.put(_eqBassBoostLevelKey, level);
  }

  /// Get active equalizer treble level (0.0 to 1.0)
  double get equalizerTrebleLevel {
    try {
      return (_settingsBox?.get(_eqTrebleLevelKey, defaultValue: 0.5) as num?)?.toDouble() ?? 0.5;
    } catch (_) {
      return 0.5;
    }
  }

  /// Persist active equalizer treble level
  Future<void> setEqualizerTrebleLevel(double level) async {
    await _settingsBox?.put(_eqTrebleLevelKey, level);
  }

  /// Get active equalizer reverb preset name (default: none)
  String get equalizerReverb {
    try {
      return _settingsBox?.get(_eqReverbKey, defaultValue: 'none') ?? 'none';
    } catch (_) {
      return 'none';
    }
  }

  /// Persist active equalizer reverb preset name
  Future<void> setEqualizerReverb(String reverb) async {
    await _settingsBox?.put(_eqReverbKey, reverb);
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
      defaultValue: PlayerUiStyle.modern.name,
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

  /// Selected theme mode (system / light / dark)
  ThemeMode get themeMode {
    final stored =
        _settingsBox?.get(_themeModeKey, defaultValue: 'system') as String?;
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  /// Persist theme mode preference
  Future<void> setThemeMode(ThemeMode mode) async {
    await _settingsBox?.put(_themeModeKey, mode.name);
  }

  /// Whether the accent color adapts to the current song's artwork
  bool get dynamicAccent {
    try {
      return _settingsBox?.get(_dynamicAccentKey, defaultValue: true) ?? true;
    } catch (e) {
      return true;
    }
  }

  /// Persist dynamic accent preference
  Future<void> setDynamicAccent(bool enabled) async {
    await _settingsBox?.put(_dynamicAccentKey, enabled);
  }

  /// Selected layout mode (list / grid / minimalist)
  String get layoutMode {
    final stored = _settingsBox?.get(_layoutModeKey, defaultValue: 'list') as String?;
    return stored ?? 'list';
  }

  /// Persist layout mode preference
  Future<void> setLayoutMode(String mode) async {
    await _settingsBox?.put(_layoutModeKey, mode);
  }

  /// Whether the first-launch onboarding has been completed
  bool get onboardingComplete {
    try {
      return _settingsBox?.get(_onboardingCompleteKey, defaultValue: false) ??
          false;
    } catch (e) {
      return false;
    }
  }

  /// Persist onboarding completion
  Future<void> setOnboardingComplete() async {
    await _settingsBox?.put(_onboardingCompleteKey, true);
  }

  /// Whether the library is backed up automatically after changes.
  /// The automatic backup goes to app-private storage only.
  bool get autoBackupEnabled {
    try {
      return _settingsBox?.get(_autoBackupKey, defaultValue: true) ?? true;
    } catch (e) {
      return true;
    }
  }

  /// Persist auto-backup preference
  Future<void> setAutoBackupEnabled(bool enabled) async {
    await _settingsBox?.put(_autoBackupKey, enabled);
  }

  /// Whether an extra backup copy is kept in shared storage (public
  /// Downloads on Android). That copy survives an uninstall but is readable
  /// by other apps with storage access, so it is strictly opt-in.
  bool get sharedBackupEnabled {
    try {
      return _settingsBox?.get(_sharedBackupKey, defaultValue: false) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Persist shared-backup opt-in
  Future<void> setSharedBackupEnabled(bool enabled) async {
    await _settingsBox?.put(_sharedBackupKey, enabled);
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

  /// Optional Spotify Developer Client ID for uncapped imports and ISRC metadata.
  String? get spotifyClientId {
    try {
      return _settingsBox?.get(_spotifyClientIdKey) as String?;
    } catch (_) {
      return null;
    }
  }

  /// Persist Spotify Developer Client ID.
  Future<void> setSpotifyClientId(String? id) async {
    if (id == null || id.trim().isEmpty) {
      await _settingsBox?.delete(_spotifyClientIdKey);
    } else {
      await _settingsBox?.put(_spotifyClientIdKey, id.trim());
    }
  }

  /// Optional Spotify Developer Client Secret for uncapped imports and ISRC metadata.
  String? get spotifyClientSecret {
    try {
      return _settingsBox?.get(_spotifyClientSecretKey) as String?;
    } catch (_) {
      return null;
    }
  }

  /// Persist Spotify Developer Client Secret.
  Future<void> setSpotifyClientSecret(String? secret) async {
    if (secret == null || secret.trim().isEmpty) {
      await _settingsBox?.delete(_spotifyClientSecretKey);
    } else {
      await _settingsBox?.put(_spotifyClientSecretKey, secret.trim());
    }
  }

  /// List of enabled home section IDs (by name).
  List<String> get enabledHomeSections {
    try {
      final raw = _settingsBox?.get(_homeSectionsConfigKey);
      if (raw is List) {
        return raw.cast<String>();
      }
      return HomeSectionId.values.map((s) => s.name).toList();
    } catch (_) {
      return HomeSectionId.values.map((s) => s.name).toList();
    }
  }

  /// Whether a specific home section is enabled.
  bool isHomeSectionEnabled(HomeSectionId section) {
    return enabledHomeSections.contains(section.name);
  }

  /// Enable or disable a specific home section.
  Future<void> setHomeSectionEnabled(HomeSectionId section, bool enabled) async {
    final current = List<String>.from(enabledHomeSections);
    if (enabled && !current.contains(section.name)) {
      current.add(section.name);
    } else if (!enabled) {
      current.remove(section.name);
    }
    await _settingsBox?.put(_homeSectionsConfigKey, current);
  }

  /// Reset all home sections to default (all enabled).
  Future<void> resetHomeSections() async {
    await _settingsBox?.put(
      _homeSectionsConfigKey,
      HomeSectionId.values.map((s) => s.name).toList(),
    );
  }

  /// Whether to persist and restore previous queue on app launch.
  bool get restoreQueueOnLaunch {
    try {
      return _settingsBox?.get(_restoreQueueOnLaunchKey, defaultValue: true) as bool? ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Persist restore queue on launch setting.
  Future<void> setRestoreQueueOnLaunch(bool value) async {
    await _settingsBox?.put(_restoreQueueOnLaunchKey, value);
  }

  /// Whether to exclude incognito/private listening sessions from being persisted.
  bool get excludeIncognitoQueue {
    try {
      return _settingsBox?.get(_excludeIncognitoQueueKey, defaultValue: true) as bool? ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Persist exclude incognito queue setting.
  Future<void> setExcludeIncognitoQueue(bool value) async {
    await _settingsBox?.put(_excludeIncognitoQueueKey, value);
  }

  /// Current app localization language code (default: 'en').
  String get appLanguage {
    try {
      return _settingsBox?.get(_appLanguageKey, defaultValue: 'en') as String? ?? 'en';
    } catch (_) {
      return 'en';
    }
  }

  /// Persist app localization language code.
  Future<void> setAppLanguage(String code) async {
    await _settingsBox?.put(_appLanguageKey, code);
  }
}


