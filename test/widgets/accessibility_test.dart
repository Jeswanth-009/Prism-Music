import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/presentation/blocs/player/player.dart';
import 'package:prism_music/presentation/blocs/theme/theme_state.dart';
import 'package:prism_music/presentation/widgets/player/mini_player.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('MiniPlayer supports large text scaling without layout overflow', (tester) async {
    final playerBloc = buildTestPlayerBloc();
    addTearDown(playerBloc.close);
    final current = song('song_1', 'A Very Long Song Title That Might Span Across Lines When Scaled Heavily', artist: 'Very Long Artist Name Testing Accessibility');
    playerBloc.emit(
      PlayerState(
        status: PlayerStatus.playing,
        currentSong: current,
        duration: const Duration(minutes: 3),
        position: const Duration(minutes: 1),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: const ThemeState().darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.8),
          ),
          child: BlocProvider<PlayerBloc>.value(
            value: playerBloc,
            child: const Scaffold(
              bottomNavigationBar: MiniPlayer(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify MiniPlayer rendered successfully without flutter errors
    expect(tester.takeException(), isNull);
    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(find.text(current.title), findsOneWidget);

    // Verify touch targets on mini actions meet minimum size (>= 48x48)
    final pauseButtonFinder = find.byTooltip('Pause');
    expect(pauseButtonFinder, findsOneWidget);
    final size = tester.getSize(pauseButtonFinder);
    expect(size.width, greaterThanOrEqualTo(48.0));
    expect(size.height, greaterThanOrEqualTo(48.0));
  });
}
