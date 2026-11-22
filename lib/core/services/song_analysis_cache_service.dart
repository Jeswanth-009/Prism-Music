import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../dsp/ebu_r128.dart';
import '../dsp/key_estimator.dart';
import '../dsp/onset_detector.dart';
import '../dsp/silence_detector.dart';
import '../models/song_scan_data.dart';

/// Service responsible for scanning audio buffers and caching acoustic metadata
/// (LUFS, Peak, BPM, Key, Silences, Climax drop) in a dedicated Hive box.
class SongAnalysisCacheService {
  static const String _boxName = 'song_scan_cache';
  Box? _box;

  SongAnalysisCacheService({Box? box}) : _box = box;

  Future<Box> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box(_boxName);
    } else {
      _box = await Hive.openBox(_boxName);
    }
    return _box!;
  }

  /// Retrieves cached scan data for [songId] if available.
  Future<SongScanData?> getScanData(String songId) async {
    try {
      final box = await _getBox();
      final raw = box.get(songId);
      if (raw == null) return null;
      if (raw is Map) {
        return SongScanData.fromMap(raw);
      }
      return null;
    } catch (e) {
      debugPrint('SongAnalysisCacheService.getScanData error: $e');
      return null;
    }
  }

  /// Saves physical scan results for [data.songId].
  Future<void> saveScanData(SongScanData data) async {
    try {
      final box = await _getBox();
      await box.put(data.songId, data.toMap());
    } catch (e) {
      debugPrint('SongAnalysisCacheService.saveScanData error: $e');
    }
  }

  /// Checks if scan data exists in cache for [songId].
  Future<bool> hasScanData(String songId) async {
    try {
      final box = await _getBox();
      return box.containsKey(songId);
    } catch (_) {
      return false;
    }
  }

  /// Removes cached scan data for [songId].
  Future<void> removeScanData(String songId) async {
    try {
      final box = await _getBox();
      await box.delete(songId);
    } catch (_) {}
  }

  /// Clears all cached scan records.
  Future<void> clearAll() async {
    try {
      final box = await _getBox();
      await box.clear();
    } catch (_) {}
  }

  /// Performs full pure-Dart acoustic scan on mono PCM samples.
  SongScanData analyzePcm(
    String songId,
    Float32List monoSamples, {
    int sampleRate = 44100,
  }) {
    final loudnessMeter = EbuR128LoudnessMeter(sampleRate: sampleRate);
    final onsetDetector = OnsetDetector(sampleRate: sampleRate);
    final keyEstimator = KeyEstimator(sampleRate: sampleRate);
    final silenceDetector = SilenceDetector(sampleRate: sampleRate);

    final lufs = loudnessMeter.calculateIntegratedLufs(monoSamples);
    final truePeak = loudnessMeter.calculateTruePeakDbfs(monoSamples);
    final onsetResult = onsetDetector.analyze(monoSamples);
    final keyResult = keyEstimator.estimate(monoSamples);
    final silenceResult = silenceDetector.detect(monoSamples);

    return SongScanData(
      songId: songId,
      integratedLufs: lufs,
      truePeakDbfs: truePeak,
      bpm: onsetResult.bpm,
      camelotKey: keyResult.camelotCode,
      leadSilenceSeconds: silenceResult.leadSilenceSeconds,
      tailSilenceSeconds: silenceResult.tailSilenceSeconds,
      bestPartStartSeconds: onsetResult.bestPartStartSeconds,
      bestPartEndSeconds: onsetResult.bestPartEndSeconds,
      scannedAt: DateTime.now(),
    );
  }
}
