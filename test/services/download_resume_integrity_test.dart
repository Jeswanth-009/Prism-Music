import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/download_service.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/core/services/stream_loader_service.dart';
import 'package:prism_music/domain/entities/entities.dart';

import '../helpers/fakes.dart';

class _FakeStreamLoaderService implements StreamLoaderService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DownloadService downloadService;
  late Directory tempDir;

  setUp(() async {
    initTestHive('download_resume_integrity_test');
    await SettingsService.instance.initialize();
    tempDir = Directory('./test_downloads_resume').absolute;
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

  group('Download Integrity & Multi-Key Matching', () {
    test('verifyDownloadIntegrity validates matching SHA-256 and detects corrupted files', () async {
      // Create a valid audio file with ID3 magic bytes and padding to exceed min size (16KB)
      final dummyAudio = Uint8List(20 * 1024);
      dummyAudio[0] = 0x49; // 'I'
      dummyAudio[1] = 0x44; // 'D'
      dummyAudio[2] = 0x33; // '3'
      for (int i = 3; i < dummyAudio.length; i++) {
        dummyAudio[i] = i % 256;
      }

      final testFile = File('${tempDir.path}/test_song.m4a');
      await testFile.writeAsBytes(dummyAudio);

      final checksum = sha256.convert(dummyAudio).toString();

      // Put record in downloadBox via Hive
      final song = Song(
        id: 'spot_123',
        title: 'Integrity Test Track',
        artist: 'Artist',
        duration: const Duration(seconds: 180),
        thumbnails: Thumbnails.empty(),
        isrc: 'USRC12345678',
      );

      final box = downloadService.downloadBox;
      await box?.put(song.playableId, {
        'songId': song.playableId,
        'id': song.id,
        'isrc': song.isrc,
        'title': song.title,
        'artist': song.artist,
        'localPath': testFile.path,
        'fileSize': dummyAudio.length,
        'checksum': checksum,
      });

      // Rebuild index
      await downloadService.initialize();

      // Verification succeeds with matching checksum
      final isValid = await downloadService.verifyDownloadIntegrity(song.playableId);
      expect(isValid, isTrue);

      // Multi-key matching: verify song is recognized via ISRC
      expect(downloadService.isDownloaded('USRC12345678'), isTrue);
      expect(downloadService.isSongDownloaded(song), isTrue);

      // Now tamper with the file bytes
      dummyAudio[100] = (dummyAudio[100] + 1) % 256;
      await testFile.writeAsBytes(dummyAudio);

      // Integrity verification fails due to checksum mismatch
      final isTamperedValid = await downloadService.verifyDownloadIntegrity(song.playableId);
      expect(isTamperedValid, isFalse);

      // Verify async download listing off the UI thread
      final asyncDownloads = await downloadService.getAllDownloadedSongsAsync();
      expect(asyncDownloads.length, equals(1));
      expect(asyncDownloads.first['songId'], equals(song.playableId));
    });
  });
}
