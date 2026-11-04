import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/presentation/blocs/library/library_bloc.dart';
import 'package:prism_music/presentation/blocs/library/library_event.dart';
import 'package:prism_music/presentation/blocs/library/library_state.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImportAppleMusicPlaylistEvent Bloc Test', () {
    late FakeMusicRepository musicRepo;
    late FakeLibraryRepository libraryRepo;
    late LibraryBloc bloc;

    setUp(() {
      musicRepo = FakeMusicRepository();
      libraryRepo = FakeLibraryRepository();
      bloc = LibraryBloc(
        musicRepository: musicRepo,
        libraryRepository: libraryRepo,
      );
    });

    tearDown(() {
      bloc.close();
    });

    test('imports Apple Music playlist and emits progress and success', () async {
      const appleUrl = 'https://music.apple.com/us/playlist/todays-hits/pl.f4d1060b525243e6a05420188a71bf1b';
      final track = Song(
        id: 'am_1',
        title: 'Espresso',
        artist: 'Sabrina Carpenter',
        duration: const Duration(seconds: 175),
        thumbnails: const Thumbnails(),
        isrc: 'USUM72403305',
      );

      final playlist = Playlist(
        id: 'apple_music_pl.f4d1060b525243e6a05420188a71bf1b',
        name: "Today's Hits",
        trackCount: 1,
        songs: [track],
        appleMusicPlaylistId: 'pl.f4d1060b525243e6a05420188a71bf1b',
      );

      musicRepo.importSpotifyResult = Right(
        ImportPlaylistResult(
          playlist: playlist,
          matchedTracks: [track],
          unmatchedTracks: const [],
          totalSourceTracks: 1,
        ),
      );

      ImportPlaylistResult? receivedResult;
      String? errorMessage;

      bloc.add(
        ImportAppleMusicPlaylistEvent(
          appleUrl,
          onResult: (res) => receivedResult = res,
          onDone: (err) => errorMessage = err,
        ),
      );

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<LibraryState>((state) =>
              state.status == LibraryStatus.success &&
              state.playlists.any((p) => p.appleMusicPlaylistId == 'pl.f4d1060b525243e6a05420188a71bf1b')),
        ),
      );

      expect(errorMessage, isNull);
      expect(receivedResult, isNotNull);
      expect(receivedResult!.matchedTracks.first.title, 'Espresso');
    });
  });
}
