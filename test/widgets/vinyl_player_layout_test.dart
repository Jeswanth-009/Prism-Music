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
    expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
    expect(find.byIcon(Icons.lyrics_outlined), findsOneWidget);
    expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);

    // Tap lyrics button to toggle lyrics view
    await tester.tap(find.byIcon(Icons.lyrics_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('lyrics_vinyl_01')), findsOneWidget);
  });
}
