import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prism_music/core/services/download_service.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/core/services/stream_loader_service.dart';
import 'package:prism_music/core/utils/path_safety.dart';

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
    initTestHive('download_bundler_test');
    await SettingsService.instance.initialize();
    tempDir = Directory('./test_downloads_bundler').absolute;
    if (!tempDir.existsSync()) {
      tempDir.createSync(recursive: true);
    }

    await SettingsService.instance.setDownloadFolderPath(tempDir.path);
    DownloadPathGuard.resetForTesting();
    downloadService = DownloadService(_FakeStreamLoaderService());
    await downloadService.initialize();
  });

  tearDown(() async {
    DownloadPathGuard.resetForTesting();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('DownloadService 3-in-1 Offline Bundler', () {
    test('retrieves local artwork path and lyrics path correctly from metadata', () async {
      final audioFile = File('${tempDir.path}/test_song.m4a')..writeAsStringSync('dummy audio');
      final artFile = File('${tempDir.path}/test_song_artwork.jpg')..writeAsStringSync('dummy artwork');
      final lrcFile = File('${tempDir.path}/test_song_lyrics.lrc')..writeAsStringSync('[00:01.00]Hello world');

      final box = Hive.box('downloads');
      await box.put('test_song', {
        'id': 'test_song',
        'title': 'Test Song',
        'artist': 'Test Artist',
        'localPath': audioFile.path,
        'localArtworkPath': artFile.path,
        'localLyricsPath': lrcFile.path,
        'quality': 'Ultra (320 kbps)',
        'fileSize': 1024,
      });

      expect(downloadService.getLocalArtworkPath('test_song'), equals(artFile.path));
      expect(downloadService.getLocalLyricsPath('test_song'), equals(lrcFile.path));

      final lyrics = await downloadService.getLocalLyrics('test_song');
      expect(lyrics, contains('[00:01.00]Hello world'));
    });

    test('deleteSong removes audio, artwork, and lyrics files together', () async {
      final audioFile = File('${tempDir.path}/del_song.m4a')..writeAsStringSync('audio data');
      final artFile = File('${tempDir.path}/del_song_artwork.jpg')..writeAsStringSync('artwork data');
      final lrcFile = File('${tempDir.path}/del_song_lyrics.lrc')..writeAsStringSync('lyrics data');

      final box = Hive.box('downloads');
      await box.put('del_song', {
        'id': 'del_song',
        'title': 'Del Song',
        'artist': 'Artist',
        'localPath': audioFile.path,
        'localArtworkPath': artFile.path,
        'localLyricsPath': lrcFile.path,
        'fileSize': 1024,
      });

      expect(audioFile.existsSync(), isTrue);
      expect(artFile.existsSync(), isTrue);
      expect(lrcFile.existsSync(), isTrue);

      final success = await downloadService.deleteSong('del_song');
      expect(success, isTrue);

      expect(audioFile.existsSync(), isFalse);
      expect(artFile.existsSync(), isFalse);
      expect(lrcFile.existsSync(), isFalse);
    });
  });
}
