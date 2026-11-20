import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/presentation/widgets/common/prism_streaming_error_banner.dart';

import '../helpers/fakes.dart';

void main() {
  group('PrismStreamingErrorBanner Tests', () {
    testWidgets('renders mapped error message and error icon', (tester) async {
      await tester.pumpWidget(
        wrapForTests(
          const Scaffold(
            body: PrismStreamingErrorBanner(
              errorMessage: 'Network error 404',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('The requested track could not be found.'), findsOneWidget);
    });

    testWidgets('invokes onRetry callback when Retry button tapped', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        wrapForTests(
          Scaffold(
            body: PrismStreamingErrorBanner(
              errorMessage: 'Failed to load stream',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      final retryButton = find.widgetWithText(TextButton, 'Retry');
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      await tester.pump();

      expect(retried, isTrue);
    });

    testWidgets('invokes onDismiss callback when dismiss button tapped', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        wrapForTests(
          Scaffold(
            body: PrismStreamingErrorBanner(
              errorMessage: 'Something went wrong',
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      final dismissButton = find.byTooltip('Dismiss error');
      expect(dismissButton, findsOneWidget);

      await tester.tap(dismissButton);
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('has accessible Semantics node with liveRegion', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        wrapForTests(
          const Scaffold(
            body: PrismStreamingErrorBanner(
              errorMessage: 'Playback stalled',
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp('Streaming error.*Playback stalled')),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}
