import '../../domain/entities/song.dart';
import '../../domain/entities/stream_info.dart';

/// Result of evaluating whether a candidate audio stream is the exact same recording.
class VerificationResult {
  final bool isVerified;
  final double confidence;
  final int durationDeltaSeconds;
  final String reason;

  const VerificationResult({
    required this.isVerified,
    required this.confidence,
    required this.durationDeltaSeconds,
    required this.reason,
  });

  @override
  String toString() =>
      'VerificationResult(verified: $isVerified, confidence: ${(confidence * 100).toStringAsFixed(0)}%, delta: ${durationDeltaSeconds}s, reason: $reason)';
}

/// Verifies whether candidate audio stream/recording matches the reference song
/// based on duration tolerance, metadata token similarity, and audio container validation.
class VerifiedRecordingVerifier {
  /// Maximum permitted duration discrepancy between recordings (seconds).
  static const int maxDurationDeltaSeconds = 4;

  /// Minimum title/artist token similarity score (0.0 - 1.0).
  static const double minConfidenceThreshold = 0.75;

  /// Verifies a candidate stream against the playing song reference.
  static VerificationResult verify({
    required Song referenceSong,
    required StreamInfo candidateStream,
    String? candidateTitle,
    String? candidateArtist,
    Duration? candidateDuration,
  }) {
    // 1. Duration check
    int durationDelta = 0;
    final effectiveDuration = candidateDuration ??
        (candidateStream.contentLength != null && candidateStream.bitrate > 0
            ? Duration(
                seconds: (candidateStream.contentLength! * 8) ~/
                    (candidateStream.bitrate * 1000),
              )
            : null);

    if (effectiveDuration != null && referenceSong.duration > Duration.zero) {
      durationDelta =
          (referenceSong.duration.inSeconds - effectiveDuration.inSeconds).abs();
      if (durationDelta > maxDurationDeltaSeconds) {
        return VerificationResult(
          isVerified: false,
          confidence: 0.3,
          durationDeltaSeconds: durationDelta,
          reason:
              'Duration difference of ${durationDelta}s exceeds ${maxDurationDeltaSeconds}s tolerance',
        );
      }
    }

    // 2. Format & audio validity
    final container = candidateStream.container.toLowerCase();
    final codec = candidateStream.codec.toLowerCase();
    final hasValidCodec = candidateStream.isAudioOnly ||
        ['m4a', 'mp4', 'webm', 'opus', 'mp3', 'aac', 'ogg']
            .contains(container) ||
        codec.contains('mp4a') ||
        codec.contains('opus') ||
        codec.contains('aac');

    if (!hasValidCodec && candidateStream.url.isEmpty) {
      return VerificationResult(
        isVerified: false,
        confidence: 0.0,
        durationDeltaSeconds: durationDelta,
        reason: 'Stream URL is empty or unplayable audio container',
      );
    }

    // 3. Token similarity calculation
    double tokenScore = candidateStream.matchConfidence ?? 0.85;
    if (candidateTitle != null && candidateTitle.isNotEmpty) {
      tokenScore = calculateTokenSimilarity(
        '${referenceSong.title} ${referenceSong.artist}',
        '$candidateTitle ${candidateArtist ?? ""}',
      );
    }

    final isVerified = tokenScore >= minConfidenceThreshold &&
        durationDelta <= maxDurationDeltaSeconds;

    return VerificationResult(
      isVerified: isVerified,
      confidence: tokenScore,
      durationDeltaSeconds: durationDelta,
      reason: isVerified
          ? 'Verified recording match (${(tokenScore * 100).toStringAsFixed(0)}% confidence, ${durationDelta}s delta)'
          : 'Low metadata similarity match (${(tokenScore * 100).toStringAsFixed(0)}%)',
    );
  }

  /// Calculates token overlap using Jaccard index between two string sets.
  static double calculateTokenSimilarity(String s1, String s2) {
    final tokens1 = _tokenize(s1);
    final tokens2 = _tokenize(s2);
    if (tokens1.isEmpty || tokens2.isEmpty) return 0.5;

    final intersection = tokens1.intersection(tokens2);
    final union = tokens1.union(tokens2);
    return union.isEmpty ? 0.0 : intersection.length / union.length;
  }

  static Set<String> _tokenize(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1 && !_stopWords.contains(t))
        .toSet();
  }

  static const _stopWords = {
    'the',
    'a',
    'an',
    'and',
    'or',
    'feat',
    'ft',
    'official',
    'audio',
    'video',
    'music',
    'song',
    'lyric',
    'lyrics',
    'hd',
    '4k',
    'remix',
    'version',
  };
}
