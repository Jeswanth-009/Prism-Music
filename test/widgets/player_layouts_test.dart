import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/di/injection.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/domain/repositories/music_repository.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';
import 'package:prism_music/presentation/widgets/player/layouts/full_bleed_player_layout.dart';
import 'package:prism_music/presentation/widgets/player/layouts/glass_player_layout.dart';
import 'package:prism_music/presentation/widgets/player/layouts/karaoke_player_layout.dart';
import 'package:prism_music/presentation/widgets/player/layouts/studio_player_layout.dart';
import 'package:prism_music/presentation/widgets/player/waveform_scrubber.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMusicRepository musicRepo;

  setUpAll(() async {
    initTestHive('player_layouts_test');
    await SettingsService.instance.initialize();
  });

  setUp(() async {
    await getIt.reset();
    musicRepo = FakeMusicRepository();
    getIt.registerSingleton<MusicRepository>(musicRepo);
  });

  tearDown(() async {
    await getIt.reset();
  });

  const testSong = Song(
    id: 'layout_test_01',
    title: 'Prism Horizons',
    artist: 'Deep Space Sound',
    album: 'Quantum Nebula',
    duration: Duration(seconds: 210),
    thumbnails: Thumbnails(),
  );

  const testState = PlayerState(
    status: PlayerStatus.playing,
    currentSong: testSong,
    position: Duration(seconds: 30),
    duration: Duration(seconds: 210),
  );

  testWidgets('Glass Player layout renders frosted card and waveform scrubber', (tester) async {
    final playerBloc = buildTestPlayerBloc();
    addTearDown(playerBloc.close);

    await pumpTestWidget(
      tester,
      GlassPlayerLayout(
        song: testSong,
        state: testState,
        showLyrics: false,
        onToggleLyrics: () {},
        onArtistTap: (_) {},
        onProvenanceTap: () {},
      ),
      playerBloc: playerBloc,
    );
    await tester.pump();

    expect(find.byType(GlassPlayerLayout), findsOneWidget);
    expect(find.text('Prism Horizons'), findsWidgets);
    expect(find.byType(WaveformScrubber), findsOneWidget);
  });

  testWidgets('Full Bleed Player layout renders edge-to-edge layout', (tester) async {
    final playerBloc = buildTestPlayerBloc();
    addTearDown(playerBloc.close);

    await pumpTestWidget(
      tester,
      FullBleedPlayerLayout(
        song: testSong,
        state: testState,
        showLyrics: false,
        onToggleLyrics: () {},
        onArtistTap: (_) {},
        onProvenanceTap: () {},
      ),
      playerBloc: playerBloc,
    );
    await tester.pump();

    expect(find.byType(FullBleedPlayerLayout), findsOneWidget);
    expect(find.text('Prism Horizons'), findsWidgets);
    expect(find.byType(WaveformScrubber), findsOneWidget);
  });

  testWidgets('Studio Player layout renders studio diagnostic pill and spectrum visualizer', (tester) async {
    final playerBloc = buildTestPlayerBloc();
    addTearDown(playerBloc.close);

    await pumpTestWidget(
      tester,
      StudioPlayerLayout(
        song: testSong,
        state: testState,
        showLyrics: false,
        onToggleLyrics: () {},
        onArtistTap: (_) {},
        onProvenanceTap: () {},
      ),
      playerBloc: playerBloc,
    );
    await tester.pump();

    expect(find.byType(StudioPlayerLayout), findsOneWidget);
    expect(find.textContaining('STUDIO MASTER'), findsOneWidget);
    expect(find.text('Prism Horizons'), findsWidgets);
    expect(find.byType(WaveformScrubber), findsOneWidget);
  });

  testWidgets('Karaoke Player layout renders Sing Karaoke header and controls', (tester) async {
    final playerBloc = buildTestPlayerBloc();
    addTearDown(playerBloc.close);

    await pumpTestWidget(
      tester,
      KaraokePlayerLayout(
        song: testSong,
        state: testState,
        lyricsText: '[00:10.00]Hello world',
        onExitKaraoke: () {},
      ),
      playerBloc: playerBloc,
    );
    await tester.pump();

    expect(find.byType(KaraokePlayerLayout), findsOneWidget);
    expect(find.text('SING KARAOKE'), findsOneWidget);
    expect(find.text('Prism Horizons'), findsWidgets);
  });
}
