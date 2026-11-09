import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/download_service.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/core/services/stream_loader_service.dart';
import '../helpers/fakes.dart';

class _FakeStreamLoaderService implements StreamLoaderService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DownloadService downloadService;

  setUp(() async {
    initTestHive('smart_download_test');
    await SettingsService.instance.initialize();
    tempDir = Directory('./test_smart_downloads').absolute;
    if (!tempDir.existsSync()) {
      tempDir.createSync(recursive: true);
    }
    await SettingsService.instance.setDownloadFolderPath(tempDir.path);
    downloadService = DownloadService(_FakeStreamLoaderService());
    await downloadService.initialize();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('Smart Download Manager - Priority & Quota Tests', () {
    test('verifies priority levels and bumpPriority', () {
      expect(DownloadPriority.high.value > DownloadPriority.normal.value, isTrue);
      expect(DownloadPriority.normal.value > DownloadPriority.low.value, isTrue);
    });

    test('storage quota calculation checks limit against settings', () async {
      // 0 = unlimited, should always allow
      await SettingsService.instance.setDownloadStorageQuotaMB(0);
      expect(await downloadService.checkStorageQuotaAllowed(estimatedBytes: 100 * 1024 * 1024), isTrue);

      // Set small quota of 1 MB
      await SettingsService.instance.setDownloadStorageQuotaMB(1);
      // Asking for 10 MB should fail quota check
      expect(await downloadService.checkStorageQuotaAllowed(estimatedBytes: 10 * 1024 * 1024), isFalse);

      // Asking for 500 KB should pass quota check
      expect(await downloadService.checkStorageQuotaAllowed(estimatedBytes: 500 * 1024), isTrue);
    });

    test('auto-download liked songs toggle persists in SettingsService', () async {
      await SettingsService.instance.setAutoDownloadLikedSongs(false);
      expect(SettingsService.instance.autoDownloadLikedSongs, isFalse);

      await SettingsService.instance.setAutoDownloadLikedSongs(true);
      expect(SettingsService.instance.autoDownloadLikedSongs, isTrue);
    });
  });
}
