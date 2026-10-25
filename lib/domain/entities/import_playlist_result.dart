import 'package:equatable/equatable.dart';
import 'import_preview_item.dart';
import 'playlist.dart';
import 'song.dart';

/// Structured outcome of importing an external playlist (Spotify, YouTube, etc.).
/// Carries the persisted playlist, matched tracks, unmatched tracks, and
/// granular confidence-scored preview items for review and manual correction.
class ImportPlaylistResult extends Equatable {
  /// The saved playlist entity containing matched tracks.
  final Playlist playlist;

  /// Tracks successfully converted and linked to playable streams.
  final List<Song> matchedTracks;

  /// Tracks from the source playlist that could not be matched with high confidence.
  final List<Song> unmatchedTracks;

  /// Detailed preview items with match confidence scores and alternative candidates.
  final List<ImportPreviewItem>? previewItems;

  /// Total tracks retrieved from the source playlist.
  final int totalSourceTracks;

  /// Whether the user aborted the import midway.
  final bool wasCancelled;

  /// Whether fallback embed scraping was used (e.g. capped at 100 tracks).
  final bool isEmbedFallback;

  const ImportPlaylistResult({
    required this.playlist,
    required this.matchedTracks,
    required this.unmatchedTracks,
    required this.totalSourceTracks,
    this.previewItems,
    this.wasCancelled = false,
    this.isEmbedFallback = false,
  });

  /// Match success rate from 0.0 to 1.0.
  double get matchRate =>
      totalSourceTracks > 0 ? matchedTracks.length / totalSourceTracks : 0.0;

  /// Match percentage rounded to an integer (0 to 100).
  int get matchPercent => (matchRate * 100).round();

  /// Count of tracks successfully matched.
  int get matchedCount => matchedTracks.length;

  /// Count of tracks that failed matching.
  int get unmatchedCount => unmatchedTracks.length;

  /// Whether all source tracks were successfully matched.
  bool get isFullyMatched =>
      totalSourceTracks > 0 && unmatchedTracks.isEmpty && !wasCancelled;

  /// Returns granular preview items, generating them dynamically if not explicitly supplied.
  List<ImportPreviewItem> get effectivePreviewItems {
    if (previewItems != null && previewItems!.isNotEmpty) {
      return previewItems!;
    }
    final items = <ImportPreviewItem>[];
    for (final song in matchedTracks) {
      items.add(ImportPreviewItem.fromMatch(
        sourceTrack: song,
        matchedSong: song,
        confidence: song.matchConfidence ?? 0.88,
      ));
    }
    for (final song in unmatchedTracks) {
      items.add(ImportPreviewItem.fromMatch(
        sourceTrack: song,
        matchedSong: null,
        confidence: 0.0,
      ));
    }
    return items;
  }

  @override
  List<Object?> get props => [
        playlist,
        matchedTracks,
        unmatchedTracks,
        previewItems,
        totalSourceTracks,
        wasCancelled,
        isEmbedFallback,
      ];
}
