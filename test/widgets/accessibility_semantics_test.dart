import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/domain/entities/song.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';
import 'package:prism_music/presentation/widgets/player/player_action_bar.dart';
import 'package:prism_music/presentation/widgets/player/player_controls_section.dart';

import '../helpers/fakes.dart';

void main() {
  group('Accessibility & Semantics Tests', () {
    const testSong = Song(
      id: 'test_song_1',
      title: 'Accessible Track',
      artist: 'Accessible Artist',
      duration: Duration(seconds: 180),
      thumbnails: Thumbnails(),
    );

    testWidgets('PlayerControlsSection provides accessible transport buttons', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        wrapForTests(
          const Scaffold(
            body: PlayerControlsSection(),
          ),
        ),
      );

      expect(find.byTooltip('Previous Track'), findsOneWidget);
      expect(find.byTooltip('Next Track'), findsOneWidget);
      expect(find.bySemanticsLabel('Play'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('PlayerActionBar provides accessible actions with semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        wrapForTests(
          Scaffold(
            body: PlayerActionBar(
              song: testSong,
              state: const PlayerState(),
              showLyrics: false,
              onToggleLyrics: () {},
            ),
          ),
        ),
      );

      expect(find.byTooltip('Shuffle'), findsOneWidget);
      expect(find.byTooltip('Repeat: Off'), findsOneWidget);
      expect(find.byTooltip('Like'), findsOneWidget);
      expect(find.byTooltip('Lyrics'), findsOneWidget);
      expect(find.byTooltip('Queue'), findsOneWidget);

      expect(find.bySemanticsLabel(RegExp('shuffle', caseSensitive: false)), findsAtLeastNWidgets(1));
      expect(find.bySemanticsLabel(RegExp('like', caseSensitive: false)), findsAtLeastNWidgets(1));
      expect(find.bySemanticsLabel(RegExp('lyrics', caseSensitive: false)), findsAtLeastNWidgets(1));

      handle.dispose();
    });
  });
}
