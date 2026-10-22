import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/utils/date_grouping.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/presentation/blocs/library/library_bloc.dart';
import 'package:prism_music/presentation/blocs/library/library_event.dart';
import 'package:prism_music/presentation/pages/recently_played_page.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DateGrouping Utility', () {
    test('classifies timestamps into accurate period labels', () {
      final now = DateTime.now();
      final todayTime = now.subtract(const Duration(minutes: 5));
      final yesterdayTime = now.subtract(const Duration(days: 1, hours: 2));
      final thisWeekTime = now.subtract(const Duration(days: 4));
      final earlierTime = now.subtract(const Duration(days: 20));

      expect(DateGrouping.getPeriodLabel(todayTime), DateGrouping.today);
      expect(DateGrouping.getPeriodLabel(yesterdayTime), DateGrouping.yesterday);
      expect(DateGrouping.getPeriodLabel(thisWeekTime), DateGrouping.thisWeek);
      expect(DateGrouping.getPeriodLabel(earlierTime), DateGrouping.earlier);
    });

    test('formats relative time human-readably', () {
      final now = DateTime.now();
      expect(DateGrouping.formatRelativeTime(now), 'Just now');
      expect(DateGrouping.formatRelativeTime(now.subtract(const Duration(minutes: 5))), '5m ago');
      expect(DateGrouping.formatRelativeTime(now.subtract(const Duration(hours: 3))), '3h ago');
    });

    test('groups items into ordered periods', () {
      final now = DateTime.now();
      final items = [
        {'id': '1', 'time': now.subtract(const Duration(minutes: 10))},
        {'id': '2', 'time': now.subtract(const Duration(days: 1, hours: 1))},
        {'id': '3', 'time': now.subtract(const Duration(days: 15))},
      ];

      final grouped = DateGrouping.groupByPeriod(items, (item) => item['time'] as DateTime);
      expect(grouped.containsKey(DateGrouping.today), isTrue);
      expect(grouped.containsKey(DateGrouping.yesterday), isTrue);
      expect(grouped.containsKey(DateGrouping.earlier), isTrue);
      expect(grouped[DateGrouping.today]?.length, 1);
    });
  });

  group('RecentlyPlayedPage and LibraryBloc History Deletion', () {
    late FakeLibraryRepository libraryRepo;
    late FakeMusicRepository musicRepo;
    late LibraryBloc libraryBloc;

    setUp(() {
      libraryRepo = FakeLibraryRepository();
      musicRepo = FakeMusicRepository();
      libraryBloc = LibraryBloc(
        libraryRepository: libraryRepo,
        musicRepository: musicRepo,
      );
    });

    tearDown(() => libraryBloc.close());

    testWidgets('renders grouped history sections and allows per-song deletion', (tester) async {
      final s1 = song('song_1', 'Midnight City', artist: 'M83');
      final s2 = song('song_2', 'Starboy', artist: 'The Weeknd');
      final now = DateTime.now();

      libraryRepo.history = [s1, s2];
      libraryRepo.recentlyPlayed = [s1, s2];
      libraryRepo.historyEntries = [
        HistoryEntry(song: s1, playedAt: now.subtract(const Duration(minutes: 10))),
        HistoryEntry(song: s2, playedAt: now.subtract(const Duration(days: 2))),
      ];

      libraryBloc.add(const LoadLibraryEvent());
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));

      await tester.pumpWidget(wrapForTests(
        const RecentlyPlayedPage(),
        libraryBloc: libraryBloc,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Should display song titles
      expect(find.text('Midnight City'), findsOneWidget);
      expect(find.text('Starboy'), findsOneWidget);

      // Should display period headers
      expect(find.text(DateGrouping.today.toUpperCase()), findsOneWidget);
      expect(find.text(DateGrouping.thisWeek.toUpperCase()), findsOneWidget);

      // Should have per-song delete buttons
      final removeButtons = find.byTooltip('Remove from history');
      expect(removeButtons, findsNWidgets(2));

      // Tap remove on first song
      await tester.tap(removeButtons.first);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // First song removed
      expect(libraryRepo.historyRemoved, contains('song_1'));
      expect(find.text('Midnight City'), findsNothing);
      expect(find.text('Starboy'), findsOneWidget);
    });
  });
}
