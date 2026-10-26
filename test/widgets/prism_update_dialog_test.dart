import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/app_update_service.dart';
import 'package:prism_music/presentation/widgets/dialogs/prism_update_dialog.dart';

void main() {
  const testInfo = AppUpdateInfo(
    latestVersion: '0.2.55',
    latestBuildNumber: 91,
    currentVersion: '0.2.54',
    currentBuildNumber: 90,
    title: 'Prism Music alpha-v0.2.55-build91',
    changelog: '✦ Added\n- Instant search recommendations\n- Fast update checker dialog',
    releaseUrl: 'https://github.com/Jeswanth-009/Prism-Music/releases',
    apkDownloadUrl: 'https://github.com/Jeswanth-009/Prism-Music/releases/download/apk.apk',
    hasUpdate: true,
  );

  testWidgets('PrismUpdateDialog renders update details, version chips, and changelog', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrismUpdateDialog(info: testInfo),
        ),
      ),
    );

    expect(find.text('Update Available'), findsOneWidget);
    expect(find.text('A new release of Prism Music is ready'), findsOneWidget);
    expect(find.text('v0.2.54'), findsOneWidget);
    expect(find.text('v0.2.55+91'), findsOneWidget);
    expect(find.text("What's New"), findsOneWidget);
    expect(find.text(testInfo.changelog), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    expect(find.text('Update Now'), findsOneWidget);
  });

  testWidgets('PrismUpdateDialog Later button triggers dismiss callback', (tester) async {
    bool dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => PrismUpdateDialog(
                  info: testInfo,
                  onDismiss: () => dismissed = true,
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Update Available'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(find.text('Update Available'), findsNothing);
    expect(dismissed, isTrue);
    expect(AppUpdateService.instance.isDismissed('0.2.55'), isTrue);
  });
}
