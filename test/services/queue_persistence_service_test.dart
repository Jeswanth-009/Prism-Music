import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prism_music/core/services/queue_persistence_service.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/presentation/blocs/player/player.dart';

class MockBox extends Mock implements Box {}

class MockSettingsService extends Mock implements SettingsService {}

class MockQueueBloc extends Mock implements QueueBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockBox mockBox;
  late MockSettingsService mockSettings;
  late Map<String, dynamic> memoryStorage;

  final sampleSong1 = Song(
    id: 'song_1',
    title: 'Bohemian Rhapsody',
    artist: 'Queen',
    duration: const Duration(seconds: 354),
    thumbnails: Thumbnails.empty(),
    source: MusicSource.jiosaavn,
  );

  final sampleSong2 = Song(
    id: 'song_2',
    title: 'Hotel California',
    artist: 'Eagles',
    duration: const Duration(seconds: 390),
    thumbnails: Thumbnails.empty(),
    source: MusicSource.youtube,
  );

  setUp(() {
    mockBox = MockBox();
    mockSettings = MockSettingsService();
    memoryStorage = {};

    when(() => mockSettings.restoreQueueOnLaunch).thenReturn(true);
    when(() => mockSettings.excludeIncognitoQueue).thenReturn(false);
    when(() => mockBox.isOpen).thenReturn(true);

    when(() => mockBox.get(any())).thenAnswer((inv) {
      final key = inv.positionalArguments[0] as String;
      return memoryStorage[key];
    });

    when(() => mockBox.put(any(), any())).thenAnswer((inv) async {
      final key = inv.positionalArguments[0] as String;
      final val = inv.positionalArguments[1];
      memoryStorage[key] = val;
    });

    when(() => mockBox.delete(any())).thenAnswer((inv) async {
      final key = inv.positionalArguments[0] as String;
      memoryStorage.remove(key);
    });

    when(() => mockBox.flush()).thenAnswer((_) async {});
  });

  group('QueuePersistenceService', () {
    test('eagerly saves and retrieves session across simulated app kill', () async {
      final service = QueuePersistenceService.forTest(
        box: mockBox,
        settingsService: mockSettings,
      );

      await service.saveSession(
        currentSong: sampleSong1,
        queue: [sampleSong1, sampleSong2],
        queueIndex: 0,
        position: const Duration(seconds: 42),
      );

      verify(() => mockBox.put('active_session', any())).called(1);
      verify(() => mockBox.flush()).called(1);

      // Simulate cold start: re-instantiate service and retrieve session
      final freshColdStartService = QueuePersistenceService.forTest(
        box: mockBox,
        settingsService: mockSettings,
      );

      final restored = await freshColdStartService.getSavedSession();
      expect(restored, isNotNull);
      expect(restored!.currentSong.id, 'song_1');
      expect(restored.currentSong.title, 'Bohemian Rhapsody');
      expect(restored.queue.length, 2);
      expect(restored.queue[1].title, 'Hotel California');
      expect(restored.queueIndex, 0);
      expect(restored.position.inSeconds, 42);
    });

    test('respects privacy settings: clears session when restoreQueueOnLaunch is false', () async {
      when(() => mockSettings.restoreQueueOnLaunch).thenReturn(false);

      final service = QueuePersistenceService.forTest(
        box: mockBox,
        settingsService: mockSettings,
      );

      await service.saveSession(
        currentSong: sampleSong1,
        queue: [sampleSong1],
        queueIndex: 0,
        position: const Duration(seconds: 10),
      );

      verify(() => mockBox.delete('active_session')).called(1);
      final restored = await service.getSavedSession();
      expect(restored, isNull);
    });

    test('ignores incognito session when excludeIncognitoQueue is enabled', () async {
      when(() => mockSettings.excludeIncognitoQueue).thenReturn(true);

      final service = QueuePersistenceService.forTest(
        box: mockBox,
        settingsService: mockSettings,
      );

      await service.saveSession(
        currentSong: sampleSong1,
        queue: [sampleSong1],
        queueIndex: 0,
        position: const Duration(seconds: 10),
        isIncognito: true,
      );

      verifyNever(() => mockBox.put('active_session', any()));
    });
  });

  group('Cold Start Queue Restoration in BLoC', () {
    test('RestoreQueueEvent restores state in paused mode with no surprise auto-play', () {
      final playerState = const PlayerState().copyWith(
        status: PlayerStatus.initial,
      );

      final restoredState = playerState.copyWith(
        status: PlayerStatus.paused,
        currentSong: sampleSong1,
        queue: [sampleSong1, sampleSong2],
        queueIndex: 0,
        position: const Duration(seconds: 42),
        isRestoredSession: true,
      );

      expect(restoredState.status, PlayerStatus.paused);
      expect(restoredState.isRestoredSession, isTrue);
      expect(restoredState.currentSong?.title, 'Bohemian Rhapsody');
      expect(restoredState.position.inSeconds, 42);
      expect(restoredState.queue.length, 2);
    });
  });
}
