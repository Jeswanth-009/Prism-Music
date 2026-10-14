import 'package:equatable/equatable.dart';
import 'playlist.dart';
import 'song.dart';

/// Structured outcome of importing an external playlist (Spotify, YouTube, etc.).
/// Carries the persisted playlist, matched tracks, and any unmatched tracks
/// so the user can review what could not be resolved.
class ImportPlaylistResult extends Equatable {
  /// The saved playlist entity containing matched tracks.
  final Playlist playlist;

  /// Tracks successfully converted and linked to playable streams.
  final List<Song> matchedTracks;

  /// Tracks from the source playlist that could not be matched with high confidence.
  final List<Song> unmatchedTracks;

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

  @override
  List<Object?> get props => [
        playlist,
        matchedTracks,
        unmatchedTracks,
        totalSourceTracks,
        wasCancelled,
        isEmbedFallback,
      ];
}
