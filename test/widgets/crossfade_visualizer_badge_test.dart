import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/presentation/widgets/player/crossfade_visualizer_badge.dart';

void main() {
  group('CrossfadeVisualizerBadge', () {
    testWidgets('renders Crossfading text and icon when active', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CrossfadeVisualizerBadge(
                isCrossfading: true,
                compact: false,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Crossfading...'), findsOneWidget);
      expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
    });

    testWidgets('renders compact Fade text when compact is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CrossfadeVisualizerBadge(
                isCrossfading: true,
                compact: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Fade'), findsOneWidget);
      expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
    });

    testWidgets('renders nothing when isCrossfading is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CrossfadeVisualizerBadge(
                isCrossfading: false,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Crossfading...'), findsNothing);
      expect(find.text('Fade'), findsNothing);
    });
  });
}
