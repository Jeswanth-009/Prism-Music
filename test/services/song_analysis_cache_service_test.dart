import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:prism_music/core/models/song_scan_data.dart';
import 'package:prism_music/core/services/song_analysis_cache_service.dart';

void main() {
  late Directory tempDir;
  late Box testBox;
  late SongAnalysisCacheService service;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('prism_scan_cache_test_');
    Hive.init(tempDir.path);
    testBox = await Hive.openBox('test_song_scan_cache');
  });

  tearDownAll(() async {
    await testBox.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    await testBox.clear();
    service = SongAnalysisCacheService(box: testBox);
  });

  group('SongAnalysisCacheService', () {
    test('saves and retrieves song scan data', () async {
      final scanData = SongScanData(
        songId: 'track_999',
        integratedLufs: -14.2,
        truePeakDbfs: -0.8,
        bpm: 128.0,
        camelotKey: '8B',
        leadSilenceSeconds: 0.12,
        tailSilenceSeconds: 0.45,
        bestPartStartSeconds: 45.0,
        bestPartEndSeconds: 70.0,
        scannedAt: DateTime(2026, 11, 22),
      );

      expect(await service.hasScanData('track_999'), isFalse);
      await service.saveScanData(scanData);

      expect(await service.hasScanData('track_999'), isTrue);
      final retrieved = await service.getScanData('track_999');
      expect(retrieved, isNotNull);
      expect(retrieved!.songId, equals('track_999'));
      expect(retrieved.integratedLufs, equals(-14.2));
      expect(retrieved.bpm, equals(128.0));
      expect(retrieved.camelotKey, equals('8B'));
    });

    test('analyzePcm scans buffer and produces valid SongScanData', () {
      final samples = Float32List(44100); // 1s of silence
      final result = service.analyzePcm('silent_song', samples);

      expect(result.songId, equals('silent_song'));
      expect(result.integratedLufs, equals(-70.0));
      expect(result.truePeakDbfs, equals(-100.0));
      expect(result.bpm, inInclusiveRange(60.0, 200.0));
    });
  });
}
