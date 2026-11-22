import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';
import 'settings_service.dart';

/// State of an in-app update download operation.
enum UpdateStatus {
  idle,
  downloading,
  readyToInstall,
  installing,
  failed,
}

/// Progress and status model for in-app APK downloads.
class UpdateDownloadState {
  final UpdateStatus status;
  final double progress; // 0.0 to 1.0
  final int bytesReceived;
  final int totalBytes;
  final String? localApkPath;
  final String? errorMessage;

  const UpdateDownloadState({
    this.status = UpdateStatus.idle,
    this.progress = 0.0,
    this.bytesReceived = 0,
    this.totalBytes = 0,
    this.localApkPath,
    this.errorMessage,
  });

  bool get isDownloading => status == UpdateStatus.downloading;
  bool get isReady => status == UpdateStatus.readyToInstall;
  bool get isFailed => status == UpdateStatus.failed;

  String get receivedMb => (bytesReceived / (1024 * 1024)).toStringAsFixed(1);
  String get totalMb => totalBytes > 0
      ? (totalBytes / (1024 * 1024)).toStringAsFixed(1)
      : '0.0';
  int get percent => (progress * 100).clamp(0, 100).toInt();

  UpdateDownloadState copyWith({
    UpdateStatus? status,
    double? progress,
    int? bytesReceived,
    int? totalBytes,
    String? localApkPath,
    String? errorMessage,
  }) {
    return UpdateDownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      totalBytes: totalBytes ?? this.totalBytes,
      localApkPath: localApkPath ?? this.localApkPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Data model representing an app update check outcome.
class AppUpdateInfo {
  final String latestVersion;
  final int latestBuildNumber;
  final String currentVersion;
  final int currentBuildNumber;
  final String title;
  final String changelog;
  final String releaseUrl;
  final String? apkDownloadUrl;
  final bool hasUpdate;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.title,
    required this.changelog,
    required this.releaseUrl,
    this.apkDownloadUrl,
    required this.hasUpdate,
  });

  String get versionTransition =>
      'v$currentVersion (+$currentBuildNumber) → v$latestVersion (+$latestBuildNumber)';

  @override
  String toString() =>
      'AppUpdateInfo(hasUpdate: $hasUpdate, current: $currentVersion+$currentBuildNumber, latest: $latestVersion+$latestBuildNumber)';
}

/// Service for checking app updates against GitHub Releases and downloading
/// and automatically installing updates on Android without browser redirection.
class AppUpdateService {
  static const String _defaultApiUrl =
      'https://api.github.com/repos/Jeswanth-009/Prism-Music/releases/latest';
  static const Duration _timeout = Duration(seconds: 4);
  static const Duration _cacheDuration = Duration(minutes: 15);
  static const Duration _throttleDuration = Duration(hours: 24);
  static const MethodChannel _installerChannel =
      MethodChannel('com.prismmusic/app_installer');

  final http.Client _client;
  final Dio _dio;
  final String _apiUrl;

  AppUpdateInfo? _cachedInfo;
  DateTime? _lastCheckTime;
  String? _dismissedVersion;
  CancelToken? _downloadCancelToken;

  /// Reactive download progress notifier for UI binding.
  final ValueNotifier<UpdateDownloadState> downloadState =
      ValueNotifier(const UpdateDownloadState());

  static AppUpdateService? _instance;
  static AppUpdateService get instance => _instance ??= AppUpdateService();

  AppUpdateService({
    http.Client? client,
    Dio? dio,
    String apiUrl = _defaultApiUrl,
  })  : _client = client ?? http.Client(),
        _dio = dio ?? Dio(),
        _apiUrl = apiUrl;

  /// Mark a version as dismissed for the active app session.
  void dismissVersion(String version) {
    _dismissedVersion = version;
  }

  /// Whether the user previously chose 'Later' for this version.
  bool isDismissed(String version) => _dismissedVersion == version;

