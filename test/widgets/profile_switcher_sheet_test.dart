import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/presentation/widgets/profile/profile_switcher_sheet.dart';

import '../helpers/fakes.dart';

void main() {
  group('ProfileSwitcherSheet', () {
    testWidgets('renders Profiles title, subtitle, and add profile button', (tester) async {
      await tester.pumpWidget(
        wrapForTests(
          const Scaffold(
            body: ProfileSwitcherSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profiles'), findsOneWidget);
      expect(find.text('Add Profile'), findsOneWidget);
      expect(find.text('Local profiles for multi-user family devices'), findsOneWidget);
      expect(find.text('Primary'), findsOneWidget);
    });

    testWidgets('tapping Add Profile opens creation dialog', (tester) async {
      await tester.pumpWidget(
        wrapForTests(
          const Scaffold(
            body: ProfileSwitcherSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Add Local Profile'), findsOneWidget);
      expect(find.text('Choose Avatar'), findsOneWidget);
      expect(find.text('Kids Mode'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
    });
  });
}
