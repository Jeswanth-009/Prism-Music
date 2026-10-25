import 'package:equatable/equatable.dart';
import 'song.dart';

/// Levels of match confidence for imported playlist tracks.
enum ImportConfidenceLevel {
  /// Perfect or near-perfect match (>= 90%)
  exact,

  /// High confidence match (>= 75%)
  high,

  /// Uncertain match that might be a live/remix cut, cover, or partial title match (50% - 74%)
  uncertain,

  /// Could not find a reliable candidate (< 50%)
  unmatched,
}

/// Represents an imported track with its matched audio stream candidate,
/// match confidence score, status, and manual correction alternatives.
class ImportPreviewItem extends Equatable {
  /// The original source track (from Spotify, YouTube, or file).
  final Song sourceTrack;

  /// The matched playable stream candidate (null if unmatched).
  final Song? matchedSong;

  /// Match confidence score from 0.0 to 1.0.
  final double confidenceScore;

  /// Categorized confidence level for UI badge display.
  final ImportConfidenceLevel confidenceLevel;

  /// Whether the user has excluded this track from the final imported playlist.
  final bool isExcluded;

  /// Alternative search candidates available for quick manual selection.
  final List<Song> candidates;

  const ImportPreviewItem({
    required this.sourceTrack,
    this.matchedSong,
    this.confidenceScore = 0.0,
    required this.confidenceLevel,
    this.isExcluded = false,
    this.candidates = const [],
  });

  /// Factory that calculates confidence level from score or matched track properties.
  factory ImportPreviewItem.fromMatch({
    required Song sourceTrack,
    Song? matchedSong,
    double? confidence,
    List<Song> candidates = const [],
    bool isExcluded = false,
  }) {
    final score = confidence ??
        matchedSong?.matchConfidence ??
        (matchedSong != null ? 0.85 : 0.0);

    final ImportConfidenceLevel level;
    if (matchedSong == null || score < 0.50) {
      level = ImportConfidenceLevel.unmatched;
    } else if (score >= 0.90) {
      level = ImportConfidenceLevel.exact;
    } else if (score >= 0.75) {
      level = ImportConfidenceLevel.high;
    } else {
      level = ImportConfidenceLevel.uncertain;
    }

    return ImportPreviewItem(
      sourceTrack: sourceTrack,
      matchedSong: matchedSong,
      confidenceScore: score.clamp(0.0, 1.0),
      confidenceLevel: level,
      isExcluded: isExcluded,
      candidates: candidates,
    );
  }

  /// Confidence percentage rounded to an integer (0 to 100).
  int get confidencePercent => (confidenceScore * 100).round();

  /// Whether this item needs user review before confirming.
  bool get needsReview =>
      confidenceLevel == ImportConfidenceLevel.uncertain ||
      confidenceLevel == ImportConfidenceLevel.unmatched;

  ImportPreviewItem copyWith({
    Song? sourceTrack,
    Song? matchedSong,
    bool clearMatchedSong = false,
    double? confidenceScore,
    ImportConfidenceLevel? confidenceLevel,
    bool? isExcluded,
    List<Song>? candidates,
  }) {
    final newMatched =
        clearMatchedSong ? null : (matchedSong ?? this.matchedSong);
    final newScore = (confidenceScore ?? this.confidenceScore).clamp(0.0, 1.0);
    final newLevel = confidenceLevel ??
        (newMatched == null || newScore < 0.50
            ? ImportConfidenceLevel.unmatched
            : (newScore >= 0.90
                ? ImportConfidenceLevel.exact
                : (newScore >= 0.75
                    ? ImportConfidenceLevel.high
                    : ImportConfidenceLevel.uncertain)));

    return ImportPreviewItem(
      sourceTrack: sourceTrack ?? this.sourceTrack,
      matchedSong: newMatched,
      confidenceScore: newScore,
      confidenceLevel: newLevel,
      isExcluded: isExcluded ?? this.isExcluded,
      candidates: candidates ?? this.candidates,
    );
  }

  @override
  List<Object?> get props => [
        sourceTrack,
        matchedSong,
        confidenceScore,
        confidenceLevel,
        isExcluded,
        candidates,
      ];
}
