import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';
import 'package:prism_music/presentation/pages/home_page.dart';
import 'package:prism_music/presentation/pages/player_page.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tablet and Landscape Adaptive Layouts', () {
    testWidgets('PlayerPage renders landscape split-pane layout without overflow',
        (tester) async {
      final playerBloc = buildTestPlayerBloc();
      addTearDown(playerBloc.close);

      playerBloc.emit(const PlayerState(
        status: PlayerStatus.playing,
        currentSong: Song(
          id: 'landscape_track',
          title: 'Adaptive Landscape Song',
          artist: 'Prism Adaptive Artist',
          duration: Duration(seconds: 240),
          thumbnails: Thumbnails(),
        ),
      ));

      await pumpTestWidget(
        tester,
        const PlayerPage(),
        playerBloc: playerBloc,
        size: const Size(900, 420),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Adaptive Landscape Song'), findsOneWidget);
      expect(find.textContaining('Adaptive Landscape Song'), findsOneWidget);

      // Verify no Flutter error/overflow occurred
      expect(tester.takeException(), isNull);
    });

    testWidgets('HomePage renders NavigationRail when on tablet width',
        (tester) async {
      final playerBloc = buildTestPlayerBloc();
      addTearDown(playerBloc.close);

      await pumpTestWidget(
        tester,
        HomePage(
          tabBuilders: [
            (_) => const Center(child: Text('TAB_HOME')),
            (_) => const Center(child: Text('TAB_SEARCH')),
            (_) => const Center(child: Text('TAB_CHARTS')),
            (_) => const Center(child: Text('TAB_LIBRARY')),
          ],
        ),
        playerBloc: playerBloc,
        size: const Size(800, 1024),
      );
      await tester.pump();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('TAB_HOME'), findsOneWidget);
    });
  });
}
