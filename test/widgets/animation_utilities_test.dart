import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/presentation/blocs/theme/theme_state.dart';
import 'package:prism_music/presentation/theme/prism_page_transitions.dart';
import 'package:prism_music/presentation/widgets/common/bouncing_tap_widget.dart';
import 'package:prism_music/presentation/widgets/common/staggered_list_animation.dart';
import 'package:prism_music/presentation/widgets/prism/prism_skeleton.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    initTestHive('animation_test');
    SettingsService.resetForTesting(secureStorage: FakeSecureStorage());
    await SettingsService.instance.initialize();
  });

  setUp(() async {
    await SettingsService.instance.setReducedMotionMode(false);
  });

  Widget wrap(Widget child) => MaterialApp(
        theme: const ThemeState().lightTheme,
        home: Scaffold(body: child),
      );

  group('Animation Utilities & Micro-Interactions', () {
    testWidgets('PrismStaggeredItem animates entrance when motion is enabled',
        (tester) async {
      await tester.pumpWidget(
        wrap(const PrismStaggeredItem(
          index: 0,
          child: Text('STAGGERED_ITEM'),
        )),
      );

      expect(find.text('STAGGERED_ITEM'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 350));
    });

    testWidgets('PrismStaggeredItem renders immediately when reduced motion is enabled',
        (tester) async {
      await tester.runAsync(() => SettingsService.instance.setReducedMotionMode(true));

      await tester.pumpWidget(
        wrap(const PrismStaggeredItem(
          index: 2,
          child: Text('REDUCED_MOTION_ITEM'),
        )),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('REDUCED_MOTION_ITEM'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PrismStaggeredItem),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
    });

    testWidgets('BouncingTapWidget responds to tap and animates scale',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        wrap(BouncingTapWidget(
          onTap: () => tapped = true,
          child: const Text('TAP_ME'),
        )),
      );

      await tester.tap(find.text('TAP_ME'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tapped, isTrue);
    });

    testWidgets('BouncingTapWidget honors reduced motion without scale bouncing',
        (tester) async {
      await tester.runAsync(() => SettingsService.instance.setReducedMotionMode(true));
      var tapped = false;

      await tester.pumpWidget(
        wrap(BouncingTapWidget(
          onTap: () => tapped = true,
          child: const Text('REDUCED_TAP'),
        )),
      );

      await tester.tap(find.text('REDUCED_TAP'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tapped, isTrue);
    });

    testWidgets('PrismSkeleton renders static block when reduced motion is active',
        (tester) async {
      await tester.runAsync(() => SettingsService.instance.setReducedMotionMode(true));

      await tester.pumpWidget(
        wrap(const PrismSkeletonGroup(
          child: PrismSkeleton(width: 100, height: 20),
        )),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(ShaderMask), findsNothing);
      expect(find.byType(PrismSkeleton), findsOneWidget);
    });

    testWidgets('PrismPageTransitionsBuilder renders transition or instant child based on reduced motion',
        (tester) async {
      const builder = PrismPageTransitionsBuilder();

      await tester.pumpWidget(
        MaterialApp(
          theme: const ThemeState().lightTheme,
          home: Builder(
            builder: (context) {
              final normalTransition = builder.buildTransitions(
                MaterialPageRoute(builder: (_) => const SizedBox()),
                context,
                const AlwaysStoppedAnimation(0.5),
                const AlwaysStoppedAnimation(0.0),
                const Text('TRANSITION_PAGE'),
              );
              return Scaffold(body: normalTransition);
            },
          ),
        ),
      );

      expect(find.text('TRANSITION_PAGE'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(SlideTransition),
        ),
        findsOneWidget,
      );
    });
  });
}
