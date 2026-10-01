import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prism_music/core/di/injection.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/domain/repositories/music_repository.dart';
import 'package:prism_music/presentation/blocs/library/library_bloc.dart';
import 'package:prism_music/presentation/blocs/library/library_event.dart';
import 'package:prism_music/presentation/blocs/player/player_bloc.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';
import 'package:prism_music/presentation/pages/charts_hub_page.dart';
import 'package:prism_music/presentation/pages/liked_songs_page.dart';
import 'package:prism_music/presentation/widgets/player/mini_player.dart';
import 'package:prism_music/presentation/widgets/player/player_lyrics_sheet.dart';
import 'package:prism_music/presentation/widgets/prism/prism_song_tile.dart';

import '../helpers/fakes.dart';

/// Golden tests for the main surfaces across dark/light themes and common
/// phone sizes.
///
/// Regenerate after intentional UI changes with:
///   flutter test --update-goldens test/goldens
///
/// Determinism: GoogleFonts runtime fetching is disabled so text renders
/// with the bundled FlutterTest font identically on every platform, and
/// every fixture uses empty artwork (no network images).
const phoneSmall = Size(360, 800);
const phoneLarge = Size(412, 915);

Future<Lyrics> _syncedLyrics() async => Lyrics(
      songId: 'golden',
      source: 'LRCLIB',
      syncedLyrics: [
        for (var i = 0; i < 8; i++)
          LyricLine(
            startTimeMs: i * 4000,
            text: 'Golden lyric line ${i + 1}',
          ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() async {
    await getIt.reset();
    final musicRepo = FakeMusicRepository()
      ..lyricsResult = Right(await _syncedLyrics());
    getIt.registerSingleton<MusicRepository>(musicRepo);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pumpGolden(
    WidgetTester tester,
    Widget child, {
    required Brightness brightness,
    required Size size,
    required String goldenName,
    PlayerBloc? playerBloc,
    LibraryBloc? libraryBloc,
  }) async {
    await pumpTestWidget(
      tester,
      child,
      brightness: brightness,
      size: size,
      playerBloc: playerBloc,
      libraryBloc: libraryBloc,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$goldenName.png'),
    );
  }

  Song goldenSong() => song('g1', 'Golden Song', artist: 'Golden Artist');

  testWidgets('song tile, light, small', (tester) async {
    await pumpGolden(
      tester,
      PrismSongTile(song: goldenSong(), index: 3, numbered: true, onTap: () {}),
      brightness: Brightness.light,
      size: phoneSmall,
      goldenName: 'song_tile_light_small',
    );
  });

  testWidgets('song tile, dark, small', (tester) async {
    await pumpGolden(
      tester,
      PrismSongTile(song: goldenSong(), index: 3, numbered: true, onTap: () {}),
      brightness: Brightness.dark,
      size: phoneSmall,
      goldenName: 'song_tile_dark_small',
    );
  });

  testWidgets('song tile, light, large', (tester) async {
    await pumpGolden(
      tester,
      PrismSongTile(song: goldenSong(), index: 3, numbered: true, onTap: () {}),
      brightness: Brightness.light,
      size: phoneLarge,
      goldenName: 'song_tile_light_large',
    );
  });

  testWidgets('song tile, dark, large', (tester) async {
    await pumpGolden(
      tester,
      PrismSongTile(song: goldenSong(), index: 3, numbered: true, onTap: () {}),
      brightness: Brightness.dark,
      size: phoneLarge,
      goldenName: 'song_tile_dark_large',
    );
  });

  Widget miniPlayerFor(PlayerBloc bloc) {
    bloc.emit(const PlayerState(
      status: PlayerStatus.playing,
      currentSong: Song(
        id: 'g1',
        title: 'Golden Song',
        artist: 'Golden Artist',
        duration: Duration(seconds: 200),
        thumbnails: Thumbnails(),
      ),
      position: Duration(seconds: 40),
      duration: Duration(seconds: 200),
    ));
    return MiniPlayer();
  }

  testWidgets('mini player, light', (tester) async {
    final bloc = buildTestPlayerBloc();
    addTearDown(bloc.close);
    await pumpGolden(
      tester,
      miniPlayerFor(bloc),
      brightness: Brightness.light,
      size: phoneSmall,
      goldenName: 'mini_player_light',
      playerBloc: bloc,
    );
  });

  testWidgets('mini player, dark', (tester) async {
    final bloc = buildTestPlayerBloc();
    addTearDown(bloc.close);
    await pumpGolden(
      tester,
      miniPlayerFor(bloc),
      brightness: Brightness.dark,
      size: phoneSmall,
      goldenName: 'mini_player_dark',
      playerBloc: bloc,
    );
  });

  Widget lyricsFor() => const PlayerLyricsView(song: Song(
        id: 'g1',
        title: 'Golden Song',
        artist: 'Golden Artist',
        duration: Duration(seconds: 200),
        thumbnails: Thumbnails(),
      ));

  testWidgets('synced lyrics, light', (tester) async {
    final bloc = buildTestPlayerBloc();
    addTearDown(bloc.close);
    await pumpGolden(
      tester,
      lyricsFor(),
      brightness: Brightness.light,
      size: phoneSmall,
      goldenName: 'lyrics_light',
      playerBloc: bloc,
    );
  });

  testWidgets('synced lyrics, dark', (tester) async {
    final bloc = buildTestPlayerBloc();
    addTearDown(bloc.close);
    await pumpGolden(
      tester,
      lyricsFor(),
      brightness: Brightness.dark,
      size: phoneSmall,
      goldenName: 'lyrics_dark',
      playerBloc: bloc,
    );
  });

  testWidgets('liked songs page, light', (tester) async {
    final libraryBloc = LibraryBloc(
      libraryRepository: FakeLibraryRepository()
        ..likedSongs = [
          song('l1', 'First Like'),
          song('l2', 'Second Like'),
          song('l3', 'Third Like'),
        ],
      musicRepository: FakeMusicRepository(),
    );
    addTearDown(libraryBloc.close);
    libraryBloc.add(const LoadLibraryEvent());

    await pumpGolden(
      tester,
      const LikedSongsPage(),
      brightness: Brightness.light,
      size: phoneSmall,
      goldenName: 'liked_songs_light',
      libraryBloc: libraryBloc,
    );
  });

  testWidgets('liked songs page, dark', (tester) async {
    final libraryBloc = LibraryBloc(
      libraryRepository: FakeLibraryRepository()
        ..likedSongs = [
          song('l1', 'First Like'),
          song('l2', 'Second Like'),
          song('l3', 'Third Like'),
        ],
      musicRepository: FakeMusicRepository(),
    );
    addTearDown(libraryBloc.close);
    libraryBloc.add(const LoadLibraryEvent());

    await pumpGolden(
      tester,
      const LikedSongsPage(),
      brightness: Brightness.dark,
      size: phoneSmall,
      goldenName: 'liked_songs_dark',
      libraryBloc: libraryBloc,
    );
  });

  testWidgets('charts hub, light', (tester) async {
    await pumpGolden(
      tester,
      const ChartsHubPage(),
      brightness: Brightness.light,
      size: phoneSmall,
      goldenName: 'charts_hub_light',
    );
  });

  testWidgets('charts hub, dark', (tester) async {
    await pumpGolden(
      tester,
      const ChartsHubPage(),
      brightness: Brightness.dark,
      size: phoneSmall,
      goldenName: 'charts_hub_dark',
    );
  });
}
