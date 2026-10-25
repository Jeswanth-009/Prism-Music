import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';
import 'package:prism_music/presentation/pages/player_page.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Accessibility Acceptance Suite', () {
    testWidgets('PlayerPage provides rich semantics for screen readers',
        (tester) async {
      final playerBloc = buildTestPlayerBloc();
      addTearDown(playerBloc.close);

      playerBloc.emit(const PlayerState(
        status: PlayerStatus.playing,
        currentSong: Song(
          id: 'accessibility_song',
          title: 'Accessible Track',
          artist: 'Accessible Artist',
          duration: Duration(minutes: 3, seconds: 45),
          thumbnails: Thumbnails(),
        ),
        position: Duration(minutes: 1, seconds: 15),
        duration: Duration(minutes: 3, seconds: 45),
      ));

      await pumpTestWidget(
        tester,
        const PlayerPage(),
        playerBloc: playerBloc,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify play/pause semantics
      final playPauseFinder = find.bySemanticsLabel('Pause');
      expect(playPauseFinder, findsOneWidget);

      // 2. Verify previous and next track tooltips / labels
      expect(find.byTooltip('Previous Track'), findsOneWidget);
      expect(find.byTooltip('Next Track'), findsOneWidget);

      // 3. Verify scrubber slider has progress semantics
      final sliderSemanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.slider == true &&
            widget.properties.label == 'Track playback progress',
      );
      expect(sliderSemanticsFinder, findsOneWidget);

      // 4. Verify touch target sizing exceeds 48x48dp minimum
      final playPauseSize = tester.getSize(playPauseFinder);
      expect(playPauseSize.width, greaterThanOrEqualTo(48.0));
      expect(playPauseSize.height, greaterThanOrEqualTo(48.0));
    });
  });
}
