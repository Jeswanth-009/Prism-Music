import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'settings_service.dart';

/// Structured result of a settings backup/restore operation.
class SettingsBackupResult {
  final bool isSuccess;
  final int restoredCount;
  final String? error;
  final Map<String, dynamic>? settings;

  const SettingsBackupResult({
    required this.isSuccess,
    this.restoredCount = 0,
    this.error,
    this.settings,
  });
}

/// Service for exporting and importing Prism Music application settings
/// across devices via versioned, portable JSON backups.
class SettingsBackupService {
  SettingsBackupService._();

  static final SettingsBackupService instance = SettingsBackupService._();

  static const String backupIdentifier = 'prism_settings_backup';
  static const int currentSchemaVersion = 1;

  /// Serializes all persistent user preferences into a JSON string.
  /// Sensitive credentials (e.g. Spotify secrets) are excluded by default for security.
  String exportSettingsToJson({bool includeSensitiveCredentials = false}) {
    final s = SettingsService.instance;
    final settingsMap = <String, dynamic>{
      'theme_mode': s.themeMode.name,
      'dynamic_accent': s.dynamicAccent,
      'player_ui_style': s.playerUiStyle.name,
      'fast_start_enabled': s.fastStartEnabled,
      'prefetch_lookahead': s.prefetchLookahead,
      'visualizer_style': s.visualizerStyle.name,
      'audio_normalization_enabled': s.audioNormalizationEnabled,
      'audio_normalization_target': s.audioNormalizationTarget,
      'audio_normalization_preamp_db': s.audioNormalizationPreampDb,
      'eq_preset': s.equalizerPreset,
      'eq_bass_boost_level': s.equalizerBassBoostLevel,
      'eq_treble_level': s.equalizerTrebleLevel,
      'eq_reverb': s.equalizerReverb,
      'app_language': s.appLanguage,
      'preferred_music_languages': s.preferredLanguages,
      'country_code': s.countryCode,
      'download_wifi_only': s.downloadWifiOnly,
      'cellular_data_saver': s.cellularDataSaver,
      'download_audio_quality': s.downloadAudioQuality,
      'download_storage_quota_mb': s.downloadStorageQuotaMB,
      'auto_download_liked_songs': s.autoDownloadLikedSongs,
      'sleep_timer_bedtime_mode': s.sleepTimerBedtimeMode,
      'reduced_motion_mode': s.reducedMotionMode,
      'wear_os_companion_enabled': s.isWearOsCompanionEnabled,
    };

    final payload = {
      'identifier': backupIdentifier,
      'schema_version': currentSchemaVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'settings': settingsMap,
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Validates a candidate JSON string without applying changes
  (bool, String?, Map<String, dynamic>?) validateSettingsJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return (false, 'Invalid backup format: root must be a JSON object', null);
      }
      if (decoded['identifier'] != backupIdentifier) {
        return (false, 'Invalid file: not a Prism Music settings backup', null);
      }
      final rawSettings = decoded['settings'];
      if (rawSettings is! Map<String, dynamic>) {
        return (false, 'Backup contains no settings data', null);
      }
      return (true, null, rawSettings);
    } catch (e) {
      return (false, 'Corrupted JSON: $e', null);
    }
  }

  /// Imports and applies settings from a JSON string.
  /// Returns a [SettingsBackupResult] indicating success and count of restored keys.
  Future<SettingsBackupResult> importSettingsFromJson(String jsonString) async {
    final (isValid, error, settings) = validateSettingsJson(jsonString);
    if (!isValid || settings == null) {
      return SettingsBackupResult(
        isSuccess: false,
        error: error ?? 'Invalid backup payload',
      );
    }

    int restoredCount = 0;
    final s = SettingsService.instance;

    try {
      if (settings.containsKey('theme_mode')) {
        final modeName = settings['theme_mode'] as String?;
        final mode = ThemeMode.values.firstWhere(
          (m) => m.name == modeName,
          orElse: () => ThemeMode.dark,
        );
        await s.setThemeMode(mode);
        restoredCount++;
      }

      if (settings.containsKey('dynamic_accent')) {
        await s.setDynamicAccent(settings['dynamic_accent'] as bool? ?? false);
        restoredCount++;
      }

      if (settings.containsKey('player_ui_style')) {
        final style = PlayerUiStyleX.fromValue(settings['player_ui_style'] as String?);
        await s.setPlayerUiStyle(style);
        restoredCount++;
      }

      if (settings.containsKey('visualizer_style')) {
        final style = VisualizerStyleX.fromValue(settings['visualizer_style'] as String?);
        await s.setVisualizerStyle(style);
        restoredCount++;
      }

      if (settings.containsKey('fast_start_enabled')) {
        await s.setFastStartEnabled(settings['fast_start_enabled'] as bool? ?? true);
        restoredCount++;
      }

      if (settings.containsKey('prefetch_lookahead')) {
        await s.setPrefetchLookahead((settings['prefetch_lookahead'] as num?)?.toInt() ?? 2);
        restoredCount++;
      }

      if (settings.containsKey('audio_normalization_enabled')) {
        await s.setAudioNormalizationEnabled(settings['audio_normalization_enabled'] as bool? ?? true);
        restoredCount++;
      }

      if (settings.containsKey('audio_normalization_target')) {
        await s.setAudioNormalizationTarget(settings['audio_normalization_target']?.toString() ?? 'balanced');
        restoredCount++;
      }

      if (settings.containsKey('audio_normalization_preamp_db')) {
        await s.setAudioNormalizationPreampDb((settings['audio_normalization_preamp_db'] as num?)?.toDouble() ?? 0.0);
        restoredCount++;
      }

      if (settings.containsKey('eq_preset')) {
        await s.setEqualizerPreset(settings['eq_preset'] as String? ?? 'Normal');
        restoredCount++;
      }

      if (settings.containsKey('eq_bass_boost_level')) {
        await s.setEqualizerBassBoostLevel((settings['eq_bass_boost_level'] as num?)?.toDouble() ?? 0.5);
        restoredCount++;
      }

      if (settings.containsKey('eq_treble_level')) {
        await s.setEqualizerTrebleLevel((settings['eq_treble_level'] as num?)?.toDouble() ?? 0.5);
        restoredCount++;
      }

      if (settings.containsKey('eq_reverb')) {
        await s.setEqualizerReverb(settings['eq_reverb'] as String? ?? 'none');
        restoredCount++;
      }

      if (settings.containsKey('app_language')) {
        await s.setAppLanguage(settings['app_language'] as String? ?? 'en');
        restoredCount++;
      }

      if (settings.containsKey('preferred_music_languages')) {
        final langs = (settings['preferred_music_languages'] as List?)?.map((e) => e.toString()).toList() ?? ['en'];
        await s.setPreferredLanguages(langs);
        restoredCount++;
      }

      if (settings.containsKey('country_code')) {
        await s.setCountryCode(settings['country_code'] as String? ?? 'US');
        restoredCount++;
      }

      if (settings.containsKey('download_wifi_only')) {
        await s.setDownloadWifiOnly(settings['download_wifi_only'] as bool? ?? true);
        restoredCount++;
      }

      if (settings.containsKey('cellular_data_saver')) {
        await s.setCellularDataSaver(settings['cellular_data_saver'] as bool? ?? false);
        restoredCount++;
      }

      if (settings.containsKey('download_audio_quality')) {
        await s.setDownloadAudioQuality(settings['download_audio_quality'] as String? ?? 'high');
        restoredCount++;
      }

      if (settings.containsKey('download_storage_quota_mb')) {
        await s.setDownloadStorageQuotaMB((settings['download_storage_quota_mb'] as num?)?.toInt() ?? 2048);
        restoredCount++;
      }

      if (settings.containsKey('auto_download_liked_songs')) {
        await s.setAutoDownloadLikedSongs(settings['auto_download_liked_songs'] as bool? ?? false);
        restoredCount++;
      }

      if (settings.containsKey('sleep_timer_bedtime_mode')) {
        await s.setSleepTimerBedtimeMode(settings['sleep_timer_bedtime_mode'] as bool? ?? false);
        restoredCount++;
      }

      if (settings.containsKey('reduced_motion_mode')) {
        await s.setReducedMotionMode(settings['reduced_motion_mode'] as bool? ?? false);
        restoredCount++;
      }

      if (settings.containsKey('wear_os_companion_enabled')) {
        await s.setWearOsCompanionEnabled(settings['wear_os_companion_enabled'] as bool? ?? true);
        restoredCount++;
      }

      return SettingsBackupResult(
        isSuccess: true,
        restoredCount: restoredCount,
        settings: settings,
      );
    } catch (e) {
      debugPrint('SettingsBackupService: Import error: $e');
      return SettingsBackupResult(
        isSuccess: false,
        restoredCount: restoredCount,
        error: e.toString(),
      );
    }
  }
}
