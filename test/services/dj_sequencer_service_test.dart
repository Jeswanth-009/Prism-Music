import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/models/song_scan_data.dart';
import 'package:prism_music/core/services/dj_sequencer_service.dart';
import 'package:prism_music/core/services/song_analysis_cache_service.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DjSequencerService djService;
  late SongAnalysisCacheService cacheService;

  setUp(() async {
    initTestHive('dj_sequencer_service_test');
    cacheService = SongAnalysisCacheService();
    djService = DjSequencerService(cacheService: cacheService);
  });

  group('DjSequencerService', () {
    test('optimizes set order harmonically and minimizes key clashes', () async {
      final songA = song('sA', 'Track A', artist: 'Artist 1');
      final songB = song('sB', 'Track B', artist: 'Artist 2');
      final songC = song('sC', 'Track C', artist: 'Artist 3');

      // Store analysis:
      // Song A: 8A (Am), 124 BPM, -14 LUFS
      // Song B: 8B (C), 124 BPM, -14 LUFS (relative key -> very compatible with 8A)
      // Song C: 2A (Ebm), 150 BPM, -10 LUFS (clash with 8A)
      await cacheService.saveScanData(SongScanData(
        songId: songA.playableId,
        integratedLufs: -14.0,
        truePeakDbfs: -1.0,
        bpm: 124.0,
        camelotKey: '8A',
        leadSilenceSeconds: 0.0,
        tailSilenceSeconds: 0.0,
        bestPartStartSeconds: 0.0,
        bestPartEndSeconds: 0.0,
        scannedAt: DateTime.now(),
      ));

      await cacheService.saveScanData(SongScanData(
        songId: songB.playableId,
        integratedLufs: -14.0,
        truePeakDbfs: -1.0,
        bpm: 124.0,
        camelotKey: '8B',
        leadSilenceSeconds: 0.0,
        tailSilenceSeconds: 0.0,
        bestPartStartSeconds: 0.0,
        bestPartEndSeconds: 0.0,
        scannedAt: DateTime.now(),
      ));

      await cacheService.saveScanData(SongScanData(
        songId: songC.playableId,
        integratedLufs: -10.0,
        truePeakDbfs: -0.5,
        bpm: 150.0,
        camelotKey: '2A',
        leadSilenceSeconds: 0.0,
        tailSilenceSeconds: 0.0,
        bestPartStartSeconds: 0.0,
        bestPartEndSeconds: 0.0,
        scannedAt: DateTime.now(),
      ));

      // Input: A, C, B (where C is jarring between A and B)
      final optimized = await djService.optimizeSetOrder(
        [songA, songC, songB],
        flow: DjEnergyFlow.steady,
      );

      expect(optimized, hasLength(3));
      // Song A should transition into Song B first because they share BPM and relative key
      expect(optimized[0].id, equals(songA.id));
      expect(optimized[1].id, equals(songB.id));
      expect(optimized[2].id, equals(songC.id));
    });

    test('planTransition generates bar-aligned crossfade cue points', () {
      final song1 = song('s1', 'First Song', duration: const Duration(minutes: 3));
      final song2 = song('s2', 'Second Song', duration: const Duration(minutes: 3));

      final scan1 = SongScanData(
        songId: song1.playableId,
        integratedLufs: -14.0,
        truePeakDbfs: -1.0,
        bpm: 128.0,
        camelotKey: '11B',
        leadSilenceSeconds: 0.0,
        tailSilenceSeconds: 0.0,
        bestPartStartSeconds: 0.0,
        bestPartEndSeconds: 0.0,
        scannedAt: DateTime.now(),
      );

      final scan2 = SongScanData(
        songId: song2.playableId,
        integratedLufs: -14.0,
        truePeakDbfs: -1.0,
        bpm: 128.0,
        camelotKey: '11B',
        leadSilenceSeconds: 0.0,
        tailSilenceSeconds: 0.0,
        bestPartStartSeconds: 0.0,
        bestPartEndSeconds: 0.0,
        scannedAt: DateTime.now(),
      );

      final cue = djService.planTransition(song1, song2, scan1, scan2);
      expect(cue.crossfadeDuration.inMilliseconds, greaterThanOrEqualTo(3500));
      expect(cue.crossfadeDuration.inMilliseconds, lessThanOrEqualTo(9000));
      expect(cue.cueOut.inMilliseconds, lessThan(song1.duration.inMilliseconds));
      expect(cue.harmonicMatchDescription, contains('Perfect harmonic key match'));
    });
  });
}
