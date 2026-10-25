import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prism_music/core/services/queue_persistence_service.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/domain/entities/entities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('queue_persistence_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await SettingsService.instance.initialize();
    await QueuePersistenceService.instance.clearSession();
    await SettingsService.instance.setRestoreQueueOnLaunch(true);
    await SettingsService.instance.setExcludeIncognitoQueue(true);
  });

  const song1 = Song(
    id: 's1',
    title: 'Starman',
    artist: 'David Bowie',
    duration: Duration(seconds: 250),
    thumbnails: Thumbnails(),
  );

  const song2 = Song(
    id: 's2',
    title: 'Space Oddity',
    artist: 'David Bowie',
    duration: Duration(seconds: 310),
    thumbnails: Thumbnails(),
  );

  test('saves and retrieves queue session correctly', () async {
    final service = QueuePersistenceService.instance;

    await service.saveSession(
      currentSong: song1,
      queue: [song1, song2],
      queueIndex: 0,
      position: const Duration(seconds: 42),
    );

    final session = await service.getSavedSession();
    expect(session, isNotNull);
    expect(session!.currentSong.id, 's1');
    expect(session.currentSong.title, 'Starman');
    expect(session.queue.length, 2);
    expect(session.queueIndex, 0);
    expect(session.position.inSeconds, 42);
  });

  test('clears session when requested', () async {
    final service = QueuePersistenceService.instance;

    await service.saveSession(
      currentSong: song1,
      queue: [song1, song2],
      queueIndex: 0,
      position: const Duration(seconds: 10),
    );

    await service.clearSession();

    final session = await service.getSavedSession();
    expect(session, isNull);
  });

  test('respects explicit privacy control: does not persist if restoreQueueOnLaunch is false', () async {
    final service = QueuePersistenceService.instance;

    await SettingsService.instance.setRestoreQueueOnLaunch(false);

    await service.saveSession(
      currentSong: song1,
      queue: [song1],
      queueIndex: 0,
      position: const Duration(seconds: 15),
    );

    final session = await service.getSavedSession();
    expect(session, isNull);
  });

  test('respects incognito privacy: excludes incognito queue when setting is enabled', () async {
    final service = QueuePersistenceService.instance;

    await SettingsService.instance.setExcludeIncognitoQueue(true);

    await service.saveSession(
      currentSong: song1,
      queue: [song1],
      queueIndex: 0,
      position: const Duration(seconds: 20),
      isIncognito: true,
    );

    final session = await service.getSavedSession();
    expect(session, isNull);
  });
}
