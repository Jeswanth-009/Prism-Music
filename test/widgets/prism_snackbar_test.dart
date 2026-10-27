import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/presentation/widgets/common/prism_snackbar.dart';

void main() {
  testWidgets('showPrismErrorSnackBar shows friendly message and triggers retry callback',
      (tester) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showPrismErrorSnackBar(
                  context,
                  error: TimeoutException('Connection timed out after 15s'),
                  onRetry: () => retried = true,
                );
              },
              child: const Text('Show Error'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Error'));
    await tester.pumpAndSettle();

    expect(
      find.text('Connection timed out. Please check your internet connection.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(retried, isTrue);
  });
}
