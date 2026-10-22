import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prism_music/presentation/widgets/prism/prism_artwork.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrismArtwork Fallbacks', () {
    testWidgets('renders song fallback with music_note_rounded icon', (tester) async {
      await tester.pumpWidget(
        wrapForTests(
          const PrismArtwork(url: '', type: ArtworkType.song),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    });

    testWidgets('renders album fallback with album_rounded icon', (tester) async {
      await tester.pumpWidget(
        wrapForTests(
          const PrismArtwork(url: '', type: ArtworkType.album),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.album_rounded), findsOneWidget);
    });

    testWidgets('renders artist fallback with person_rounded icon and circular clip', (tester) async {
      await tester.pumpWidget(
        wrapForTests(
          const PrismArtwork(url: '', type: ArtworkType.artist, isCircular: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.byType(ClipOval), findsOneWidget);
    });

    testWidgets('renders playlist fallback with queue_music_rounded icon', (tester) async {
      await tester.pumpWidget(
        wrapForTests(
          const PrismArtwork(url: '', type: ArtworkType.playlist),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);
    });
  });

  group('Typography Configuration', () {
    test('runtime font fetching is disabled to ensure offline bundled typography', () {
      expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
    });
  });
}
