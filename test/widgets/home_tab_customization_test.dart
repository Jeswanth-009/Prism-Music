import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/presentation/widgets/home/home_sections_sheet.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    initTestHive('home_customization');
    await SettingsService.instance.initialize();
  });

  group('SettingsService - Home Sections Configuration', () {
    test('defaults to all sections enabled and allows disabling specific sections', () async {
      final settings = SettingsService.instance;
      await settings.resetHomeSections();

      expect(settings.isHomeSectionEnabled(HomeSectionId.hero), isTrue);
      expect(settings.isHomeSectionEnabled(HomeSectionId.charts), isTrue);
      expect(settings.isHomeSectionEnabled(HomeSectionId.trending), isTrue);
      expect(settings.isHomeSectionEnabled(HomeSectionId.moodChips), isTrue);
      expect(settings.isHomeSectionEnabled(HomeSectionId.pinnedPlaylists), isTrue);
      expect(settings.isHomeSectionEnabled(HomeSectionId.likedThisMonth), isTrue);
      expect(settings.isHomeSectionEnabled(HomeSectionId.unplayedDownloads), isTrue);

      await settings.setHomeSectionEnabled(HomeSectionId.charts, false);
      expect(settings.isHomeSectionEnabled(HomeSectionId.charts), isFalse);
      expect(settings.isHomeSectionEnabled(HomeSectionId.hero), isTrue);

      await settings.resetHomeSections();
      expect(settings.isHomeSectionEnabled(HomeSectionId.charts), isTrue);
    });

    test('reorders home sections and toggles pinned playlists', () async {
      final settings = SettingsService.instance;
      await settings.resetHomeSections();

      final originalOrder = settings.homeSectionsOrder;
      expect(originalOrder.first, HomeSectionId.hero);

      final newOrder = [HomeSectionId.trending, ...originalOrder.where((s) => s != HomeSectionId.trending)];
      await settings.setHomeSectionsOrder(newOrder);
      expect(settings.homeSectionsOrder.first, HomeSectionId.trending);

      expect(settings.isPlaylistPinned('p1'), isFalse);
      await settings.togglePinPlaylist('p1');
      expect(settings.isPlaylistPinned('p1'), isTrue);
      expect(settings.pinnedPlaylistIds, contains('p1'));

      await settings.togglePinPlaylist('p1');
      expect(settings.isPlaylistPinned('p1'), isFalse);
    });
  });

  group('HomeSectionsCustomizerSheet Widget', () {
    testWidgets('renders all home sections and allows toggling', (tester) async {
      var changedCount = 0;
      await pumpTestWidget(
        tester,
        HomeSectionsCustomizerSheet(
          onChanged: () => changedCount++,
        ),
        size: const Size(400, 1800),
      );

      expect(find.text('Customize Home'), findsOneWidget);
      expect(find.text('Quick Play & Greeting'), findsOneWidget);
      expect(find.text('Top Charts'), findsOneWidget);
      expect(find.text('Trending Now'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);

      // Tap the first switch to toggle a section
      final switchFinder = find.byType(Switch).first;
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(changedCount, greaterThanOrEqualTo(1));

      // Tap Reset button
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(changedCount, greaterThanOrEqualTo(2));
    });
  });
}
