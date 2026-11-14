import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/core/services/visualizer_service.dart';
import 'package:prism_music/presentation/widgets/player/audio_visualizer_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioVisualizerWidget', () {
    testWidgets('renders CustomPaint when visualizer style is bars', (tester) async {
      await VisualizerService.instance.setStyle(VisualizerStyle.bars);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioVisualizerWidget(
              isPlaying: true,
              dominantColor: Colors.purple,
              height: 40,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(AudioVisualizerWidget), findsOneWidget);
      final visualizerPaint = find.descendant(
        of: find.byType(AudioVisualizerWidget),
        matching: find.byType(CustomPaint),
      );
      expect(visualizerPaint, findsOneWidget);
    });

    testWidgets('renders empty space when visualizer is off', (tester) async {
      await VisualizerService.instance.setStyle(VisualizerStyle.off);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioVisualizerWidget(
              isPlaying: true,
              dominantColor: Colors.cyan,
              height: 40,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final visualizerPaint = find.descendant(
        of: find.byType(AudioVisualizerWidget),
        matching: find.byType(CustomPaint),
      );
      expect(visualizerPaint, findsNothing);
    });

    testWidgets('tapping visualizer cycles through styles', (tester) async {
      await VisualizerService.instance.setStyle(VisualizerStyle.bars);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioVisualizerWidget(
              isPlaying: true,
              dominantColor: Colors.deepOrange,
              height: 40,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byType(AudioVisualizerWidget));
      await tester.pump(const Duration(milliseconds: 50));

      expect(VisualizerService.instance.style, equals(VisualizerStyle.wave));
    });
  });
}
