import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prism_music/core/services/download_service.dart';
import 'package:prism_music/core/services/offline_mode_service.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/domain/repositories/repositories.dart';
import 'package:prism_music/data/datasources/local/local_datasource.dart';
import 'package:prism_music/presentation/blocs/search/search.dart';

class MockConnectivity extends Mock implements Connectivity {}

class MockSettingsService extends Mock implements SettingsService {}

class MockMusicRepository extends Mock implements MusicRepository {}

class MockLocalDataSource extends Mock implements LocalDataSource {}

class MockDownloadService extends Mock implements DownloadService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockConnectivity mockConnectivity;
  late MockSettingsService mockSettings;
  late StreamController<List<ConnectivityResult>> connectivityController;

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
  });

  tearDown(() {
    connectivityController.close();
  });

  group('OfflineModeService', () {
    test('initializes as online when wifi is connected', () async {
      final service = OfflineModeService(
        connectivity: mockConnectivity,
        settingsService: mockSettings,
      );

      await service.initialize();
      expect(service.isOffline, isFalse);
      expect(service.isManualOffline, isFalse);
    });

    test('initializes as offline when connectivity is none', () async {
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]);

      final service = OfflineModeService(
        connectivity: mockConnectivity,
        settingsService: mockSettings,
      );

      await service.initialize();
      expect(service.isOffline, isTrue);
    });

    test('emits onSwitchedToOffline when connectivity changes to none', () async {
      final service = OfflineModeService(
        connectivity: mockConnectivity,
        settingsService: mockSettings,
      );

      await service.initialize();
      expect(service.isOffline, isFalse);

      bool switchedFired = false;
      final sub = service.onSwitchedToOffline.listen((_) {
        switchedFired = true;
      });

      connectivityController.add([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);

      expect(service.isOffline, isTrue);
      expect(switchedFired, isTrue);
      await sub.cancel();
    });

    test('manual offline mode forces offline state regardless of network', () async {
      final service = OfflineModeService(
        connectivity: mockConnectivity,
        settingsService: mockSettings,
      );

      await service.initialize();
      expect(service.isOffline, isFalse);

      await service.setForceOffline(true);
      expect(service.isOffline, isTrue);
      expect(service.isManualOffline, isTrue);
      verify(() => mockSettings.setForceOfflineMode(true)).called(1);

      await service.setForceOffline(false);
      expect(service.isOffline, isFalse);
      expect(service.isManualOffline, isFalse);
      verify(() => mockSettings.setForceOfflineMode(false)).called(1);
    });
  });

  group('DownloadService search & mapping', () {
    test('maps raw download dictionary to typed Song entity', () {
      final song = DownloadService.mapDownloadToSong({
        'songId': 'dl_123',
        'title': 'Offline Symphony',
        'artist': 'Local Artist',
        'duration': 180,
        'localPath': '/path/to/dl_123.m4a',
      });

      expect(song.id, 'dl_123');
      expect(song.title, 'Offline Symphony');
      expect(song.artist, 'Local Artist');
      expect(song.duration, const Duration(seconds: 180));
      expect(song.streamUrl, '/path/to/dl_123.m4a');
      expect(song.source, MusicSource.local);
    });
  });

  group('SearchBloc offline behavior', () {
    late MockMusicRepository mockMusicRepo;
    late MockLocalDataSource mockLocalData;
    late MockDownloadService mockDownload;
    late OfflineModeService offlineService;

    setUp(() {
      mockMusicRepo = MockMusicRepository();
      mockLocalData = MockLocalDataSource();
      mockDownload = MockDownloadService();

      offlineService = OfflineModeService(
        connectivity: mockConnectivity,
        settingsService: mockSettings,
      );

      when(() => mockLocalData.getSearchHistory())
          .thenAnswer((_) async => []);
      when(() => mockLocalData.addSearchHistory(any()))
          .thenAnswer((_) async {});
    });

    test('queries downloads directly when offline mode is active', () async {
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]);
      await offlineService.initialize();

      final offlineTrack = Song(
        id: 'off_1',
        title: 'Despacito Offline',
        artist: 'Luis Fonsi',
        duration: const Duration(seconds: 200),
        thumbnails: Thumbnails.empty(),
        source: MusicSource.local,
      );

      when(() => mockDownload.searchDownloadedSongs('Despacito'))
          .thenReturn([offlineTrack]);

      final searchBloc = SearchBloc(
        musicRepository: mockMusicRepo,
        localDataSource: mockLocalData,
        downloadService: mockDownload,
        offlineModeService: offlineService,
      );

      searchBloc.add(const SearchQueryEvent(query: 'Despacito'));

      await expectLater(
        searchBloc.stream,
        emitsThrough(predicate<SearchState>((state) {
          return state.status == SearchStatus.success &&
              state.isOfflineResults == true &&
              state.results.songs.length == 1 &&
              state.results.songs.first.id == 'off_1';
        })),
      );

      verifyNever(() => mockMusicRepo.searchSongs(any(), limit: any(named: 'limit')));
      verify(() => mockDownload.searchDownloadedSongs('Despacito')).called(1);

      await searchBloc.close();
    });
  });
}
