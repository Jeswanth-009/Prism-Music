import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/di/injection.dart';
import 'package:prism_music/presentation/pages/downloads_page.dart';
import 'package:prism_music/presentation/widgets/downloads/offline_storage_info_sheet.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ensureWidgetTestHive();
  });

  setUp(() {
    registerTestGetIt();
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('renders all offline guarantee and storage info sections',
      (tester) async {
    await pumpTestWidget(
      tester,
      const OfflineStorageInfoSheet(),
    );
    await tester.pump();

    expect(find.text('Offline & Downloads Model'), findsOneWidget);
    expect(find.text('100% Offline Guarantee'), findsOneWidget);
    expect(find.text('Where Files Live'), findsOneWidget);
    expect(find.text('Audio Quality & Integrity'), findsOneWidget);
    expect(find.text('Privacy & Device-Only Data'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
  });

  testWidgets('tapping info button on downloads page opens offline info sheet',
      (tester) async {
    await pumpTestWidget(
      tester,
      const DownloadsPage(),
    );
    await tester.pump();

    final infoButton = find.byTooltip('Offline & Storage Info');
    expect(infoButton, findsOneWidget);

    await tester.tap(infoButton);
    await tester.pumpAndSettle();

    expect(find.text('Offline & Downloads Model'), findsOneWidget);
    expect(find.text('100% Offline Guarantee'), findsOneWidget);

    // Dismiss with Got it
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text('Offline & Downloads Model'), findsNothing);
  });
}
