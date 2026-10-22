import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/formatters.dart';
import 'local_backup_service.dart';
import 'settings_service.dart';
import 'storage_service.dart';

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

  /// Copies formatted diagnostic text to the device clipboard.
  Future<void> copyToClipboard(BuildContext context) async {
    final text = await formatDiagnosticsText();
    await Clipboard.setData(ClipboardData(text: text));
  }
}
