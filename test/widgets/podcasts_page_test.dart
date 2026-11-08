import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/domain/entities/podcast.dart';
import 'package:prism_music/presentation/pages/podcast_detail_page.dart';
import 'package:prism_music/presentation/pages/podcasts_page.dart';

import '../helpers/fakes.dart';

void main() {
  group('PodcastsPage & PodcastDetailPage', () {
    testWidgets('renders search field, categories, and layout properly', (tester) async {
      await tester.pumpWidget(
        wrapForTests(const PodcastsPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Podcasts'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search podcasts, hosts, shows...'), findsOneWidget);
      expect(find.text('Technology'), findsOneWidget);
      expect(find.text('News'), findsOneWidget);
      expect(find.text('Comedy'), findsOneWidget);
    });

    testWidgets('entering text in search field updates input', (tester) async {
      await tester.pumpWidget(
        wrapForTests(const PodcastsPage()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Huberman Lab');
      await tester.pumpAndSettle();

      expect(find.text('Huberman Lab'), findsOneWidget);
    });

    testWidgets('renders PodcastDetailPage header and subscribe button', (tester) async {
      const podcast = Podcast(
        id: 'test_pod_1',
        title: 'Prism Tech Talks',
        author: 'Prism Media',
        feedUrl: 'https://example.com/feed.xml',
        artworkUrl: 'https://example.com/art.jpg',
        description: 'Deep dive into modern audio architectures.',
        genres: ['Technology', 'Music'],
      );

      await tester.pumpWidget(
        wrapForTests(const PodcastDetailPage(podcast: podcast)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Prism Tech Talks'), findsWidgets);
      expect(find.text('Prism Media'), findsOneWidget);
      expect(find.text('Deep dive into modern audio architectures.'), findsOneWidget);
      expect(find.text('Subscribe'), findsOneWidget);
    });
  });
}
