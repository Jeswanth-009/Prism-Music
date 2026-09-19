import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:dart_ytmusic_api/types.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prism_music/core/error/failures.dart';
import 'package:prism_music/core/mappers/ytmusic_api_mappers.dart';
import 'package:prism_music/core/services/audio_focus_orchestrator_service.dart';
import 'package:prism_music/core/services/audio_player_service.dart';
import 'package:prism_music/core/services/download_service.dart';
import 'package:prism_music/core/services/media_resolver_service.dart';
import 'package:prism_music/core/services/playback_reliability_service.dart';
import 'package:prism_music/core/services/recommendation_service.dart';
import 'package:prism_music/core/services/stream_loader_service.dart';
import 'package:prism_music/core/services/ytmusic_api_service.dart';
import 'package:prism_music/data/datasources/local/local_datasource.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/domain/repositories/repositories.dart';
import 'package:prism_music/presentation/blocs/player/player_bloc.dart';
import 'package:prism_music/presentation/blocs/player/player_event.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';
import 'package:prism_music/presentation/blocs/search/search_bloc.dart';
import 'package:prism_music/presentation/blocs/search/search_event.dart';
import 'package:prism_music/presentation/blocs/search/search_state.dart';

class FakeMusicRepo implements MusicRepository {
  int searchSongsCallCount = 0;
  String? lastSearchQuery;

