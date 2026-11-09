import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:prism_music/presentation/blocs/player/player_bloc.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';
import 'package:prism_music/presentation/widgets/player/player_slider_widget.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Player Performance & Scrubber Isolation Tests', () {
    testWidgets('PlayerSliderWidget uses isolated BlocBuilder when state is omitted', (tester) async {
      final playerBloc = buildTestPlayerBloc();
      addTearDown(playerBloc.close);

      final testTrack = song(
        'perf_test_1',
        'Performance Track',
        duration: const Duration(minutes: 3),
      );

      playerBloc.emit(
        PlayerState(
          status: PlayerStatus.playing,
          currentSong: testTrack,
          position: const Duration(seconds: 15),
          duration: const Duration(minutes: 3),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<PlayerBloc>.value(
            value: playerBloc,
            child: const Scaffold(
              body: PlayerSliderWidget(),
            ),
          ),
        ),
      );

      expect(find.byType(PlayerSliderWidget), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // Verify position and remaining duration rendered
      expect(find.text('0:15'), findsOneWidget);
      expect(find.text('-2:45'), findsOneWidget);

      // Advance position only
      playerBloc.emit(
        PlayerState(
          status: PlayerStatus.playing,
          currentSong: testTrack,
          position: const Duration(seconds: 30),
          duration: const Duration(minutes: 3),
        ),
      );
      await tester.pump();

      // Scrubber times should update cleanly
      expect(find.text('0:30'), findsOneWidget);
      expect(find.text('-2:30'), findsOneWidget);
    });
  });
}
