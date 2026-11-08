import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/genre_service.dart';
import 'package:prism_music/presentation/pages/genre_browse_page.dart';
import 'package:prism_music/presentation/pages/genre_detail_page.dart';

import '../helpers/fakes.dart';

void main() {
  group('GenreBrowsePage & GenreDetailPage', () {
    testWidgets('renders search box, filter chips, and genre cards', (tester) async {
      await tester.pumpWidget(
        wrapForTests(const GenreBrowsePage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Genres & Moods'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All Categories'), findsOneWidget);
      expect(find.text('Music Genres'), findsOneWidget);
      expect(find.text('Moods & Activities'), findsOneWidget);
      expect(find.text('Pop'), findsOneWidget);
      expect(find.text('Rock & Alternative'), findsOneWidget);
    });

    testWidgets('filters genres when typing in search query', (tester) async {
      await tester.pumpWidget(
        wrapForTests(const GenreBrowsePage()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Rock');
      await tester.pumpAndSettle();

      expect(find.text('Rock & Alternative'), findsOneWidget);
      expect(find.text('Bollywood & Hindi'), findsNothing);
    });

    testWidgets('filter chips filter between genres and moods', (tester) async {
      await tester.pumpWidget(
        wrapForTests(const GenreBrowsePage()),
      );
      await tester.pumpAndSettle();

      // Tap Moods & Activities chip
      await tester.tap(find.text('Moods & Activities'));
      await tester.pumpAndSettle();

      expect(find.text('Lo-Fi & Study'), findsOneWidget);
      expect(find.text('Workout & Energy'), findsOneWidget);
      expect(find.text('Pop'), findsNothing);
    });

    testWidgets('GenreDetailPage renders description and curated playlists', (tester) async {
      final genre = GenreService.instance.getGenreById('pop')!;

      await tester.pumpWidget(
        wrapForTests(GenreDetailPage(genre: genre)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pop'), findsOneWidget);
      expect(find.text('Curated Playlists'), findsOneWidget);
      expect(find.text(genre.description), findsOneWidget);
      expect(find.text('${genre.playlistCount} available'), findsOneWidget);
    });
  });
}
