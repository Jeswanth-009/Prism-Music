import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/local_backup_service.dart';
import 'package:prism_music/presentation/widgets/settings/portable_backup_sheet.dart';

void main() {
  testWidgets('renders PortableBackupSheetContent properly', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dummyInfo = BackupSnapshotInfo(
      timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      fileSizeBytes: 2048,
      boxCounts: const {
        'liked_songs': 5,
        'playlists': 2,
        'listening_history': 10,
        'downloads': 0,
      },
      filePath: '/dummy/path.json',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showPortableBackupSheet(
                context,
                initialInfo: dummyInfo,
              ),
              child: const Text('Open Backup Sheet'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open Backup Sheet'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Portable Library Backup'), findsOneWidget);
    expect(find.text('Latest Device Snapshot'), findsOneWidget);
    expect(find.text('5 Likes'), findsOneWidget);
    expect(find.text('2 Playlists'), findsOneWidget);
    expect(find.text('Export Portable Snapshot'), findsOneWidget);
    expect(find.text('Import / Restore from File'), findsOneWidget);
    expect(find.text('Export & Share Backup'), findsOneWidget);
    expect(find.text('Inspect'), findsOneWidget);

    // Scroll down to reveal Inspect button
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Inspect'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Please enter a valid file path'), findsOneWidget);
  });
}
