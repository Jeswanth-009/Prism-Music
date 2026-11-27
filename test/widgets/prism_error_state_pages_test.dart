import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/presentation/pages/charts_hub_page.dart';
import 'package:prism_music/presentation/pages/genre_browse_page.dart';
import 'package:prism_music/presentation/widgets/prism/prism_states.dart';

import '../helpers/fakes.dart';

void main() {
  group('PrismErrorState across pages', () {
    testWidgets('PrismErrorState renders custom title, message, and executes retry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        wrapForTests(
          Scaffold(
            body: PrismErrorState(
              title: 'Could not load podcasts',
              message: 'Network connection failed',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Could not load podcasts'), findsOneWidget);
      expect(find.text('Network connection failed'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);

      final retryButton = find.text('Try again');
      expect(retryButton, findsOneWidget);
      await tester.tap(retryButton);
      await tester.pump();

      expect(retried, isTrue);
    });

    testWidgets('ChartsHubPage renders charts without crashing', (tester) async {
      await tester.pumpWidget(
        wrapForTests(
          const Scaffold(
            body: ChartsHubPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Charts'), findsAtLeastNWidgets(1));
    });

    testWidgets('GenreBrowsePage renders search and categories', (tester) async {
      await tester.pumpWidget(
        wrapForTests(
          const Scaffold(
            body: GenreBrowsePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Genres & Moods'), findsOneWidget);
    });
  });
}
