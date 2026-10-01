import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:dart_ytmusic_api/types.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prism_music/core/mappers/ytmusic_api_mappers.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/presentation/blocs/player/player_event.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';
import 'package:prism_music/presentation/blocs/search/search_bloc.dart';
import 'package:prism_music/presentation/blocs/search/search_event.dart';
import 'package:prism_music/presentation/blocs/search/search_state.dart';

import 'helpers/fakes.dart';

/// End-to-end search → play flow tests. Uses the canonical fakes from
/// helpers/fakes.dart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    initTestHive('flow');
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  group('Search & Recommendation Flow Tests', () {
    test('SearchBloc debounces rapid keystrokes and searches only final query',
        () async {
      final fakeRepo = FakeMusicRepository()
        ..searchResult = Right([song('s_faded', 'Faded')]);
      final searchBloc = SearchBloc(
        musicRepository: fakeRepo,
        localDataSource: FakeLocalDataSource(),
      );

      // Rapidly emit keystrokes (simulating fast typing)
      searchBloc
        ..add(const SearchQueryEvent(query: 'fa', filter: SearchFilter.songs))
        ..add(const SearchQueryEvent(query: 'fad', filter: SearchFilter.songs))
        ..add(const SearchQueryEvent(query: 'fade', filter: SearchFilter.songs))
        ..add(const SearchQueryEvent(query: 'faded', filter: SearchFilter.songs));

      // Wait for debounce (300ms) + small execution buffer
      await Future.delayed(const Duration(milliseconds: 500));

      expect(searchBloc.state.status, SearchStatus.success);
      expect(searchBloc.state.query, 'faded');
      expect(fakeRepo.lastSearchQuery, 'faded');
      expect(fakeRepo.searchSongsCallCount, 1);

      await searchBloc.close();
    });

    test(
        'SearchBloc resets to initial and cleans query on empty or short input',
        () async {
      final fakeRepo = FakeMusicRepository()
        ..searchResult = Right([song('s_faded', 'Faded')]);
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

    test(
        'PlayerBloc seeds queue and immediately appends recommendations when playing single song from search',
        () async {
      final fakeRecService = FakeRecommendationService();
      final playerBloc = buildTestPlayerBloc(
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
