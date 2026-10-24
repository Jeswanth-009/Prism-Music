import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/stats_export_service.dart';
import 'package:prism_music/domain/entities/listening_stats.dart';
import 'package:prism_music/domain/entities/song.dart';
import 'package:prism_music/presentation/widgets/stats/stats_export_sheet.dart';

class _FakeStatsExportService extends StatsExportService {
  bool shareTextCalled = false;
  bool exportJsonCalled = false;
  bool copyClipboardCalled = false;

  @override
  Future<void> shareTextSummary(ListeningStats stats) async {
    shareTextCalled = true;
  }

  @override
  Future<File?> exportStatsJson(
    ListeningStats stats, [
    List<HistoryEntry> entries = const [],
  ]) async {
    exportJsonCalled = true;
    return File('test_export.json');
  }

  @override
  Future<void> copySummaryToClipboard(ListeningStats stats) async {
    copyClipboardCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testSong = Song(
    id: 's_01',
    title: 'Neon Nights',
    artist: 'Prism Wave',
    album: 'City Lights',
    duration: Duration(seconds: 240),
    thumbnails: Thumbnails(),
  );

  final testStats = ListeningStats(
    totalPlays: 42,
    totalListeningTime: const Duration(hours: 3, minutes: 15),
    uniqueSongs: 28,
    topArtist: 'Prism Wave',
    topArtistCount: 15,
    mostPlayedSong: testSong,
    mostPlayedCount: 9,
  );

  testWidgets('StatsExportSheet renders options and delegates actions', (tester) async {
    final fakeService = _FakeStatsExportService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatsExportSheet(
            stats: testStats,
            exportService: fakeService,
          ),
        ),
      ),
    );

    expect(find.text('Export Listening Stats'), findsOneWidget);
    expect(find.text('Share Summary Card'), findsOneWidget);
    expect(find.text('Export JSON Archive (.json)'), findsOneWidget);
    expect(find.text('Copy to Clipboard'), findsOneWidget);

    // Tap Copy to Clipboard
    await tester.tap(find.text('Copy to Clipboard'));
    await tester.pumpAndSettle();
    expect(fakeService.copyClipboardCalled, isTrue);
  });
}
