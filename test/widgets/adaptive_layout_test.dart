import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/presentation/widgets/common/adaptive_layout.dart';

void main() {
  group('AdaptiveBreakpoints & AdaptiveLayoutBuilder', () {
    testWidgets('identifies phone portrait as compact', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool? isTabletResult;
      bool? isLandscapeResult;
      bool? isExpandedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isTabletResult = AdaptiveBreakpoints.isTablet(context);
              isLandscapeResult = AdaptiveBreakpoints.isLandscape(context);
              isExpandedResult = AdaptiveBreakpoints.isExpanded(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(isTabletResult, isFalse);
      expect(isLandscapeResult, isFalse);
      expect(isExpandedResult, isFalse);
    });

    testWidgets('identifies tablet width as expanded', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool? isTabletResult;
      bool? isExpandedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isTabletResult = AdaptiveBreakpoints.isTablet(context);
              isExpandedResult = AdaptiveBreakpoints.isExpanded(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(isTabletResult, isTrue);
      expect(isExpandedResult, isTrue);
    });

    testWidgets('identifies landscape phone as expanded', (tester) async {
      tester.view.physicalSize = const Size(840, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool? isLandscapeResult;
      bool? isExpandedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isLandscapeResult = AdaptiveBreakpoints.isLandscape(context);
              isExpandedResult = AdaptiveBreakpoints.isExpanded(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(isLandscapeResult, isTrue);
      expect(isExpandedResult, isTrue);
    });

    testWidgets('AdaptiveLayoutBuilder displays compact vs expanded widgets',
        (tester) async {
      // 1. Mobile view
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveLayoutBuilder(
            compact: (_) => const Text('COMPACT_VIEW'),
            expanded: (_) => const Text('EXPANDED_VIEW'),
          ),
        ),
      );

      expect(find.text('COMPACT_VIEW'), findsOneWidget);
      expect(find.text('EXPANDED_VIEW'), findsNothing);

      // 2. Switch to tablet view
      tester.view.physicalSize = const Size(900, 600);
      await tester.pumpAndSettle();

      expect(find.text('COMPACT_VIEW'), findsNothing);
      expect(find.text('EXPANDED_VIEW'), findsOneWidget);
    });

    testWidgets('AdaptiveSplitPane renders left and right panes in row',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdaptiveSplitPane(
              left: Text('LEFT_PANE'),
              right: Text('RIGHT_PANE'),
            ),
          ),
        ),
      );

      expect(find.text('LEFT_PANE'), findsOneWidget);
      expect(find.text('RIGHT_PANE'), findsOneWidget);
      expect(find.byType(Row), findsOneWidget);
    });
  });
}
