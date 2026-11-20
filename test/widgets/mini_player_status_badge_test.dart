import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/presentation/blocs/player/player_event.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';
import 'package:prism_music/presentation/widgets/player/mini_player.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ensureWidgetTestHive();
  });

  const testSong = Song(
    id: 'test-1',
    title: 'Test Song Title',
    artist: 'Test Artist',
    duration: Duration(seconds: 180),
    thumbnails: Thumbnails(),
  );

  testWidgets('renders repeat and shuffle badges on mini player',
      (tester) async {
    final playerBloc = buildTestPlayerBloc();
    addTearDown(playerBloc.close);

    playerBloc.emit(
      const PlayerState(
        status: PlayerStatus.playing,
        currentSong: testSong,
        repeatMode: RepeatMode.all,
        isShuffleEnabled: true,
      ),
    );

    await pumpTestWidget(
      tester,
      const MiniPlayer(),
      playerBloc: playerBloc,
    );
    await tester.pump();

    expect(find.text('Test Song Title'), findsOneWidget);
    expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);

    // Switch to repeat one
    playerBloc.emit(
      const PlayerState(
        status: PlayerStatus.playing,
        currentSong: testSong,
        repeatMode: RepeatMode.one,
        isShuffleEnabled: false,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.repeat_one_rounded), findsOneWidget);
    expect(find.byIcon(Icons.shuffle_rounded), findsNothing);
  });

  testWidgets(
      'renders queue finished state with replay action on mini player',
      (tester) async {
    final playerBloc = buildTestPlayerBloc();
    addTearDown(playerBloc.close);

    playerBloc.emit(
      const PlayerState(
        status: PlayerStatus.completed,
        currentSong: testSong,
        queue: [testSong],
        queueIndex: 0,
      ),
    );

    await pumpTestWidget(
      tester,
      const MiniPlayer(),
      playerBloc: playerBloc,
    );
    await tester.pump();

    expect(find.text('Queue finished · Tap to replay'), findsOneWidget);
    expect(find.byIcon(Icons.replay_rounded), findsOneWidget);

    // Tapping replay sends PlaySongEvent
    await tester.tap(find.byIcon(Icons.replay_rounded));
    await tester.pump();
  });
}
