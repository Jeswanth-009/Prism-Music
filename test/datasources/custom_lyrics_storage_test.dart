import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prism_music/data/datasources/remote/lyrics/custom_lyrics_storage.dart';

void main() {
  late Directory tempDir;
  final storage = CustomLyricsStorage.instance;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('prism_lyrics_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  tearDown(() async {
    final box = await Hive.openBox<Map>(CustomLyricsStorage.boxName);
    await box.clear();
  });

  group('CustomLyricsStorage', () {
    test('saves plain custom lyrics and retrieves them with "User Edited" source', () async {
      const songId = 'song_1';
      const title = 'Shape of You';
      const artist = 'Ed Sheeran';
      const plain = "The club isn't the best place to find a lover\nSo the bar is where I go";

      expect(await storage.hasCustomLyrics(songId, title, artist), isFalse);

      await storage.saveCustomLyrics(
        songId,
        title,
        artist,
        plainLyrics: plain,
      );

      expect(await storage.hasCustomLyrics(songId, title, artist), isTrue);

      final retrieved = await storage.getCustomLyrics(title, artist, songId);
      expect(retrieved, isNotNull);
      expect(retrieved!.source, equals('User Edited'));
      expect(retrieved.plainLyrics, equals(plain));
      expect(retrieved.isSynced, isFalse);
    });

    test('saves LRC synced lyrics and correctly parses timestamps', () async {
      const songId = 'song_2';
      const title = 'Believer';
      const artist = 'Imagine Dragons';
      const lrc = '[00:10.50]First things first\n[00:15.20]I\'ma say all the words inside my head';

      await storage.saveCustomLyrics(
        songId,
        title,
        artist,
        syncedLrc: lrc,
      );

      final retrieved = await storage.getCustomLyrics(title, artist, songId);
      expect(retrieved, isNotNull);
      expect(retrieved!.source, equals('User Edited'));
      expect(retrieved.isSynced, isTrue);
      expect(retrieved.syncedLyrics!.length, equals(2));
      expect(retrieved.syncedLyrics![0].text, equals('First things first'));
      expect(retrieved.syncedLyrics![0].startTimeMs, equals(10500));
    });

    test('clearing custom lyrics removes override', () async {
      const songId = 'song_3';
      const title = 'Counting Stars';
      const artist = 'OneRepublic';

      await storage.saveCustomLyrics(
        songId,
        title,
        artist,
        plainLyrics: 'Lately I been, I been losing sleep',
      );
      expect(await storage.hasCustomLyrics(songId, title, artist), isTrue);

      await storage.clearCustomLyrics(songId, title, artist);
      expect(await storage.hasCustomLyrics(songId, title, artist), isFalse);
      expect(await storage.getCustomLyrics(title, artist, songId), isNull);
    });
  });
}
