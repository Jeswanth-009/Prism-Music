import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/di/injection.dart';
import 'package:prism_music/core/mappers/ytmusic_api_mappers.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/domain/repositories/music_repository.dart';
import 'package:prism_music/presentation/blocs/player/player_bloc.dart';
import 'package:prism_music/presentation/pages/album_page.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Album mapping & routing (F10)', () {
    test('albumFromYtMusicApi maps album details and tracks correctly', () {
      final rawAlbum = {
        'type': 'album',
        'browseId': 'MPREb_album123',
        'playlistId': 'OLAK5uy_play123',
        'title': 'Test Album Title',
        'artist': 'Test Artist Name',
        'year': 2024,
        'thumbnails': [
          {'url': 'https://example.com/thumb.jpg', 'width': 500, 'height': 500}
        ],
        'tracks': [
          {
            'videoId': 'track-1',
            'title': 'First Track',
            'artist': 'Test Artist Name',
            'durationSeconds': 210,
          },
          {
            'videoId': 'track-2',
            'title': 'Second Track',
            'artist': 'Test Artist Name',
            'durationSeconds': 185,
          },
        ],
      };

      final album = albumFromYtMusicApi(rawAlbum);

      expect(album.id, 'MPREb_album123');
      expect(album.title, 'Test Album Title');
      expect(album.artist, 'Test Artist Name');
      expect(album.year, 2024);
      expect(album.youtubePlaylistId, 'OLAK5uy_play123');
      expect(album.songs, isNotNull);
      expect(album.songs!.length, 2);
      expect(album.songs![0].id, 'track-1');
      expect(album.songs![0].title, 'First Track');
      expect(album.songs![1].id, 'track-2');
      expect(album.songs![1].title, 'Second Track');
    });

    group('AlbumPage widget', () {
      late FakeMusicRepository musicRepo;
      late PlayerBloc playerBloc;

      setUp(() async {
        await getIt.reset();
        musicRepo = FakeMusicRepository();
        getIt.registerSingleton<MusicRepository>(musicRepo);
        playerBloc = buildTestPlayerBloc();
      });

      tearDown(() async {
        playerBloc.close();
        await getIt.reset();
      });

      testWidgets('fetches album details using browse ID when songs are not loaded',
          (tester) async {
        musicRepo.albumResult = Right(
          Album(
            id: 'MPREb_xyz',
            title: 'Resolved Title',
            artist: 'Resolved Artist',
            thumbnails: const Thumbnails(),
            songs: [
              song('s1', 'Track One', artist: 'Resolved Artist'),
              song('s2', 'Track Two', artist: 'Resolved Artist'),
            ],
          ),
        );

        final initialAlbum = const Album(
          id: 'MPREb_xyz',
          title: 'Initial Title',
          artist: 'Initial Artist',
          thumbnails: Thumbnails(),
        );

        await tester.pumpWidget(wrapForTests(
          AlbumPage(album: initialAlbum),
          playerBloc: playerBloc,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(musicRepo.lastAlbumIdRequested, 'MPREb_xyz');
        expect(find.text('Track One'), findsOneWidget);
        expect(find.text('Track Two'), findsOneWidget);
      });

      testWidgets('falls back to youtubePlaylistId when album id is empty',
          (tester) async {
        musicRepo.albumResult = Right(
          Album(
            id: 'OLAK5uy_fallback',
            title: 'Playlist Title',
            artist: 'Artist',
            thumbnails: const Thumbnails(),
            songs: [
              song('s1', 'Playlist Track', artist: 'Artist'),
            ],
          ),
        );

        final initialAlbum = const Album(
          id: '',
          title: 'Initial Title',
          artist: 'Initial Artist',
          thumbnails: Thumbnails(),
          youtubePlaylistId: 'OLAK5uy_fallback',
        );

        await tester.pumpWidget(wrapForTests(
          AlbumPage(album: initialAlbum),
          playerBloc: playerBloc,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(musicRepo.lastAlbumIdRequested, 'OLAK5uy_fallback');
        expect(find.text('Playlist Track'), findsOneWidget);
      });
    });
  });
}
