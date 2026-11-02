import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prism_music/core/services/offline_mode_service.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/presentation/blocs/player/player_event.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';

import '../helpers/fakes.dart';

class MockConnectivity extends Mock implements Connectivity {}
class MockSettingsService extends Mock implements SettingsService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockConnectivity mockConnectivity;
  late MockSettingsService mockSettings;
  late StreamController<List<ConnectivityResult>> connectivityController;
  late OfflineModeService offlineService;

  final onlineSong1 = Song(
    id: 'online_1',
    title: 'Online Stream Track 1',
    artist: 'Artist A',
    duration: const Duration(seconds: 200),
    thumbnails: const Thumbnails(),
    source: MusicSource.youtube,
  );

  final onlineSong2 = Song(
    id: 'online_2',
    title: 'Online Stream Track 2',
    artist: 'Artist B',
    duration: const Duration(seconds: 180),
    thumbnails: const Thumbnails(),
    source: MusicSource.youtube,
  );

  final downloadedSong = Song(
    id: 'downloaded_1',
    title: 'Cached Local Symphony',
    artist: 'Offline Artist',
    duration: const Duration(seconds: 210),
    thumbnails: const Thumbnails(),
    source: MusicSource.local,
  );

  setUp(() {
    mockConnectivity = MockConnectivity();
    mockSettings = MockSettingsService();
    connectivityController = StreamController<List<ConnectivityResult>>.broadcast();

    when(() => mockSettings.forceOfflineMode).thenReturn(false);
    when(() => mockSettings.setForceOfflineMode(any())).thenAnswer((_) async {});
    when(() => mockConnectivity.onConnectivityChanged)
        .thenAnswer((_) => connectivityController.stream);
    when(() => mockConnectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);

    offlineService = OfflineModeService(
      connectivity: mockConnectivity,
      settingsService: mockSettings,
    );
    OfflineModeService.setInstance(offlineService);
  });

  tearDown(() {
    connectivityController.close();
  });

  group('PlayerBloc offline fallback', () {
    test('when offline and requested song is not downloaded, falls back to downloaded song in queue', () async {
      await offlineService.initialize();
      await offlineService.setForceOffline(true);

      final fakeDownloads = FakeDownloadService(
        downloadedIds: {downloadedSong.playableId},
        downloadedSongs: [downloadedSong],
      );

      final playerBloc = buildTestPlayerBloc(downloadService: fakeDownloads);
      addTearDown(playerBloc.close);

      // User tries to play onlineSong1 from a queue containing [onlineSong1, downloadedSong]
      playerBloc.add(
        PlaySongEvent(
          song: onlineSong1,
          queue: [onlineSong1, downloadedSong],
          queueIndex: 0,
          userInitiated: true,
        ),
      );

      // Verify that the bloc falls back to downloadedSong
      await expectLater(
        playerBloc.stream,
        emitsThrough(
          predicate<PlayerState>((state) {
            return state.currentSong?.playableId == downloadedSong.playableId &&
                state.queueIndex == 1;
          }),
        ),
      );
    });

    test('when offline and no songs in queue are downloaded, falls back to device downloaded library', () async {
      await offlineService.initialize();
      await offlineService.setForceOffline(true);

      final fakeDownloads = FakeDownloadService(
        downloadedIds: {downloadedSong.playableId},
        downloadedSongs: [downloadedSong],
      );

      final playerBloc = buildTestPlayerBloc(downloadService: fakeDownloads);
      addTearDown(playerBloc.close);

      // Queue has only online songs
      playerBloc.add(
        PlaySongEvent(
          song: onlineSong1,
          queue: [onlineSong1, onlineSong2],
          queueIndex: 0,
          userInitiated: true,
        ),
      );

      await expectLater(
        playerBloc.stream,
        emitsThrough(
          predicate<PlayerState>((state) {
            return state.currentSong?.playableId == downloadedSong.playableId &&
                state.queue.contains(downloadedSong);
          }),
        ),
      );
    });

    test('when offline and zero downloaded songs exist, cleanly emits error state', () async {
      await offlineService.initialize();
      await offlineService.setForceOffline(true);

      final fakeDownloads = FakeDownloadService(
        downloadedIds: {},
        downloadedSongs: [],
      );

      final playerBloc = buildTestPlayerBloc(downloadService: fakeDownloads);
      addTearDown(playerBloc.close);

      playerBloc.add(
        PlaySongEvent(
          song: onlineSong1,
          queue: [onlineSong1],
          queueIndex: 0,
          userInitiated: true,
        ),
      );

      await expectLater(
        playerBloc.stream,
        emitsThrough(
          predicate<PlayerState>((state) {
            return state.status == PlayerStatus.error &&
                (state.errorMessage?.contains('Offline mode') ?? false);
          }),
        ),
      );
    });
  });
}

