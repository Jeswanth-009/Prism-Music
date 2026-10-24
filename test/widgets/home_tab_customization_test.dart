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

      await settings.setHomeSectionEnabled(HomeSectionId.charts, false);
      expect(settings.isHomeSectionEnabled(HomeSectionId.charts), isFalse);
      expect(settings.isHomeSectionEnabled(HomeSectionId.hero), isTrue);

      await settings.resetHomeSections();
      expect(settings.isHomeSectionEnabled(HomeSectionId.charts), isTrue);
    });
  });

  group('HomeSectionsCustomizerSheet Widget', () {
    testWidgets('renders all home sections and allows toggling', (tester) async {
      var changedCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeSectionsCustomizerSheet(
              onChanged: () => changedCount++,
            ),
          ),
        ),
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
