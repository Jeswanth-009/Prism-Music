import 'dart:math' as math;
import '../../domain/entities/song.dart';
import '../models/song_scan_data.dart';
import 'settings_service.dart';

enum NormalizationTarget {
  balanced(-14.0), // Standard streaming target (Spotify / YouTube Music)
  quiet(-18.0),    // ReplayGain audiophile target (more dynamic range)
  loud(-11.0);     // Higher loudness for noisy environments

  final double lufs;
  const NormalizationTarget(this.lufs);

  static NormalizationTarget fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'quiet':
        return NormalizationTarget.quiet;
      case 'loud':
        return NormalizationTarget.loud;
      case 'balanced':
      default:
        return NormalizationTarget.balanced;
    }
  }
}

/// Service that computes loudness normalization / ReplayGain amplitude multipliers
/// to ensure consistent volume across tracks from diverse music sources.
class AudioNormalizationService {
  AudioNormalizationService._();
  static final AudioNormalizationService instance = AudioNormalizationService._();

  /// Estimates the integrated loudness in LUFS of a song based on its platform source.
  double estimateTrackLufs(Song song) {
    switch (song.source) {
      case MusicSource.youtube:
      case MusicSource.youtubeMusic:
        return -14.0; // Standard YouTube mastered loudness
      case MusicSource.jiosaavn:
        return -11.5; // Indian streaming tracks typically mastered hotter
      case MusicSource.spotify:
      case MusicSource.appleMusic:
        return -14.0;
      case MusicSource.local:
        return -16.0; // Uncompressed/CD rip dynamic range
      case MusicSource.unknown:
        return -14.0;
    }
  }

  /// Computes the linear volume multiplier (gain factor) to apply to playback.
  ///
  /// When [scanData] or [measuredLufs] is provided, uses exact ITU-R BS.1770-4
  /// integrated loudness and true-peak headroom constraints rather than source heuristics.
  double computeGainFactor(
    Song song, {
    SongScanData? scanData,
    double? measuredLufs,
    bool? enabled,
    String? targetMode,
    double? preampDb,
  }) {
    final settings = SettingsService.instance;
    final isEnabled = enabled ?? settings.audioNormalizationEnabled;
    if (!isEnabled) return 1.0;

    final target = NormalizationTarget.fromString(targetMode ?? settings.audioNormalizationTarget);
    final preamp = preampDb ?? settings.audioNormalizationPreampDb;
    final trackLufs = measuredLufs ?? scanData?.integratedLufs ?? estimateTrackLufs(song);

    // Gain in decibels = target LUFS - track LUFS + preamp dB
    double gainDb = (target.lufs - trackLufs) + preamp;

    // Peak clipping prevention: if true peak is known, don't allow gain to exceed headroom
    if (scanData != null && scanData.truePeakDbfs > -50.0) {
      final maxSafeGainDb = -scanData.truePeakDbfs - 0.2; // 0.2 dB true-peak safety margin
      if (gainDb > maxSafeGainDb) {
        gainDb = maxSafeGainDb;
      }
    }

    // Linear amplitude factor = 10 ^ (gainDb / 20)
    final factor = math.pow(10, gainDb / 20.0).toDouble();

    // Prevent hard digital clipping: clamp between 0.2 and 1.25
    return factor.clamp(0.2, 1.25);
  }
}
