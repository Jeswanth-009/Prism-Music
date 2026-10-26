import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/logger.dart';

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

/// Service for checking app updates against GitHub Releases.
///
/// Executes with a strict timeout (4 seconds) so app startup is never delayed,
/// caches recent results, and parses clean changelog release notes.
class AppUpdateService {
  static const String _defaultApiUrl =
      'https://api.github.com/repos/Jeswanth-009/Prism-Music/releases?per_page=1';
  static const Duration _timeout = Duration(seconds: 4);
  static const Duration _cacheDuration = Duration(minutes: 15);

  final http.Client _client;
  final String _apiUrl;

  AppUpdateInfo? _cachedInfo;
  DateTime? _lastCheckTime;
  String? _dismissedVersion;

  static AppUpdateService? _instance;
  static AppUpdateService get instance => _instance ??= AppUpdateService();

  AppUpdateService({
    http.Client? client,
    String apiUrl = _defaultApiUrl,
  })  : _client = client ?? http.Client(),
        _apiUrl = apiUrl;

  /// Mark a version as dismissed for the active app session.
  void dismissVersion(String version) {
    _dismissedVersion = version;
  }

  /// Whether the user previously chose 'Later' for this version.
  bool isDismissed(String version) => _dismissedVersion == version;

  /// Check for application updates.
  ///
  /// Returns [AppUpdateInfo] if an update check was performed or served from cache.
  /// Returns null if network error, timeout, or invalid response occurs.
  Future<AppUpdateInfo?> checkForUpdate({
    bool force = false,
    PackageInfo? overridePackageInfo,
  }) async {
    // 1. Check in-memory cache if not forced
    if (!force &&
        _cachedInfo != null &&
        _lastCheckTime != null &&
        DateTime.now().difference(_lastCheckTime!) < _cacheDuration) {
      return _cachedInfo;
    }

    try {
      final packageInfo = overridePackageInfo ?? await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version.trim();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber.trim()) ?? 0;

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
      if (decoded is! List || decoded.isEmpty) {
        logDebug('AppUpdateService: No releases returned by GitHub');
        return null;
      }

      final latestRelease = decoded.first as Map<String, dynamic>;
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

      return updateInfo;
    } catch (e, stack) {
      logError('AppUpdateService: Error checking for update', e, stack);
      return null;
    }
  }

  /// Parses (version, buildNumber) from tag name and release body.
  ///
  /// Examples:
  /// - `alpha-v0.2.54-build90` -> ("0.2.54", 90)
  /// - `v0.2.54+90` -> ("0.2.54", 90)
  /// - `0.2.54` -> ("0.2.54", 0)
  (String, int) _parseVersionFromTag(String tag, String body) {
    // 1. Try parsing from tag name: alpha-v0.2.54-build90 or v0.2.54+90
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

    // 2. If build number wasn't found in tag, look for versionCode in release body
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

  /// Determines whether the latest release is newer than the current app installation.
  bool _isUpdateAvailable({
    required String currentVersion,
    required int currentBuild,
    required String latestVersion,
    required int latestBuild,
  }) {
    // Higher build number is primary truth on Android
    if (latestBuild > 0 && currentBuild > 0) {
      if (latestBuild > currentBuild) return true;
      if (latestBuild < currentBuild) return false;
    }

    // Semver comparison fallback
    return _compareSemver(latestVersion, currentVersion) > 0;
  }

  /// Compares two semver strings (e.g., "0.2.54" vs "0.2.53").
  /// Returns 1 if v1 > v2, -1 if v1 < v2, and 0 if equal.
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

  /// Resolves the phone APK browser download URL from GitHub release assets.
  String? _extractApkDownloadUrl(List assets) {
    String? fallbackApk;

    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = (asset['name'] as String?)?.toLowerCase() ?? '';
      final url = asset['browser_download_url'] as String?;

      if (url == null) continue;

      // Prefer phone APK (non-emulator)
      if (name.endsWith('.apk') && !name.contains('emulator')) {
        return url;
      }

      if (name.endsWith('.apk') && fallbackApk == null) {
        fallbackApk = url;
      }
    }

    return fallbackApk;
  }

  /// Extracts readable, human-facing changelog lines from the GitHub release markdown body.
  String _cleanChangelog(String body) {
    if (body.trim().isEmpty) {
      return 'Performance improvements, bug fixes, and stability updates.';
    }

    final lines = body.split('\n');
    final changelogLines = <String>[];
    bool inWhatChanged = false;

    for (final rawLine in lines) {
      final line = rawLine.trim();

      if (line.startsWith('## What changed') || line.startsWith('### What changed')) {
        inWhatChanged = true;
        continue;
      }

      // Stop at release summary table or installation guide
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

    // Fallback: extract any bullet items in the entire body
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
