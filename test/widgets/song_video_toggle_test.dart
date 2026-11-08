import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/presentation/widgets/player/song_video_toggle.dart';

void main() {
  group('SongVideoToggle', () {
    testWidgets('renders Song and Video tabs when video is available', (tester) async {
      bool? toggledState;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SongVideoToggle(
                isVideoMode: false,
                isVideoAvailable: true,
                onToggle: (val) {
                  toggledState = val;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Song'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);

      await tester.tap(find.text('Video'));
      await tester.pumpAndSettle();

      expect(toggledState, isTrue);
    });

    testWidgets('switches back to Song when Video is active', (tester) async {
      bool? toggledState;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SongVideoToggle(
                isVideoMode: true,
                isVideoAvailable: true,
                onToggle: (val) {
                  toggledState = val;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Song'));
      await tester.pumpAndSettle();

      expect(toggledState, isFalse);
    });

    testWidgets('hides completely if video is unavailable and not in video mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SongVideoToggle(
                isVideoMode: false,
                isVideoAvailable: false,
                onToggle: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Song'), findsNothing);
      expect(find.text('Video'), findsNothing);
    });
  });
}
