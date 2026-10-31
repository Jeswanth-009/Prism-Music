import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prism_music/data/datasources/local/local_datasource.dart';
import 'package:prism_music/domain/entities/entities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalDataSourceImpl dataSource;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('history_test');
    Hive.init(tempDir.path);
    dataSource = LocalDataSourceImpl();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  Song createSong(String id, String title) {
    return Song(
      id: id,
      title: title,
      artist: 'Test Artist',
      duration: const Duration(minutes: 3),
      thumbnails: const Thumbnails(),
      source: MusicSource.youtube,
      youtubeId: id,
    );
  }

  test('addToHistory deduplicates consecutive plays within 15 seconds', () async {
    final s1 = createSong('song_1', 'Song One');

    await dataSource.addToHistory(s1);
    final history1 = await dataSource.getListeningHistory();
    expect(history1.length, 1);

    // Immediate second add of same song
    await dataSource.addToHistory(s1);
    final history2 = await dataSource.getListeningHistory();
    expect(history2.length, 1);
  });

  test('addToHistory prunes entries beyond 90 days retention window', () async {
    final box = await Hive.openBox('listening_history');
    final oldTime = DateTime.now().subtract(const Duration(days: 95)).millisecondsSinceEpoch;
    await box.put('${oldTime}_old_song', {
      'id': 'old_song',
      'title': 'Old Track',
      'artist': 'Artist',
      'durationMs': 180000,
      'source': 0,
      'sourceName': 'youtube',
    });

    expect(box.length, 1);

    final newSong = createSong('new_song', 'New Track');
    await dataSource.addToHistory(newSong);

    // Old track older than 90 days should have been pruned
    expect(box.containsKey('${oldTime}_old_song'), isFalse);
    final history = await dataSource.getListeningHistory();
    expect(history.length, 1);
    expect(history.first.id, 'new_song');
  });
}
