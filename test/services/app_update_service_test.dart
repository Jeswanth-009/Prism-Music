import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:prism_music/core/services/app_update_service.dart';

void main() {
  group('AppUpdateService Tests', () {
    const sampleReleaseJson = '''
[
  {
    "tag_name": "alpha-v0.2.55-build91",
    "name": "Prism Music alpha-v0.2.55-build91",
    "html_url": "https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.55-build91",
    "body": "## What changed\\n\\n### Added\\n- Instant recommendations after playing search results\\n- Fast automatic update check dialog\\n\\n### Fixed\\n- Stale queue concurrency bug\\n\\n## Prism Music — Automated Alpha Release\\n| Field | Value |\\n|---|---|\\n| **versionCode** | 91 |",
    "assets": [
      {
        "name": "prism-music-alpha-v0.2.55-build91-android-emulator-x86_64.apk",
        "browser_download_url": "https://github.com/download/emulator.apk"
      },
      {
        "name": "prism-music-alpha-v0.2.55-build91-android.apk",
        "browser_download_url": "https://github.com/download/phone.apk"
      }
    ]
  }
]
''';

    test('detects newer version when latest build number is greater', () async {
      final mockClient = MockClient((request) async {
        return http.Response(sampleReleaseJson, 200, headers: {
          'content-type': 'application/json',
        });
      });

      final service = AppUpdateService(
        client: mockClient,
        apiUrl: 'https://api.github.com/test/releases',
      );

      final currentPkg = PackageInfo(
        appName: 'Prism Music',
        packageName: 'com.prism.music',
        version: '0.2.54',
        buildNumber: '90',
      );

      final info = await service.checkForUpdate(
        force: true,
        overridePackageInfo: currentPkg,
      );

      expect(info, isNotNull);
      expect(info!.hasUpdate, isTrue);
      expect(info.latestVersion, '0.2.55');
      expect(info.latestBuildNumber, 91);
      expect(info.currentVersion, '0.2.54');
      expect(info.currentBuildNumber, 90);
      expect(info.apkDownloadUrl, 'https://github.com/download/phone.apk');
      expect(info.changelog, contains('Instant recommendations'));
      expect(info.changelog, contains('Stale queue concurrency bug'));
      // Verifies CI table was stripped
      expect(info.changelog, isNot(contains('| Field |')));
    });

    test('reports hasUpdate = false when already on latest version and build', () async {
      final mockClient = MockClient((request) async {
        return http.Response(sampleReleaseJson, 200, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      });

      final service = AppUpdateService(
        client: mockClient,
        apiUrl: 'https://api.github.com/test/releases',
      );

      final currentPkg = PackageInfo(
        appName: 'Prism Music',
        packageName: 'com.prism.music',
        version: '0.2.55',
        buildNumber: '91',
      );

      final info = await service.checkForUpdate(
        force: true,
        overridePackageInfo: currentPkg,
      );

      expect(info, isNotNull);
      expect(info!.hasUpdate, isFalse);
    });

    test('caches check results in memory and skips network on repeat call', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response(sampleReleaseJson, 200, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      });

      final service = AppUpdateService(
        client: mockClient,
        apiUrl: 'https://api.github.com/test/releases',
      );

      final currentPkg = PackageInfo(
        appName: 'Prism Music',
        packageName: 'com.prism.music',
        version: '0.2.54',
        buildNumber: '90',
      );

      final info1 = await service.checkForUpdate(
        force: false,
        overridePackageInfo: currentPkg,
      );
      final info2 = await service.checkForUpdate(
        force: false,
        overridePackageInfo: currentPkg,
      );

      expect(requestCount, 1);
      expect(identical(info1, info2), isTrue);
    });

    test('returns null gracefully on HTTP error status code', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final service = AppUpdateService(
        client: mockClient,
        apiUrl: 'https://api.github.com/test/releases',
      );

      final currentPkg = PackageInfo(
        appName: 'Prism Music',
        packageName: 'com.prism.music',
        version: '0.2.54',
        buildNumber: '90',
      );

      final info = await service.checkForUpdate(
        force: true,
        overridePackageInfo: currentPkg,
      );

      expect(info, isNull);
    });

    test('dismissVersion marks version as dismissed', () {
      final service = AppUpdateService();
      expect(service.isDismissed('0.2.55'), isFalse);
      service.dismissVersion('0.2.55');
      expect(service.isDismissed('0.2.55'), isTrue);
    });
  });
}