  @override
  Future<Either<Failure, List<Song>>> searchSongs(
    String query, {
    int limit = 20,
    String? filter,
  }) async {
    searchSongsCallCount++;
    lastSearchQuery = query;
    return Right([
      Song(
        id: 's_$query',
        title: 'Song for $query',
        artist: 'Artist',
        duration: const Duration(seconds: 200),
        thumbnails: const Thumbnails(),
      ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLocalDataSource implements LocalDataSource {
  @override
  Future<void> addSearchHistory(String query) async {}

  @override
  Future<List<Map<String, String>>> getSearchHistory({int limit = 20}) async => [];

  @override
  Future<void> clearSearchHistory() async {}

  @override
  Future<void> removeSearchHistory(String id) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAudioPlayerService implements AudioPlayerService {
  final _posCtrl = StreamController<Duration>.broadcast();
  final _bufCtrl = StreamController<Duration>.broadcast();
  final _durCtrl = StreamController<Duration?>.broadcast();
  final _playCtrl = StreamController<bool>.broadcast();
  final _bufferingCtrl = StreamController<bool>.broadcast();
  final _compCtrl = StreamController<bool>.broadcast();
  final _errCtrl = StreamController<String>.broadcast();
  final _idxCtrl = StreamController<int?>.broadcast();

  @override
  Stream<Duration> get positionStream => _posCtrl.stream;
  @override
  Stream<Duration> get bufferedPositionStream => _bufCtrl.stream;
  @override
  Stream<Duration?> get durationStream => _durCtrl.stream;
  @override
  Stream<bool> get playingStream => _playCtrl.stream;
  @override
  Stream<bool> get bufferingStream => _bufferingCtrl.stream;
  @override
  Stream<bool> get completedStream => _compCtrl.stream;
  @override
  Stream<String> get errorStream => _errCtrl.stream;
  @override
  Stream<int?> get currentIndexStream => _idxCtrl.stream;

  @override
  bool get playing => false;
  @override
  bool get isQueueMode => false;

  @override
  Future<Duration?> setUrl(
    String url, {
    Map<String, String>? headers,
    String? videoId,
    String quality = 'high',
    String? title,
    String? artist,
    String? album,
    String? artworkUrl,
    Duration? mediaDuration,
    bool allowYouTubeFallbackOnDirectFailure = false,
  }) async {
    return const Duration(seconds: 180);
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> stop() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAudioFocusOrchestrator implements AudioFocusOrchestratorService {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> activateForPlayback() async => true;

  @override
  Future<void> deactivate() async {}

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockMediaResolver implements MediaResolverService {
  @override
  Future<ResolvedMediaSource> resolveForPlayback(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    return ResolvedMediaSource(
      uri: 'https://stream.example.com/${song.id}',
      isOffline: false,
      videoId: song.id,
    );
  }

  @override
  ResolvedMediaSource? takePreResolved(String songId) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLibraryRepository implements LibraryRepository {
  @override
  Future<Either<Failure, void>> addToHistory(Song song) async => const Right(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStreamLoaderService implements StreamLoaderService {
  @override
  void prefetch(Song song, {AudioQuality preferredQuality = AudioQuality.high}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRecommendationService implements RecommendationService {
  Song? lastCurrentSong;
  int getRecommendationsCount = 0;

  @override
  Future<List<Song>> getRecommendations({
    Song? currentSong,
    int limit = 10,
  }) async {
    getRecommendationsCount++;
    lastCurrentSong = currentSong;
    return [
      const Song(
        id: 'rec_1',
        title: 'Recommended Song 1',
        artist: 'Similar Artist',
        duration: Duration(seconds: 180),
        thumbnails: Thumbnails(),
      ),
      const Song(
        id: 'rec_2',
        title: 'Recommended Song 2',
        artist: 'Similar Artist 2',
        duration: Duration(seconds: 210),
        thumbnails: Thumbnails(),
      ),
    ];
  }

  @override
  Future<void> recordPlay(Song song) async {}

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDownloadService implements DownloadService {
  @override
  bool isDownloaded(String songId) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init('./test_hive_flow');
  });

  group('Search & Recommendation Flow Tests', () {
    test('SearchBloc debounces rapid keystrokes and searches only final query', () async {
      final fakeRepo = FakeMusicRepo();
      final searchBloc = SearchBloc(
        musicRepository: fakeRepo,
        localDataSource: FakeLocalDataSource(),
      );

      // Rapidly emit keystrokes (simulating fast typing)
      searchBloc.add(const SearchQueryEvent(query: 'fa', filter: SearchFilter.songs));
      searchBloc.add(const SearchQueryEvent(query: 'fad', filter: SearchFilter.songs));
      searchBloc.add(const SearchQueryEvent(query: 'fade', filter: SearchFilter.songs));
      searchBloc.add(const SearchQueryEvent(query: 'faded', filter: SearchFilter.songs));

      // Wait for debounce (300ms) + small execution buffer
      await Future.delayed(const Duration(milliseconds: 500));

      expect(searchBloc.state.status, SearchStatus.success);
      expect(searchBloc.state.query, 'faded');
      expect(fakeRepo.lastSearchQuery, 'faded');
      expect(fakeRepo.searchSongsCallCount, 1);

      await searchBloc.close();
    });

    test('SearchBloc resets to initial and cleans query on empty or short input', () async {
      final fakeRepo = FakeMusicRepo();
      final searchBloc = SearchBloc(
        musicRepository: fakeRepo,
        localDataSource: FakeLocalDataSource(),
      );

      searchBloc.add(const SearchQueryEvent(query: 'faded', filter: SearchFilter.songs));
      await Future.delayed(const Duration(milliseconds: 400));
      expect(searchBloc.state.status, SearchStatus.success);

      // User clears field
      searchBloc.add(const SearchQueryEvent(query: '', filter: SearchFilter.songs));
      await Future.delayed(const Duration(milliseconds: 400));

      expect(searchBloc.state.status, SearchStatus.initial);
      expect(searchBloc.state.results.songs, isEmpty);

      await searchBloc.close();
    });

    test('PlayerBloc seeds queue and immediately appends recommendations when playing single song from search', () async {
      final fakeRepo = FakeMusicRepo();
      final fakeRecService = FakeRecommendationService();

      final playerBloc = PlayerBloc(
        musicRepository: fakeRepo,
        libraryRepository: FakeLibraryRepository(),
        audioPlayerService: MockAudioPlayerService(),
        audioFocus: MockAudioFocusOrchestrator(),
        mediaResolver: MockMediaResolver(),
        reliability: PlaybackReliabilityService(),
        streamLoader: FakeStreamLoaderService(),
        downloadService: FakeDownloadService(),
        recommendationService: fakeRecService,
      );

      const searchedSong = Song(
        id: 'seed_faded',
        title: 'Faded',
        artist: 'Alan Walker',
        duration: Duration(seconds: 212),
        thumbnails: Thumbnails(),
        source: MusicSource.youtubeMusic,
        youtubeId: 'seed_faded',
      );

      // Tapping a song in search now passes queue: [searchedSong], queueIndex: 0
      playerBloc.add(
        const PlaySongEvent(
          song: searchedSong,
          queue: [searchedSong],
          queueIndex: 0,
        ),
      );

      // Wait for immediate recommendation top-up to emit updated queue
      await expectLater(
        playerBloc.stream,
        emitsThrough(
          predicate<PlayerState>((state) {
            return state.queue.length == 3 &&
                state.queue.first.id == 'seed_faded' &&
                state.queue[1].id == 'rec_1' &&
                state.queue[2].id == 'rec_2';
          }),
        ),
      );

      expect(fakeRecService.getRecommendationsCount, greaterThanOrEqualTo(1));
      expect(fakeRecService.lastCurrentSong?.id, 'seed_faded');

      await playerBloc.close();
    });

    test('UpNextsDetails converts into valid Map and Song entity', () {
      final upNextItem = UpNextsDetails(
        type: 'SONG',
        videoId: 'vid123',
        title: 'Alone',
        artists: ArtistBasic(artistId: 'art123', name: 'Alan Walker'),
        album: AlbumBasic(albumId: 'alb123', name: 'Alone Album'),
        duration: 180,
        thumbnails: [
          ThumbnailFull(url: 'https://img.youtube.com/vi/vid123/0.jpg', width: 120, height: 120),
        ],
      );

      final ytService = YtMusicApiService();
      // Test dynamic mapper through runtime
      final map = {
        'type': 'song',
        'videoId': upNextItem.videoId,
        'id': upNextItem.videoId,
        'title': upNextItem.title,
        'name': upNextItem.title,
        'artist': upNextItem.artists.name,
        'artists': [
          {'artistId': upNextItem.artists.artistId, 'name': upNextItem.artists.name}
        ],
        'album': {'albumId': upNextItem.album!.albumId, 'name': upNextItem.album!.name},
        'durationSeconds': upNextItem.duration,
        'duration': upNextItem.duration,
        'thumbnails': upNextItem.thumbnails.map((t) => {'url': t.url}).toList(),
      };

      final song = songFromYtMusicApi(map);
      expect(song.id, 'vid123');
      expect(song.title, 'Alone');
      expect(song.artist, 'Alan Walker');
      expect(song.album, 'Alone Album');
      expect(song.playableId, 'vid123');
      expect(song.duration.inSeconds, 180);
      expect(song.thumbnailUrl, 'https://img.youtube.com/vi/vid123/0.jpg');
    });
  });
}
