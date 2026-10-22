import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/presentation/pages/onboarding_page.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('onboarding_test');
    Hive.init(tempDir.path);
    await SettingsService.instance.initialize();
  });

  tearDown(() async {
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  testWidgets(
      'renders all onboarding slides including transparent permissions and direct actions',
      (tester) async {
    await pumpTestWidget(tester, const OnboardingPage());
    await tester.pump();

    // Slide 1
    expect(find.text('All your music,\none app'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    // Advance to Slide 2
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Private by design'), findsOneWidget);

    // Advance to Slide 3 (Transparent Permissions)
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Transparent\nPermissions'), findsOneWidget);
    expect(find.textContaining('Media Notifications'), findsOneWidget);

    // Advance to Slide 4 (Ready to listen?)
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Ready to listen?'), findsOneWidget);
    expect(find.text('Search & Play Music'), findsOneWidget);
    expect(find.text('Explore Trending & Home'), findsOneWidget);
  });
}
