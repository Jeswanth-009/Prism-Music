import 'dart:math' as math;
import 'dart:typed_data';

/// Result of lead-in and tail silence detection.
class SilenceAnalysisResult {
  final double leadSilenceSeconds;
  final double tailSilenceSeconds;
  final int trimStartSample;
  final int trimEndSample;

  const SilenceAnalysisResult({
    required this.leadSilenceSeconds,
    required this.tailSilenceSeconds,
    required this.trimStartSample,
    required this.trimEndSample,
  });

  @override
  String toString() =>
      'SilenceAnalysisResult(lead: ${leadSilenceSeconds.toStringAsFixed(2)}s, tail: ${tailSilenceSeconds.toStringAsFixed(2)}s)';
}

/// Detects lead-in and tail silence boundaries in audio streams.
class SilenceDetector {
  final int sampleRate;
  final double thresholdDbfs;

  SilenceDetector({
    this.sampleRate = 44100,
    this.thresholdDbfs = -50.0,
  });

  /// Analyzes mono PCM audio samples to locate lead-in and tail silence boundaries.
  SilenceAnalysisResult detect(Float32List samples) {
    if (samples.isEmpty) {
      return const SilenceAnalysisResult(
        leadSilenceSeconds: 0.0,
        tailSilenceSeconds: 0.0,
        trimStartSample: 0,
        trimEndSample: 0,
      );
    }

    // Convert dBFS threshold to linear amplitude threshold
    final linearThreshold = math.pow(10.0, thresholdDbfs / 20.0).toDouble();

    // 50ms block for RMS measurement to avoid single sample zero-crossings
    final blockSize = (0.050 * sampleRate).round().clamp(16, 2048);
    final totalSamples = samples.length;

    int startSample = 0;
    bool foundActive = false;
    for (int i = 0; i + blockSize <= totalSamples; i += blockSize) {
      double sumSquares = 0.0;
      for (int j = 0; j < blockSize; j++) {
        final s = samples[i + j];
        sumSquares += s * s;
      }
      final rms = math.sqrt(sumSquares / blockSize);
      if (rms >= linearThreshold) {
        startSample = i;
        foundActive = true;
        break;
      }
    }

    if (!foundActive) {
      final totalSeconds = (totalSamples / sampleRate * 100).roundToDouble() / 100.0;
      return SilenceAnalysisResult(
        leadSilenceSeconds: totalSeconds,
        tailSilenceSeconds: 0.0,
        trimStartSample: totalSamples,
        trimEndSample: totalSamples,
      );
    }

    int endSample = totalSamples;
    for (int i = totalSamples - blockSize; i >= 0; i -= blockSize) {
      double sumSquares = 0.0;
      for (int j = 0; j < blockSize; j++) {
        final s = samples[i + j];
        sumSquares += s * s;
      }
      final rms = math.sqrt(sumSquares / blockSize);
      if (rms >= linearThreshold) {
        endSample = i + blockSize;
        break;
      }
    }

    if (endSample < startSample) {
      endSample = startSample;
    }

    final leadSilenceSeconds = (startSample / sampleRate * 100).roundToDouble() / 100.0;
    final tailSilenceSeconds = ((totalSamples - endSample) / sampleRate * 100).roundToDouble() / 100.0;

    return SilenceAnalysisResult(
      leadSilenceSeconds: leadSilenceSeconds,
      tailSilenceSeconds: tailSilenceSeconds,
      trimStartSample: startSample,
      trimEndSample: endSample,
    );
  }
}
