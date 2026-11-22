import 'dart:math' as math;

import '../../domain/entities/song.dart';
import '../models/song_scan_data.dart';
import 'song_analysis_cache_service.dart';

/// DJ Energy trajectory preferences
enum DjEnergyFlow {
  steady,
  build,
  windDown,
}

/// Transition cue points for seamless crossfading between two songs
class DjTransitionCue {
  final Song outgoingSong;
  final Song incomingSong;
  final Duration cueOut;
  final Duration cueIn;
  final Duration crossfadeDuration;
  final double blendCost;
  final String harmonicMatchDescription;

  const DjTransitionCue({
    required this.outgoingSong,
    required this.incomingSong,
    required this.cueOut,
    required this.cueIn,
    required this.crossfadeDuration,
    required this.blendCost,
    required this.harmonicMatchDescription,
  });
}

/// DJ Sequencer: scans BPM, musical key (Camelot wheel), loudness, and energy
/// to optimize set ordering using greedy + 2-opt squared blend cost minimization.
class DjSequencerService {
  final SongAnalysisCacheService _cacheService;

  DjSequencerService({SongAnalysisCacheService? cacheService})
      : _cacheService = cacheService ?? SongAnalysisCacheService();

  /// Optimizes a playlist or queue of songs for seamless DJ mix transitions
  Future<List<Song>> optimizeSetOrder(
    List<Song> songs, {
    DjEnergyFlow flow = DjEnergyFlow.steady,
  }) async {
    if (songs.length <= 2) return List.of(songs);

    // 1. Fetch or estimate song scan data
    final scans = <String, SongScanData>{};
    for (final song in songs) {
      final cached = await _cacheService.getScanData(song.playableId);
      scans[song.id] = cached ?? _estimateDefaultScan(song);
    }

    // 2. Greedy nearest-neighbor initialization
    final unvisited = List.of(songs);
    final ordered = <Song>[unvisited.removeAt(0)];

    while (unvisited.isNotEmpty) {
      final current = ordered.last;
      final currentScan = scans[current.id]!;

      int bestIndex = 0;
      double minCost = double.infinity;

      for (int i = 0; i < unvisited.length; i++) {
        final candidate = unvisited[i];
        final candScan = scans[candidate.id]!;
        final cost = _calculateBlendCost(current, candidate, currentScan, candScan, flow);

        if (cost < minCost) {
          minCost = cost;
          bestIndex = i;
        }
      }

      ordered.add(unvisited.removeAt(bestIndex));
    }

    // 3. 2-opt optimization passes (reversing segments to resolve crossed / high-cost transitions)
    bool improved = true;
    int iterations = 0;
    const maxIterations = 50;

    while (improved && iterations < maxIterations) {
      improved = false;
      iterations++;

      for (int i = 0; i < ordered.length - 2; i++) {
        for (int j = i + 2; j < ordered.length; j++) {
          final a = ordered[i];
          final b = ordered[i + 1];
          final c = ordered[j - 1];
          final d = (j < ordered.length) ? ordered[j] : null;

          final currentSegmentCost = _calculateBlendCost(a, b, scans[a.id]!, scans[b.id]!, flow) +
              (d != null ? _calculateBlendCost(c, d, scans[c.id]!, scans[d.id]!, flow) : 0.0);

          final reversedSegmentCost = _calculateBlendCost(a, c, scans[a.id]!, scans[c.id]!, flow) +
              (d != null ? _calculateBlendCost(b, d, scans[b.id]!, scans[d.id]!, flow) : 0.0);

          if (reversedSegmentCost < currentSegmentCost - 0.01) {
            // Reverse sub-list from i + 1 to j - 1
            final segment = ordered.sublist(i + 1, j).reversed.toList();
            ordered.replaceRange(i + 1, j, segment);
            improved = true;
            break;
          }
        }
        if (improved) break;
      }
    }

    return ordered;
  }

  /// Calculates the squared blend cost between two adjacent songs
  double _calculateBlendCost(
    Song a,
    Song b,
    SongScanData scanA,
    SongScanData scanB,
    DjEnergyFlow flow,
  ) {
    // 1. Camelot Harmonic Key clash (weight 1.0)
    final keyClash = _calculateCamelotClash(scanA.camelotKey, scanB.camelotKey);

    // 2. Octave-free BPM tempo gap (weight 0.8)
    final tempoGap = _calculateOctaveFreeBpmGap(scanA.bpm, scanB.bpm);

    // 3. Artist repetition penalty (weight 0.7)
    final artistPenalty = (a.artist.toLowerCase() == b.artist.toLowerCase()) ? 1.0 : 0.0;

    // 4. Energy flow penalty (weight 0.6)
    final energyDiff = scanB.energy - scanA.energy;
    double energyCost = 0.0;
    switch (flow) {
      case DjEnergyFlow.steady:
        energyCost = energyDiff.abs();
        break;
      case DjEnergyFlow.build:
        energyCost = energyDiff >= 0 ? 0.0 : (-energyDiff);
        break;
      case DjEnergyFlow.windDown:
        energyCost = energyDiff <= 0 ? 0.0 : energyDiff;
        break;
    }

    // Worst transitions dominate via squared penalty
    return (1.0 * keyClash * keyClash) +
        (0.8 * tempoGap * tempoGap) +
        (0.7 * artistPenalty) +
        (0.6 * energyCost * energyCost);
  }

