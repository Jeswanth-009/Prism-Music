import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/di/injection.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/domain/repositories/music_repository.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';
import 'package:prism_music/presentation/pages/player_page.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMusicRepository musicRepo;

  setUp(() async {
    await getIt.reset();
    musicRepo = FakeMusicRepository();
    getIt.registerSingleton<MusicRepository>(musicRepo);

    initTestHive('vinyl_player_test');
    await SettingsService.instance.initialize();
    await SettingsService.instance.setPlayerUiStyle(PlayerUiStyle.vinyl);
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('Vinyl Player layout renders vinyl disc, transport controls, and song info',
      (tester) async {
    final playerBloc = buildTestPlayerBloc();
    addTearDown(playerBloc.close);

    const testSong = Song(
      id: 'vinyl_01',
      title: 'Analog Grooves',
      artist: 'Retro Horizon',
      album: 'Turntable Sessions',
      duration: Duration(seconds: 240),
      thumbnails: Thumbnails(),
    );

    playerBloc.emit(const PlayerState(
      status: PlayerStatus.playing,
      currentSong: testSong,
      position: Duration(seconds: 45),
    ));

    await pumpTestWidget(
      tester,
      const PlayerPage(),
      playerBloc: playerBloc,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Analog Grooves'), findsOneWidget);
    expect(find.text('Retro Horizon'), findsOneWidget);
    expect(find.text('Turntable Sessions'), findsOneWidget);

    // Verify RotationTransition and transport controls
    expect(find.byType(RotationTransition), findsWidgets);
    expect(find.byType(AudiophileTonearm), findsOneWidget);
    expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
    expect(find.byIcon(Icons.lyrics_outlined), findsOneWidget);
    expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);

    // Initial playing state should have tonearm at groove angle (0.22)
    final tonearm = tester.widget<AudiophileTonearm>(find.byType(AudiophileTonearm));
    expect(tonearm.angle, closeTo(0.22, 0.01));

    // Tap lyrics button to toggle lyrics view
    await tester.tap(find.byIcon(Icons.lyrics_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('lyrics_vinyl_01')), findsOneWidget);
  });

  testWidgets('Tonearm moves to side rest when paused and returns to groove when resumed',
      (tester) async {
    final playerBloc = buildTestPlayerBloc();
    addTearDown(playerBloc.close);

    const testSong = Song(
      id: 'vinyl_02',
      title: 'Groove Needle',
      artist: 'Retro Horizon',
      album: 'Turntable Sessions',
      duration: Duration(seconds: 200),
      thumbnails: Thumbnails(),
    );

    // Start in playing state
    playerBloc.emit(const PlayerState(
      status: PlayerStatus.playing,
      currentSong: testSong,
    ));

    await pumpTestWidget(
      tester,
      const PlayerPage(),
      playerBloc: playerBloc,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // When playing, tonearm is on vinyl grooves (0.22 rad)
    var tonearm = tester.widget<AudiophileTonearm>(find.byType(AudiophileTonearm));
    expect(tonearm.angle, closeTo(0.22, 0.01));

    // Pause playback
    playerBloc.emit(const PlayerState(
      status: PlayerStatus.paused,
      currentSong: testSong,
    ));
    await tester.pump();
    await tester.pump();
    // Allow the 700ms animation to complete
    await tester.pump(const Duration(milliseconds: 750));

    // Tonearm must now be at rest position on the side cradle (-0.42 rad)
    tonearm = tester.widget<AudiophileTonearm>(find.byType(AudiophileTonearm));
    expect(tonearm.angle, closeTo(-0.42, 0.01));

    // Resume playback
    playerBloc.emit(const PlayerState(
      status: PlayerStatus.playing,
      currentSong: testSong,
    ));
    await tester.pump();
    await tester.pump();
    // Allow the 700ms animation to complete
    await tester.pump(const Duration(milliseconds: 750));

    // Tonearm must have swung back inward onto the vinyl grooves (0.22 rad)
    tonearm = tester.widget<AudiophileTonearm>(find.byType(AudiophileTonearm));
    expect(tonearm.angle, closeTo(0.22, 0.01));
  });

  testWidgets('Tonearm starts at rest position when player opens in paused state',
      (tester) async {
    final playerBloc = buildTestPlayerBloc();
    addTearDown(playerBloc.close);

    const testSong = Song(
      id: 'vinyl_03',
      title: 'Dormant Deck',
      artist: 'Retro Horizon',
      album: 'Turntable Sessions',
      duration: Duration(seconds: 180),
      thumbnails: Thumbnails(),
    );

    playerBloc.emit(const PlayerState(
      status: PlayerStatus.paused,
      currentSong: testSong,
    ));

    await pumpTestWidget(
      tester,
      const PlayerPage(),
      playerBloc: playerBloc,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final tonearm = tester.widget<AudiophileTonearm>(find.byType(AudiophileTonearm));
    expect(tonearm.angle, closeTo(-0.42, 0.01));
  });
}
