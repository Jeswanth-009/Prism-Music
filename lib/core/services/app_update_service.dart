import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:device_info_plus/device_info_plus.dart';
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
  final String? apkSha256DownloadUrl;
  final String? desktopDownloadUrl;
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
    this.apkSha256DownloadUrl,
    this.desktopDownloadUrl,
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
      'https://api.github.com/repos/Jeswanth-009/Prism-Music/releases?per_page=5';
  static const String _fallbackApiUrl =
      'https://api.github.com/repos/Jeswanth-009/Prism-Music/releases/latest';
  static const Duration _timeout = Duration(seconds: 10);
  static const Duration _cacheDuration = Duration(minutes: 15);
  static const Duration _throttleDuration = Duration(hours: 2);
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

  /// Discovers the primary hardware ABI of the Android device (e.g. 'arm64-v8a', 'armeabi-v7a', 'x86_64').
  /// Returns 'universal' for non-Android platforms or if detection fails.
  Future<String> getDevicePrimaryAbi({DeviceInfoPlugin? deviceInfoOverride}) async {
    if (kIsWeb || !Platform.isAndroid) return 'universal';
    try {
      final plugin = deviceInfoOverride ?? DeviceInfoPlugin();
      final androidInfo = await plugin.androidInfo;
      final supportedAbis = androidInfo.supportedAbis;
      for (final abi in supportedAbis) {
        final lower = abi.toLowerCase();
        if (lower.contains('arm64')) return 'arm64-v8a';
        if (lower.contains('v7') || lower.contains('armeabi')) return 'armeabi-v7a';
        if (lower.contains('x86_64')) return 'x86_64';
      }
      return supportedAbis.isNotEmpty ? supportedAbis.first : 'universal';
    } catch (e) {
      logDebug('AppUpdateService: Error detecting device ABI: $e');
      return 'universal';
    }
  }

  /// Check for application updates.
  Future<AppUpdateInfo?> checkForUpdate({
    bool force = false,
    PackageInfo? overridePackageInfo,
    String? overrideDeviceAbi,
  }) async {
    // 1. In-memory and persistent throttle check.
    // If cached info already exists and was checked recently, return it immediately.
    // Notice: We only throttle if _cachedInfo is NOT null; on fresh process launch,
    // we always query GitHub to ensure the user gets real update status.
    if (!force) {
      if (_cachedInfo != null &&
          _lastCheckTime != null &&
          DateTime.now().difference(_lastCheckTime!) < _cacheDuration) {
        return _cachedInfo;
      }
      try {
        final lastCheck =
            SettingsService.instance.lastUpdateCheckTime ?? _lastCheckTime;
        if (_cachedInfo != null &&
            lastCheck != null &&
            DateTime.now().difference(lastCheck) < _throttleDuration) {
          logDebug('AppUpdateService: Reusing cached update info (throttled to $_throttleDuration)');
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

      http.Response? response;
      try {
        response = await _client.get(
          Uri.parse(_apiUrl),
          headers: const {
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'Prism-Music-App',
          },
        ).timeout(_timeout);
      } catch (netErr) {
        logError('AppUpdateService: Primary API request failed: $netErr');
      }

      // If primary multi-release endpoint returned non-200 and we're on default URL,
      // fallback to /releases/latest endpoint.
      if ((response == null || response.statusCode != 200) && _apiUrl == _defaultApiUrl) {
        try {
          response = await _client.get(
            Uri.parse(_fallbackApiUrl),
            headers: const {
              'Accept': 'application/vnd.github.v3+json',
              'User-Agent': 'Prism-Music-App',
            },
          ).timeout(_timeout);
        } catch (fbErr) {
          logError('AppUpdateService: Fallback API request failed: $fbErr');
        }
      }

      if (response == null || response.statusCode != 200) {
        logError(
          'AppUpdateService: GitHub API returned status ${response?.statusCode ?? "no response"}',
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
        latestRelease = decoded.firstWhere(
          (r) => r is Map<String, dynamic> && r['draft'] != true,
          orElse: () => decoded.first,
        ) as Map<String, dynamic>;
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

      // Discover device ABI on Android to choose the smallest APK slice (saving 55%+ bandwidth)
      final deviceAbi = overrideDeviceAbi ?? await getDevicePrimaryAbi();

      // Extract matching release APK asset for this device architecture
      final apkDownloadUrl = _extractApkDownloadUrl(assets, preferredAbi: deviceAbi);

      // Extract matching SHA-256 asset URL for APK integrity verification (SEC-13 / FIX-16)
      final apkSha256DownloadUrl =
          _extractSha256DownloadUrl(assets, apkDownloadUrl);

      // Extract desktop platform asset (.zip / .tar.gz) if applicable
      final desktopDownloadUrl = _extractDesktopDownloadUrl(assets);

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
        apkSha256DownloadUrl: apkSha256DownloadUrl,
        desktopDownloadUrl: desktopDownloadUrl,
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
        // SEC-13 / FIX-16: Checksum verification against authentic release hash
        if (info.apkSha256DownloadUrl != null) {
          try {
            final shaRes = await _client.get(
              Uri.parse(info.apkSha256DownloadUrl!),
              headers: const {'User-Agent': 'Prism-Music-App'},
            ).timeout(const Duration(seconds: 10));

            if (shaRes.statusCode == 200) {
              final expectedHash =
                  shaRes.body.trim().split(RegExp(r'\s+')).first.toLowerCase();
              final bytes = await file.readAsBytes();
              final actualHash =
                  crypto.sha256.convert(bytes).toString().toLowerCase();

              if (expectedHash.isNotEmpty && actualHash != expectedHash) {
                logError(
                  'AppUpdateService: Integrity check failed! Expected: $expectedHash, Actual: $actualHash',
                );
                await file.delete();
                downloadState.value = downloadState.value.copyWith(
                  status: UpdateStatus.failed,
                  errorMessage: 'Integrity check failed: checksum mismatch.',
                );
                return;
              }
              logDebug('AppUpdateService: APK integrity verified via SHA-256 ($actualHash)');
            }
          } catch (shaErr) {
            logError('AppUpdateService: Error verifying APK checksum', shaErr);
          }
        }

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

    if (build == 0) {
      // Parse +build or build number from body metadata: e.g. "Version: 1.0.8+141"
      final buildMatch = RegExp(
        r'(?:\+|versionCode[:\s]*|build[:\s]*|v\d+\.\d+\.\d+\+)(\d+)',
        caseSensitive: false,
      ).firstMatch(body);
      if (buildMatch != null && buildMatch.group(1) != null) {
        build = int.tryParse(buildMatch.group(1)!) ?? 0;
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

  String? _extractApkDownloadUrl(List assets, {String preferredAbi = 'universal'}) {
    String? arm64Apk;
    String? armv7Apk;
    String? x86_64Apk;
    String? universalApk;
    String? fallbackApk;

    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = (asset['name'] as String?)?.toLowerCase() ?? '';
      final url = asset['browser_download_url'] as String?;

      if (url == null || !name.endsWith('.apk')) continue;

      if (name.contains('arm64-v8a') || name.contains('arm64')) {
        arm64Apk ??= url;
      } else if (name.contains('armeabi-v7a') || name.contains('armv7') || name.contains('armeabi')) {
        armv7Apk ??= url;
      } else if (name.contains('x86_64') || name.contains('emulator')) {
        x86_64Apk ??= url;
      } else if (name.endsWith('-android.apk') ||
          name.contains('universal') ||
          name.contains('-phone-')) {
        universalApk ??= url;
      } else {
        fallbackApk ??= url;
      }
    }

    // Prioritize device's matching ABI slice to save 55%+ bandwidth (~19 MB arm64 vs 44 MB universal)
    if (preferredAbi == 'arm64-v8a' && arm64Apk != null) {
      return arm64Apk;
    }
    if (preferredAbi == 'armeabi-v7a' && armv7Apk != null) {
      return armv7Apk;
    }
    if (preferredAbi == 'x86_64' && x86_64Apk != null) {
      return x86_64Apk;
    }

    return universalApk ?? arm64Apk ?? armv7Apk ?? fallbackApk;
  }

  String? _extractSha256DownloadUrl(List assets, String? apkUrl) {
    if (apkUrl == null) return null;

    // 1. Locate the exact asset matching the chosen APK URL to get its authentic name
    String? matchedApkName;
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      if (asset['browser_download_url'] == apkUrl) {
        matchedApkName = (asset['name'] as String?)?.toLowerCase();
        break;
      }
    }

    final urlFileName = Uri.parse(apkUrl).pathSegments.last.toLowerCase();
    final expectedSha1 = matchedApkName != null ? '$matchedApkName.sha256' : null;
    final expectedSha2 = '$urlFileName.sha256';

    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = (asset['name'] as String?)?.toLowerCase() ?? '';
      final url = asset['browser_download_url'] as String?;
      if (url == null) continue;

      if ((expectedSha1 != null && name == expectedSha1) || name == expectedSha2) {
        return url;
      }
    }

    // Fallback if specific slice sha256 not found:
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = (asset['name'] as String?)?.toLowerCase() ?? '';
      final url = asset['browser_download_url'] as String?;
      if (url == null) continue;
      if (name.endsWith('.sha256') && name.contains('android.apk')) {
        return url;
      }
    }
    return null;
  }

  String? _extractDesktopDownloadUrl(List assets) {
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = (asset['name'] as String?)?.toLowerCase() ?? '';
      final url = asset['browser_download_url'] as String?;
      if (url == null) continue;

      if (name.endsWith('.zip') || name.contains('windows')) {
        return url;
      }
      if (name.endsWith('.tar.gz') || name.contains('linux')) {
        return url;
      }
    }
    return null;
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