  /// Camelot wheel distance clash: 0.0 (perfect) to 1.0 (harsh clash)
  double _calculateCamelotClash(String keyA, String keyB) {
    if (keyA.isEmpty || keyB.isEmpty || keyA == 'Unknown' || keyB == 'Unknown') {
      return 0.3; // neutral penalty for unknown
    }
    if (keyA == keyB) return 0.0;

    final numA = int.tryParse(keyA.substring(0, keyA.length - 1)) ?? 0;
    final numB = int.tryParse(keyB.substring(0, keyB.length - 1)) ?? 0;
    final letterA = keyA[keyA.length - 1];
    final letterB = keyB[keyB.length - 1];

    if (numA == 0 || numB == 0) return 0.3;

    // Wheel distance on 12-hour clock
    int wheelDist = (numA - numB).abs();
    if (wheelDist > 6) wheelDist = 12 - wheelDist;

    if (letterA == letterB) {
      if (wheelDist == 1) return 0.1; // Adjacent key
      if (wheelDist == 2) return 0.5; // Two steps
      return 1.0; // Harmonic clash
    } else {
      // Relative major/minor switch
      if (wheelDist == 0) return 0.15; // Relative key (e.g. 8A to 8B)
      if (wheelDist == 1) return 0.35; // Diagonal jump
      return 1.0;
    }
  }

  /// Octave-free BPM ratio difference (e.g. 70 bpm matches 140 bpm)
  double _calculateOctaveFreeBpmGap(double bpmA, double bpmB) {
    if (bpmA <= 0 || bpmB <= 0) return 0.3;

    final scales = [0.5, 1.0, 2.0];
    double minGap = double.infinity;

    for (final scale in scales) {
      final scaledB = bpmB * scale;
      final gap = ((bpmA - scaledB) / bpmA).abs();
      if (gap < minGap) minGap = gap;
    }

    return minGap.clamp(0.0, 1.0);
  }

  /// Calculates transition cue points and crossfade length between two tracks
  DjTransitionCue planTransition(
    Song outgoing,
    Song incoming,
    SongScanData scanOut,
    SongScanData scanIn,
  ) {
    final bpm = scanOut.bpm > 0 ? scanOut.bpm : 120.0;
    // Length of 2 bars (8 beats) in milliseconds
    final crossfadeMs = ((8 * 60 / bpm) * 1000).clamp(4000.0, 9000.0).toInt();

    final songDurationMs = outgoing.duration.inMilliseconds > 0
        ? outgoing.duration.inMilliseconds
        : 180000;

    final cueOutMs = math.max(0, songDurationMs - crossfadeMs);
    final cueInMs = 0;

    final cost = _calculateBlendCost(outgoing, incoming, scanOut, scanIn, DjEnergyFlow.steady);
    final desc = _describeHarmonicMatch(scanOut.camelotKey, scanIn.camelotKey);

    return DjTransitionCue(
      outgoingSong: outgoing,
      incomingSong: incoming,
      cueOut: Duration(milliseconds: cueOutMs),
      cueIn: Duration(milliseconds: cueInMs),
      crossfadeDuration: Duration(milliseconds: crossfadeMs),
      blendCost: cost,
      harmonicMatchDescription: desc,
    );
  }

  String _describeHarmonicMatch(String keyA, String keyB) {
    if (keyA == keyB) return 'Perfect harmonic key match ($keyA)';
    final clash = _calculateCamelotClash(keyA, keyB);
    if (clash <= 0.15) return 'Harmonic transition ($keyA -> $keyB)';
    if (clash <= 0.5) return 'Moderate key change ($keyA -> $keyB)';
    return 'Energy shift transition ($keyA -> $keyB)';
  }

  SongScanData _estimateDefaultScan(Song song) {
    return SongScanData(
      songId: song.playableId,
      integratedLufs: -14.0,
      truePeakDbfs: -1.0,
      bpm: 120.0,
      camelotKey: '8B',
      leadSilenceSeconds: 0.0,
      tailSilenceSeconds: 0.0,
      bestPartStartSeconds: 0.0,
      bestPartEndSeconds: 0.0,
      scannedAt: DateTime.now(),
    );
  }
}
