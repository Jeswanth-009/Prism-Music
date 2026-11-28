import 'dart:typed_data';
import 'audio_math.dart';

/// Result of onset, tempo, and climax detection.
class OnsetAnalysisResult {
  final double bpm;
  final List<double> onsetTimestamps; // in seconds
  final double bestPartStartSeconds;
  final double bestPartEndSeconds;

  const OnsetAnalysisResult({
    required this.bpm,
    required this.onsetTimestamps,
    required this.bestPartStartSeconds,
    required this.bestPartEndSeconds,
  });
}

/// Detects musical onsets, estimates BPM, and identifies high-energy song climaxes.
class OnsetDetector {
  final int windowSize;
  final int hopSize;
  final int sampleRate;

  OnsetDetector({
    this.windowSize = 2048,
    this.hopSize = 512,
    this.sampleRate = 44100,
  });

  /// Analyzes mono PCM audio samples to extract BPM, onset locations, and the climax segment.
  OnsetAnalysisResult analyze(Float32List samples) {
    if (samples.length < windowSize * 2) {
      return const OnsetAnalysisResult(
        bpm: 120.0,
        onsetTimestamps: [],
        bestPartStartSeconds: 0.0,
        bestPartEndSeconds: 0.0,
      );
    }

    final window = hannWindow(windowSize);
    final numFrames = (samples.length - windowSize) ~/ hopSize;
    if (numFrames <= 2) {
      return const OnsetAnalysisResult(
        bpm: 120.0,
        onsetTimestamps: [],
        bestPartStartSeconds: 0.0,
        bestPartEndSeconds: 0.0,
      );
    }

    final frameRate = sampleRate / hopSize;
    final halfWindow = windowSize ~/ 2;

    // Track spectral flux and frame energy
    final flux = Float64List(numFrames);
    final energy = Float64List(numFrames);
    Float64List prevMag = Float64List(halfWindow);

    for (int f = 0; f < numFrames; f++) {
      final offset = f * hopSize;
      final inputComplex = List<Complex>.generate(windowSize, (i) {
        final sample = samples[offset + i].toDouble() * window[i];
        return Complex(sample, 0.0);
      });

      final spectrum = fft(inputComplex);
      final currentMag = Float64List(halfWindow);
      double frameEnergy = 0.0;
      double currentFlux = 0.0;

      for (int k = 0; k < halfWindow; k++) {
        final mag = spectrum[k].magnitude;
        currentMag[k] = mag;
        frameEnergy += mag * mag;

        final diff = mag - prevMag[k];
        if (diff > 0.0) {
          currentFlux += diff;
        }
      }

      flux[f] = currentFlux;
      energy[f] = frameEnergy;
      prevMag = currentMag;
    }

    // Peak picking with local adaptive thresholding
    final onsets = <double>[];
    final filterRadius = (0.2 * frameRate).round().clamp(2, 10); // ~200ms radius

    for (int i = filterRadius; i < numFrames - filterRadius; i++) {
      double localSum = 0.0;
      for (int j = i - filterRadius; j <= i + filterRadius; j++) {
        localSum += flux[j];
      }
      final localAvg = localSum / (filterRadius * 2 + 1);
      final threshold = localAvg * 1.35; // 35% above local average

      // Local maximum check
      if (flux[i] > threshold &&
          flux[i] > flux[i - 1] &&
          flux[i] >= flux[i + 1]) {
        final timeSec = (i * hopSize) / sampleRate;
        onsets.add(timeSec);
      }
    }

    // Estimate BPM via autocorrelation of spectral flux
    final bpm = _estimateBpm(flux, frameRate);

    // Identify Climax / Best-Part (25-second window with maximum energy + flux)
    final (bestStart, bestEnd) = _findBestPart(
      energy: energy,
      flux: flux,
      numFrames: numFrames,
      frameRate: frameRate,
      totalDurationSec: samples.length / sampleRate,
    );

    return OnsetAnalysisResult(
      bpm: bpm,
      onsetTimestamps: onsets,
      bestPartStartSeconds: bestStart,
      bestPartEndSeconds: bestEnd,
    );
  }

  double _estimateBpm(Float64List novelty, double frameRate) {
    if (novelty.length < 50) return 120.0;

    // Tempo range: 60 to 200 BPM
    final minLag = (frameRate * 60.0 / 200.0).round().clamp(1, novelty.length - 1);
    final maxLag = (frameRate * 60.0 / 60.0).round().clamp(minLag + 1, novelty.length - 1);

    double bestCorr = -1.0;
    int bestLag = minLag;

    final n = novelty.length;
    for (int lag = minLag; lag <= maxLag; lag++) {
      double sum = 0.0;
      int count = 0;
      for (int i = 0; i < n - lag; i++) {
        sum += novelty[i] * novelty[i + lag];
        count++;
      }
      final corr = count > 0 ? sum / count : 0.0;
      if (corr > bestCorr) {
        bestCorr = corr;
        bestLag = lag;
      }
    }

    if (bestLag <= 0) return 120.0;

    double estimatedBpm = 60.0 * frameRate / bestLag;

    // Normalize octave: keep BPM between 70 and 160 if possible
    while (estimatedBpm < 70.0) {
      estimatedBpm *= 2.0;
    }
    while (estimatedBpm > 175.0) {
      estimatedBpm /= 2.0;
    }

    return (estimatedBpm * 10).roundToDouble() / 10.0;
  }

  (double, double) _findBestPart({
    required Float64List energy,
    required Float64List flux,
    required int numFrames,
    required double frameRate,
    required double totalDurationSec,
  }) {
    if (totalDurationSec <= 30.0) {
      return (0.0, totalDurationSec);
    }

    // Default target best-part duration: 25 seconds
    const targetDurationSec = 25.0;
    final windowFrames = (targetDurationSec * frameRate).round().clamp(10, numFrames);

    // Calculate moving sum of combined normalized energy and flux
    double currentWindowScore = 0.0;
    for (int i = 0; i < windowFrames; i++) {
      currentWindowScore += energy[i] + flux[i] * 2.0;
    }

    double maxScore = currentWindowScore;
    int bestStartFrame = 0;

    // Slide across frames (skip first 10% intro to avoid false climax on quiet intros)
    final maxStart = numFrames > windowFrames ? numFrames - windowFrames : 0;
    final startOffset = (numFrames * 0.10).round().clamp(0, maxStart);
    for (int i = 0; i < startOffset && i + windowFrames < numFrames; i++) {
      currentWindowScore += (energy[i + windowFrames] + flux[i + windowFrames] * 2.0) -
          (energy[i] + flux[i] * 2.0);
    }

    maxScore = currentWindowScore;
    bestStartFrame = startOffset;

    for (int i = startOffset; i + windowFrames < numFrames; i++) {
      currentWindowScore += (energy[i + windowFrames] + flux[i + windowFrames] * 2.0) -
          (energy[i] + flux[i] * 2.0);
      if (currentWindowScore > maxScore) {
        maxScore = currentWindowScore;
        bestStartFrame = i + 1;
      }
    }

    final startSec = (bestStartFrame / frameRate).clamp(0.0, totalDurationSec);
    final endSec = (startSec + targetDurationSec).clamp(startSec, totalDurationSec);

    return (
      (startSec * 10).roundToDouble() / 10.0,
      (endSec * 10).roundToDouble() / 10.0,
    );
  }
}
