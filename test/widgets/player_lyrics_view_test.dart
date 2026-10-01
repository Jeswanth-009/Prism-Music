import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/di/injection.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/domain/repositories/music_repository.dart';
import 'package:prism_music/presentation/widgets/player/player_lyrics_sheet.dart';

import '../helpers/fakes.dart';

Lyrics syncedLyrics(String marker) => Lyrics(
      songId: 'test',
      source: 'LRCLIB',
      syncedLyrics: [
        LyricLine(startTimeMs: 0, text: '$marker line one'),
        LyricLine(startTimeMs: 5000, text: '$marker line two'),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMusicRepository musicRepo;

  setUp(() async {
    await getIt.reset();
    musicRepo = FakeMusicRepository();
    getIt.registerSingleton<MusicRepository>(musicRepo);
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('renders synced lyrics with the LRCLIB attribution footer',
      (tester) async {
    musicRepo.lyricsResult = Right(syncedLyrics('First'));

    await pumpTestWidget(
      tester,
      const PlayerLyricsView(song: Song(
        id: 's1',
        title: 'Song One',
        artist: 'Artist',
        duration: Duration(seconds: 200),
        thumbnails: Thumbnails(),
      )),
      playerBloc: buildTestPlayerBloc(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('First line one'), findsOneWidget);
    expect(find.text('Lyrics provided by LRCLIB'), findsOneWidget);
  });

  testWidgets('not-found state offers a Retry that re-requests',
      (tester) async {
    await pumpTestWidget(
      tester,
      const PlayerLyricsView(song: Song(
        id: 's1',
        title: 'Song One',
        artist: 'Artist',
        duration: Duration(seconds: 200),
        thumbnails: Thumbnails(),
      )),
      playerBloc: buildTestPlayerBloc(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Lyrics not found'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    final callsBefore = musicRepo.getLyricsCallCount;

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(musicRepo.getLyricsCallCount, greaterThan(callsBefore));
  });

  testWidgets('passes a plausible song duration to the lookup',
      (tester) async {
    await pumpTestWidget(
      tester,
      const PlayerLyricsView(song: Song(
        id: 's1',
        title: 'Song One',
        artist: 'Artist',
        duration: Duration(seconds: 213),
        thumbnails: Thumbnails(),
      )),
      playerBloc: buildTestPlayerBloc(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(musicRepo.lastLyricsDurationSeconds, 213);
  });

  testWidgets('a stale response never replaces the new song lyrics',
      (tester) async {
    // The first lookup is held back long enough for the widget to swap
    // songs and complete the second lookup first.
    musicRepo.lyricsDelay = const Duration(milliseconds: 400);
    musicRepo.lyricsResult = Right(syncedLyrics('First'));

    const songA = Song(
      id: 'a',
      title: 'Song A',
      artist: 'Artist',
      duration: Duration(seconds: 200),
      thumbnails: Thumbnails(),
    );
    const songB = Song(
      id: 'b',
      title: 'Song B',
      artist: 'Artist',
      duration: Duration(seconds: 200),
      thumbnails: Thumbnails(),
    );

    await pumpTestWidget(
      tester,
      const PlayerLyricsView(song: songA),
      playerBloc: buildTestPlayerBloc(),
    );
    await tester.pump();

    // Swap to song B while A's lookup is still in flight; B resolves from
    // the same fake (now without delay) and must win.
    musicRepo.lyricsDelay = Duration.zero;
    await pumpTestWidget(
      tester,
      const PlayerLyricsView(song: songB),
      playerBloc: buildTestPlayerBloc(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('First line one'), findsOneWidget);

    // A's slow response lands now — it must be discarded.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('First line one'), findsOneWidget);
    expect(find.textContaining('Song A'), findsNothing);
  });
}