  /// Check for application updates.
  Future<AppUpdateInfo?> checkForUpdate({
    bool force = false,
    PackageInfo? overridePackageInfo,
  }) async {
    // 1. Persistent 24-hour rate limit check (bypass if force is true)
    if (!force) {
      if (_cachedInfo != null &&
          _lastCheckTime != null &&
          DateTime.now().difference(_lastCheckTime!) < _cacheDuration) {
        return _cachedInfo;
      }
      try {
        final lastCheck =
            SettingsService.instance.lastUpdateCheckTime ?? _lastCheckTime;
        if (lastCheck != null &&
            DateTime.now().difference(lastCheck) < _throttleDuration) {
          logDebug('AppUpdateService: Update check skipped (throttled to 24 hours)');
          return _cachedInfo;
        }
      } catch (_) {
        // Fall back gracefully if Hive/settings box not yet ready
      }
    }

    try {
      final packageInfo = overridePackageInfo ?? await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version.trim();
      final currentBuildNumber =
          int.tryParse(packageInfo.buildNumber.trim()) ?? 0;

      final uri = Uri.parse(_apiUrl);
      final response = await _client.get(
        uri,
        headers: const {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Prism-Music-App',
        },
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        logError(
          'AppUpdateService: GitHub API returned status ${response.statusCode}',
        );
        return null;
      }

      final decoded = json.decode(response.body);
      Map<String, dynamic> latestRelease;
      if (decoded is List) {
        if (decoded.isEmpty) {
          logDebug('AppUpdateService: No releases returned by GitHub');
          return null;
        }
        latestRelease = decoded.first as Map<String, dynamic>;
      } else if (decoded is Map<String, dynamic>) {
        latestRelease = decoded;
      } else {
        logDebug('AppUpdateService: Unexpected response format from GitHub');
        return null;
      }
      final tagName = (latestRelease['tag_name'] as String?) ?? '';
      final releaseName = (latestRelease['name'] as String?) ?? tagName;
      final releaseUrl = (latestRelease['html_url'] as String?) ??
          'https://github.com/Jeswanth-009/Prism-Music/releases';
      final body = (latestRelease['body'] as String?) ?? '';
      final assets = (latestRelease['assets'] as List?) ?? const [];

      // Parse release version & build number from tag or release metadata
      final parsed = _parseVersionFromTag(tagName, body);
      final latestVersion = parsed.$1;
      final latestBuildNumber = parsed.$2;

      // Determine if the release is strictly newer
      final hasUpdate = _isUpdateAvailable(
        currentVersion: currentVersion,
        currentBuild: currentBuildNumber,
        latestVersion: latestVersion,
        latestBuild: latestBuildNumber,
      );

      // Extract ARM phone release APK asset if available
      final apkDownloadUrl = _extractApkDownloadUrl(assets);

      // Extract readable changelog notes
      final changelog = _cleanChangelog(body);

      final updateInfo = AppUpdateInfo(
        latestVersion: latestVersion,
        latestBuildNumber: latestBuildNumber,
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
        title: releaseName,
        changelog: changelog,
        releaseUrl: releaseUrl,
        apkDownloadUrl: apkDownloadUrl,
        hasUpdate: hasUpdate,
      );

      _cachedInfo = updateInfo;
      _lastCheckTime = DateTime.now();
      try {
        await SettingsService.instance.setLastUpdateCheckTime(_lastCheckTime!);
      } catch (_) {}

      return updateInfo;
    } catch (e, stack) {
      logError('AppUpdateService: Error checking for update', e, stack);
      return null;
    }
  }

