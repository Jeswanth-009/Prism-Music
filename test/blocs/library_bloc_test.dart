import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/error/failures.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/presentation/blocs/library/library_bloc.dart';
import 'package:prism_music/presentation/blocs/library/library_event.dart';
import 'package:prism_music/presentation/blocs/library/library_state.dart';

import '../helpers/fakes.dart';

/// Poll until [condition] is true (bloc event chains complete
/// asynchronously — e.g. add-to-playlist triggers a full library reload).
Future<void> waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('waitFor condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLibraryRepository libraryRepo;
  late FakeMusicRepository musicRepo;
  late LibraryBloc bloc;

  setUp(() {
    libraryRepo = FakeLibraryRepository();
    musicRepo = FakeMusicRepository();
    bloc = LibraryBloc(
      libraryRepository: libraryRepo,
      musicRepository: musicRepo,
    );
  });

  tearDown(() => bloc.close());

  group('LoadLibraryEvent', () {
    test('aggregates liked songs, playlists, history, downloads and stats',
        () async {
      final liked = [song('l1', 'Liked Song')];
      final playlists = [playlist('p1', 'My Playlist')];
      final history = [song('h1', 'History Song')];
      final recent = [song('r1', 'Recent Song')];
      final downloads = [song('d1', 'Downloaded Song')];
      libraryRepo
        ..likedSongs = liked
        ..playlists = playlists
        ..history = history
        ..recentlyPlayed = recent
        ..downloads = downloads
        ..stats = const ListeningStats(totalPlays: 12, uniqueSongs: 5);

      bloc.add(const LoadLibraryEvent());
      await waitFor(() => bloc.state.status == LibraryStatus.success);

      expect(bloc.state.likedSongs, liked);
      expect(bloc.state.playlists, playlists);
      expect(bloc.state.history, history);
      expect(bloc.state.recentlyPlayed, recent);
      expect(bloc.state.downloads, downloads);
      expect(bloc.state.stats?.totalPlays, 12);
      expect(bloc.state.likedSongIds, {'l1'});
      expect(bloc.state.downloadedSongIds, {'d1'});
    });

    test('emits error when the library cannot be read', () async {
      libraryRepo.failLoad = true;

      bloc.add(const LoadLibraryEvent());
      await waitFor(() => bloc.state.status == LibraryStatus.error);

      expect(bloc.state.errorMessage, contains('load failed'));
    });
  });

  group('CreatePlaylistEvent / DeletePlaylistEvent', () {
    test('create prepends the new playlist to state', () async {
      libraryRepo.createPlaylistResult =
          Right(playlist('new_1', 'Road trip', description: 'summer'));

      bloc.add(const CreatePlaylistEvent(name: 'Road trip'));
      await waitFor(() => bloc.state.playlists.isNotEmpty);

      expect(libraryRepo.createdPlaylistNames, ['Road trip']);
      expect(bloc.state.playlists.single.id, 'new_1');
    });

    test('create failure emits error status', () async {
      libraryRepo.createPlaylistResult =
          const Left(UnknownFailure(message: 'disk full'));

      bloc.add(const CreatePlaylistEvent(name: 'Nope'));
      await waitFor(() => bloc.state.status == LibraryStatus.error);

      expect(bloc.state.errorMessage, contains('disk full'));
      expect(bloc.state.playlists, isEmpty);
    });

    test('delete removes the playlist from state', () async {
      libraryRepo.playlists = [playlist('p1', 'Keep'), playlist('p2', 'Gone')];
      bloc.add(const LoadLibraryEvent());
      await waitFor(() => bloc.state.status == LibraryStatus.success);

      bloc.add(const DeletePlaylistEvent('p2'));
      await waitFor(() => bloc.state.playlists.length == 1);

      expect(libraryRepo.deletedPlaylistIds, ['p2']);
      expect(bloc.state.playlists.single.name, 'Keep');
    });
  });

  group('AddToPlaylistEvent / RemoveFromPlaylistEvent', () {
    test('add records the song then reloads the library', () async {
      libraryRepo.playlists = [playlist('p1', 'Mine')];
      bloc.add(const LoadLibraryEvent());
      await waitFor(() => bloc.state.status == LibraryStatus.success);

      bloc.add(AddToPlaylistEvent(playlistId: 'p1', song: song('s1', 'Track')));
      await waitFor(
        () => libraryRepo.songsAddedByPlaylist['p1'] != null,
      );

      expect(libraryRepo.songsAddedByPlaylist['p1']!.single.id, 's1');
    });

    test('remove records playlist and song id', () async {
      bloc.add(const RemoveFromPlaylistEvent(playlistId: 'p1', songId: 's9'));
      await waitFor(() => libraryRepo.removedSongKeys.isNotEmpty);

      expect(libraryRepo.removedSongKeys.single, 'p1/s9');
    });
  });

  group('ImportSpotifyPlaylistEvent', () {
    test('persists the playlist with all songs and reports success',
        () async {
      final imported = playlist(
        'spotify_abc',
        'Comeback Comrade',
        songs: [song('t1', 'Maya'), song('t2', 'Track Two')],
        spotifyPlaylistId: 'abc',
      );
      musicRepo.importResult = Right(imported);
      libraryRepo.createPlaylistResult = Right(playlist('local_1', 'unused'));

      final done = Completer<String?>();
      bloc.add(ImportSpotifyPlaylistEvent(
        'https://open.spotify.com/playlist/abc',
        onDone: done.complete,
      ));
      final errorMessage = await done.future;

      expect(errorMessage, isNull);
      expect(libraryRepo.createdPlaylistNames, ['Comeback Comrade']);
      expect(libraryRepo.songsAddedByPlaylist['local_1'], hasLength(2));

      final saved = bloc.state.playlists.single;
      expect(saved.id, 'local_1');
      expect(saved.songs, hasLength(2));
      expect(saved.spotifyPlaylistId, 'abc');
      expect(bloc.state.status, LibraryStatus.success);
    });

    test('reports the failure message through onDone', () async {
      musicRepo.importResult =
          const Left(ParsingFailure(message: 'Could not read playlist'));

      final done = Completer<String?>();
      bloc.add(ImportSpotifyPlaylistEvent(
        'https://open.spotify.com/playlist/bad',
        onDone: done.complete,
      ));
      final errorMessage = await done.future;

      expect(errorMessage, contains('Could not read playlist'));
      expect(bloc.state.status, LibraryStatus.error);
      expect(bloc.state.playlists, isEmpty);
    });

    test('re-import refreshes the existing playlist in place', () async {
      final existing = playlist(
        'local_old',
        'Comeback Comrade',
        songs: [song('old_1', 'Old Track')],
        spotifyPlaylistId: 'abc',
      );
      libraryRepo.playlists = [existing];
      bloc.add(const LoadLibraryEvent());
      await waitFor(() => bloc.state.status == LibraryStatus.success);

      final refreshed = playlist(
        'spotify_abc',
        'Comeback Comrade',
        songs: [song('t1', 'Maya'), song('t2', 'Track Two')],
        spotifyPlaylistId: 'abc',
      );
      musicRepo.importResult = Right(refreshed);

      final done = Completer<String?>();
      bloc.add(ImportSpotifyPlaylistEvent('url', onDone: done.complete));
      await done.future;

      // Updated in place — no second playlist created.
      expect(libraryRepo.createdPlaylistNames, isEmpty);
      expect(libraryRepo.playlistSongsUpdated['local_old'], hasLength(2));
      expect(bloc.state.playlists, hasLength(1));
      expect(bloc.state.playlists.single.songs?.first.title, 'Maya');
    });

    test('emits import progress during matching', () async {
      musicRepo.importResult = Right(
        playlist('spotify_x', 'X', songs: [song('t1', 'T')], spotifyPlaylistId: 'x'),
      );
      libraryRepo.createPlaylistResult = Right(playlist('local_1', 'X'));

      final progress = <double>[];
      final done = Completer<String?>();
      late final StreamSubscription<LibraryState> sub;
      sub = bloc.stream.listen((s) {
        final value = s.importProgress;
        if (value != null && (progress.isEmpty || progress.last != value)) {
          progress.add(value);
        }
      });

      bloc.add(ImportSpotifyPlaylistEvent('url', onDone: done.complete));
      await done.future;
      await sub.cancel();

      expect(progress, containsAllInOrder([0.0, 0.5, 1.0]));
    });
  });

  group('ImportYouTubePlaylistEvent', () {
    test('persists and reports success', () async {
      musicRepo.importResult = Right(
        playlist(
          'PL123',
          'YT Playlist',
          songs: [song('y1', 'Video Song')],
          youtubePlaylistId: 'PL123',
        ),
      );
      libraryRepo.createPlaylistResult = Right(playlist('local_2', 'unused'));

      final done = Completer<String?>();
      bloc.add(ImportYouTubePlaylistEvent(
        'https://youtube.com/playlist?list=PL123',
        onDone: done.complete,
      ));
      final errorMessage = await done.future;

      expect(errorMessage, isNull);
      expect(musicRepo.lastImportUrl, contains('PL123'));
      expect(libraryRepo.songsAddedByPlaylist['local_2'], hasLength(1));
      expect(bloc.state.playlists.single.youtubePlaylistId, 'PL123');
    });
  });

  group('ToggleLikeSongEvent', () {
    test('likes an unliked song', () async {
      libraryRepo.likedSongs = [];
      bloc.add(const LoadLibraryEvent());
      await waitFor(() => bloc.state.status == LibraryStatus.success);

      bloc.add(ToggleLikeSongEvent(song('s1', 'New Like')));
      await waitFor(() => bloc.state.likedSongIds.contains('s1'));

      expect(libraryRepo.likedSaved.single.id, 's1');
    });

    test('unlikes a liked song', () async {
      libraryRepo.likedSongs = [song('s1', 'Already Liked')];
      bloc.add(const LoadLibraryEvent());
      await waitFor(() => bloc.state.status == LibraryStatus.success);

      bloc.add(ToggleLikeSongEvent(song('s1', 'Already Liked')));
      await waitFor(() => !bloc.state.likedSongIds.contains('s1'));

      expect(libraryRepo.unlikedIds, ['s1']);
      expect(bloc.state.likedSongs, isEmpty);
    });
  });

  group('DownloadSongEvent', () {
    test('resolves the stream then downloads the file', () async {
      musicRepo.streamUrlResult =
          Right(streamInfo('https://stream.example.com/audio'));

      bloc.add(DownloadSongEvent(song('d9', 'Offline Song')));
      await waitFor(() => bloc.state.downloadedSongIds.contains('d9'));

      expect(musicRepo.lastStreamUrlSongId, 'd9');
      expect(
        libraryRepo.downloadsSaved['d9'],
        'https://stream.example.com/audio',
      );
      expect(bloc.state.downloads.single.id, 'd9');
    });

    test('emits error when stream resolution fails', () async {
      musicRepo.streamUrlResult =
          const Left(UnknownFailure(message: 'no stream'));

      bloc.add(DownloadSongEvent(song('bad', 'Bad Song')));
      await waitFor(() => bloc.state.status == LibraryStatus.error);

      expect(bloc.state.errorMessage, contains('no stream'));
      expect(libraryRepo.downloadsSaved, isEmpty);
    });
  });
}
