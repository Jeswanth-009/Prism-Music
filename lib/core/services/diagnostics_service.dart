import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../benchmark/playback_benchmark_matrix.dart';
import '../di/injection.dart';
import '../../domain/entities/song.dart';
import '../providers/audio_stream_resolver.dart';
import '../utils/formatters.dart';
import 'local_backup_service.dart';
import 'settings_service.dart';
import 'storage_service.dart';
import 'stream_loader_service.dart';

/// Diagnostic summary and metadata collector for support, debugging, and bug reporting.
class DiagnosticsService {
  DiagnosticsService._();

  static final DiagnosticsService instance = DiagnosticsService._();

  /// Collects comprehensive system, application, audio, and storage diagnostics.
  Future<Map<String, dynamic>> collectDiagnostics() async {
    String appName = 'Prism Music';
    String appVersion = 'Unknown';
    String buildNumber = 'Unknown';
    String packageName = 'Unknown';

    try {
      final info = await PackageInfo.fromPlatform();
      appName = info.appName.isNotEmpty ? info.appName : 'Prism Music';
      appVersion = info.version;
      buildNumber = info.buildNumber;
      packageName = info.packageName;
    } catch (_) {
      // Best-effort in headless or test environments
    }

    final settings = SettingsService.instance;
    int cacheBytes = 0;
    try {
      final breakdown = await StorageService.instance.getStorageBreakdown();
      cacheBytes = breakdown.cacheBytes;
    } catch (_) {}

    int backupCount = 0;
    String? latestBackupDate;
    try {
      final latest = await LocalBackupService.instance.getLatestBackupInfo();
      if (latest != null) {
        backupCount = latest.totalItems;
        latestBackupDate = Formatters.formatDate(latest.timestamp);
      }
    } catch (_) {}

    final buildMode = kReleaseMode
        ? 'Release'
        : kProfileMode
            ? 'Profile'
            : 'Debug';

    return <String, dynamic>{
      'app': {
        'name': appName,
        'version': appVersion,
        'buildNumber': buildNumber,
        'packageName': packageName,
        'buildMode': buildMode,
      },
      'platform': {
        'os': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'dartVersion': Platform.version.split(' ').first,
      },
      'audioSettings': {
        'quality': settings.audioQuality,
        'fastStart': settings.fastStartEnabled,
        'autoPlay': settings.autoPlay,
        'crossfade': settings.crossfadeDuration > 0,
        'equalizerPreset': settings.equalizerPreset,
        'bassBoost': settings.bassBoostEnabled,
      },
      'storage': {
        'cacheUsage': Formatters.formatBytes(cacheBytes),
        'backupItems': backupCount,
        'latestBackup': latestBackupDate ?? 'None',
      },
    };
  }

  /// Formats the collected diagnostics as a markdown snippet suitable for GitHub issues or support chats.
  Future<String> formatDiagnosticsText() async {
    final data = await collectDiagnostics();
    final app = data['app'] as Map<String, dynamic>;
    final platform = data['platform'] as Map<String, dynamic>;
    final audio = data['audioSettings'] as Map<String, dynamic>;
    final storage = data['storage'] as Map<String, dynamic>;

    final buffer = StringBuffer();
    buffer.writeln('### Prism Music Diagnostics');
    buffer.writeln('- **App Version:** ${app['version']}+${app['buildNumber']} (${app['buildMode']})');
    buffer.writeln('- **Package:** ${app['packageName']}');
    buffer.writeln('- **Operating System:** ${platform['os']} (${platform['osVersion']})');
    buffer.writeln('- **Dart Runtime:** ${platform['dartVersion']}');
    buffer.writeln('- **Audio Quality:** ${audio['quality']}');
    buffer.writeln('- **Audio Features:** FastStart=${audio['fastStart']}, AutoPlay=${audio['autoPlay']}, Crossfade=${audio['crossfade']}, EQ=${audio['equalizerPreset']}, BassBoost=${audio['bassBoost']}');
    buffer.writeln('- **Storage:** Cache=${storage['cacheUsage']}, Backups=${storage['backupItems']} items (Latest: ${storage['latestBackup']})');

    return buffer.toString();
  }

  /// Runs the playback benchmark matrix and returns the detailed performance report.
  Future<PlaybackBenchmarkReport> runPlaybackBenchmark({Song? testSong}) async {
    List<AudioStreamResolver> resolvers = const [];
    if (getIt.isRegistered<StreamLoaderService>()) {
      resolvers = getIt<StreamLoaderService>().resolvers;
    }
    final matrix = PlaybackBenchmarkMatrix(resolvers: resolvers);
    return matrix.runFullMatrix(testSong: testSong);
  }

  /// Copies formatted diagnostic text to the device clipboard.
  Future<void> copyToClipboard(BuildContext context) async {
    final text = await formatDiagnosticsText();
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Whether the user has explicitly opted into anonymous diagnostics telemetry.
  bool get hasTelemetryConsent => SettingsService.instance.telemetryConsent;

  /// Redacts Personally Identifiable Information (user directories, IP addresses, tokens) from [text].
  static String sanitizeText(String text) {
    if (text.isEmpty) return text;
    var sanitized = text;

    // 1. Redact Windows absolute user directory paths
    sanitized = sanitized.replaceAll(
      RegExp(r'[A-Za-z]:\\(?:Users|Documents|Downloads|AppData)\\[^\s"''`,)]+'),
      '[REDACTED_USER_PATH]',
    );

    // 2. Redact Unix/Android user directory paths
    sanitized = sanitized.replaceAll(
      RegExp(r'/(?:data/user/\d+|home/[^/\s]+|Users/[^/\s]+)/[^\s"''`,)]+'),
      '[REDACTED_USER_PATH]',
    );

    // 3. Redact IPv4 addresses
    sanitized = sanitized.replaceAll(
      RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'),
      '[REDACTED_IP]',
    );

    // 4. Redact tokens, secrets, and auth credentials
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'(client_secret|token|bearer|key)=([a-zA-Z0-9_\-\.]{8,})', caseSensitive: false),
      (match) => '${match[1]}=[REDACTED_SECRET]',
    );

    return sanitized;
  }

  /// Generates an entirely local, privacy-sanitized diagnostics bundle.
  Future<Map<String, dynamic>> generateSanitizedLocalBundle() async {
    final raw = await collectDiagnostics();
    final sanitizedMap = <String, dynamic>{
      'diagnosticsVersion': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'privacy': {
        'telemetryConsentGranted': hasTelemetryConsent,
        'piiSanitized': true,
        'mode': 'local_export_only',
      },
      'system': raw,
    };
    return sanitizedMap;
  }

  /// Serializes the sanitized diagnostics bundle as formatted JSON for local copy or file export.
  Future<String> exportSanitizedLocalBundleJson() async {
    final bundle = await generateSanitizedLocalBundle();
    const encoder = JsonEncoder.withIndent('  ');
    final jsonStr = encoder.convert(bundle);
    return sanitizeText(jsonStr);
  }
}
