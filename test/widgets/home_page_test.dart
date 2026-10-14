import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/presentation/pages/home_page.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'HomePage mounts first tab initially and lazily mounts other tabs on selection',
      (tester) async {
    var tab0Builds = 0;
    var tab1Builds = 0;
    var tab2Builds = 0;
    var tab3Builds = 0;

    await pumpTestWidget(
      tester,
      HomePage(
        tabBuilders: [
          (_) {
            tab0Builds++;
            return const Text('Tab 0 Content');
          },
          (_) {
            tab1Builds++;
            return const Text('Tab 1 Content');
          },
          (_) {
            tab2Builds++;
            return const Text('Tab 2 Content');
          },
          (_) {
            tab3Builds++;
            return const Text('Tab 3 Content');
          },
        ],
      ),
    );
    await tester.pump();

    // Tab 0 is initially mounted
    expect(find.text('Tab 0 Content'), findsOneWidget);
    expect(tab0Builds, 1);
    // Other tabs are not mounted yet
    expect(find.text('Tab 1 Content'), findsNothing);
    expect(tab1Builds, 0);
    expect(find.text('Tab 2 Content'), findsNothing);
    expect(tab2Builds, 0);
    expect(find.text('Tab 3 Content'), findsNothing);
    expect(tab3Builds, 0);

    // Tap Library (tab 3)
    await tester.tap(find.text('Library'));
    await tester.pump();

    // Tab 3 is now mounted
    expect(find.text('Tab 3 Content'), findsOneWidget);
    expect(tab3Builds, 1);
    // Tab 1 and Tab 2 remain unmounted
    expect(find.text('Tab 1 Content'), findsNothing);
    expect(tab1Builds, 0);
    expect(find.text('Tab 2 Content'), findsNothing);
    expect(tab2Builds, 0);

    // Tap Search (tab 1)
    await tester.tap(find.text('Search'));
    await tester.pump();

    expect(find.text('Tab 1 Content'), findsOneWidget);
    expect(tab1Builds, 1);
    expect(find.text('Tab 2 Content'), findsNothing);
    expect(tab2Builds, 0);
  });
}