  /// Downloads the release APK in the background with progress reporting and
  /// automatically triggers native Android installation when done.
  Future<void> startDownload(AppUpdateInfo info) async {
    final downloadUrl = info.apkDownloadUrl;
    if (downloadUrl == null || downloadUrl.isEmpty) {
      downloadState.value = downloadState.value.copyWith(
        status: UpdateStatus.failed,
        errorMessage: 'Direct APK download URL is not available.',
      );
      return;
    }

    _downloadCancelToken?.cancel();
    _downloadCancelToken = CancelToken();

    downloadState.value = const UpdateDownloadState(
      status: UpdateStatus.downloading,
      progress: 0.0,
      bytesReceived: 0,
      totalBytes: 0,
    );

    try {
      final cacheDir = await getTemporaryDirectory();
      final updatesDir = Directory('${cacheDir.path}/app_updates');
      if (!await updatesDir.exists()) {
        await updatesDir.create(recursive: true);
      }

      final savePath = '${updatesDir.path}/PrismMusic_${info.latestVersion}.apk';
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }

      await _dio.download(
        downloadUrl,
        savePath,
        cancelToken: _downloadCancelToken,
        options: Options(
          headers: {
            'User-Agent': 'Prism-Music-App',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = (received / total).clamp(0.0, 1.0);
            downloadState.value = UpdateDownloadState(
              status: UpdateStatus.downloading,
              progress: progress,
              bytesReceived: received,
              totalBytes: total,
            );
          }
        },
      );

      // Verify file downloaded successfully
      if (await file.exists() && await file.length() > 0) {
        downloadState.value = UpdateDownloadState(
          status: UpdateStatus.readyToInstall,
          progress: 1.0,
          bytesReceived: await file.length(),
          totalBytes: await file.length(),
          localApkPath: savePath,
        );

        // Automatically trigger native installation on Android
        if (Platform.isAndroid) {
          await installDownloadedApk(savePath);
        }
      } else {
        downloadState.value = downloadState.value.copyWith(
          status: UpdateStatus.failed,
          errorMessage: 'Downloaded APK was empty or missing.',
        );
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        downloadState.value = const UpdateDownloadState(status: UpdateStatus.idle);
        return;
      }
      logError('AppUpdateService: Error downloading update', e);
      downloadState.value = downloadState.value.copyWith(
        status: UpdateStatus.failed,
        errorMessage: 'Download failed: $e',
      );
    }
  }

  /// Cancels any active download operation and resets state.
  void cancelDownload() {
    _downloadCancelToken?.cancel('User cancelled download');
    _downloadCancelToken = null;
    downloadState.value = const UpdateDownloadState(status: UpdateStatus.idle);
  }

  /// Prompts the native Android package installer to install the downloaded APK.
  Future<bool> installDownloadedApk(String filePath) async {
    if (!Platform.isAndroid) return false;
    try {
      downloadState.value = downloadState.value.copyWith(
        status: UpdateStatus.installing,
      );
      final result = await _installerChannel.invokeMethod<bool>(
        'installApk',
        {'filePath': filePath},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      logError('AppUpdateService: Failed to launch installer', e);
      downloadState.value = downloadState.value.copyWith(
        status: UpdateStatus.readyToInstall,
        errorMessage: e.message ?? 'Installation failed',
      );
      return false;
    }
  }

  (String, int) _parseVersionFromTag(String tag, String body) {
    final tagRegex = RegExp(
      r'v?(\d+\.\d+\.\d+)(?:-build|\+)?(\d+)?',
      caseSensitive: false,
    );
    final match = tagRegex.firstMatch(tag);

    String version = '0.0.0';
    int build = 0;

    if (match != null) {
      version = match.group(1) ?? '0.0.0';
      if (match.group(2) != null) {
        build = int.tryParse(match.group(2)!) ?? 0;
      }
    }

    if (build == 0) {
      final codeMatch = RegExp(
        r'\|\s*\*\*versionCode\*\*\s*\|\s*`?(\d+)`?\s*\|',
        caseSensitive: false,
      ).firstMatch(body);
      if (codeMatch != null && codeMatch.group(1) != null) {
        build = int.tryParse(codeMatch.group(1)!) ?? 0;
      }
    }

    return (version, build);
  }

  bool _isUpdateAvailable({
    required String currentVersion,
    required int currentBuild,
    required String latestVersion,
    required int latestBuild,
  }) {
    if (latestBuild > 0 && currentBuild > 0) {
      if (latestBuild > currentBuild) return true;
      if (latestBuild < currentBuild) return false;
    }
    return _compareSemver(latestVersion, currentVersion) > 0;
  }

  int _compareSemver(String v1, String v2) {
    final parts1 = v1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final parts2 = v2.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    while (parts1.length < 3) {
      parts1.add(0);
    }
    while (parts2.length < 3) {
      parts2.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (parts1[i] > parts2[i]) return 1;
      if (parts1[i] < parts2[i]) return -1;
    }
    return 0;
  }

  String? _extractApkDownloadUrl(List assets) {
    String? fallbackApk;

    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = (asset['name'] as String?)?.toLowerCase() ?? '';
      final url = asset['browser_download_url'] as String?;

      if (url == null) continue;

      if (name.endsWith('.apk') && !name.contains('emulator')) {
        return url;
      }

      if (name.endsWith('.apk') && fallbackApk == null) {
        fallbackApk = url;
      }
    }

    return fallbackApk;
  }

  String _cleanChangelog(String body) {
    if (body.trim().isEmpty) {
      return 'Performance improvements, bug fixes, and stability updates.';
    }

    final lines = body.split('\n');
    final changelogLines = <String>[];
    bool inWhatChanged = false;

    for (final rawLine in lines) {
      final line = rawLine.trim();

      if (line.startsWith('## What changed') ||
          line.startsWith('### What changed')) {
        inWhatChanged = true;
        continue;
      }

      if (line.startsWith('## Prism Music') ||
          line.startsWith('| Field |') ||
          line.startsWith('### Install') ||
          line.startsWith('**Full Changelog**')) {
        if (inWhatChanged && changelogLines.isNotEmpty) break;
      }

      if (inWhatChanged) {
        if (line.startsWith('### Added') ||
            line.startsWith('### Fixed') ||
            line.startsWith('### Changed') ||
            line.startsWith('### Removed')) {
          changelogLines.add('\n${line.replaceFirst('###', '✦').trim()}');
        } else if (line.startsWith('- ') || line.startsWith('* ')) {
          changelogLines.add(line);
        }
      }
    }

    if (changelogLines.isNotEmpty) {
      return changelogLines.join('\n').trim();
    }

    final bulletLines = lines
        .map((l) => l.trim())
        .where((l) => l.startsWith('- ') || l.startsWith('* '))
        .take(8)
        .toList();

    if (bulletLines.isNotEmpty) {
      return bulletLines.join('\n');
    }

    return 'Performance improvements, bug fixes, and stability updates.';
  }
}
