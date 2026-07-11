import 'package:equatable/equatable.dart';

import 'song.dart';

/// A single recorded play of a song (with its timestamp).
class HistoryEntry extends Equatable {
  final Song song;
  final DateTime playedAt;

  const HistoryEntry({required this.song, required this.playedAt});

  @override
  List<Object?> get props => [song, playedAt];
}

/// Aggregated listening statistics derived from the play history.
class ListeningStats extends Equatable {
  /// Total number of plays recorded.
  final int totalPlays;

  /// Sum of the durations of all played tracks (best-effort listening time).
  final Duration totalListeningTime;

  /// The most frequently played song.
  final Song? mostPlayedSong;

  /// How many times [mostPlayedSong] was played.
  final int mostPlayedCount;

  /// The most common genre across plays (null if unknown).
  final String? topGenre;

  /// How many plays had [topGenre].
  final int topGenreCount;

  /// The most played artist.
  final String? topArtist;

  /// How many plays were by [topArtist].
  final int topArtistCount;

  /// Number of distinct songs played.
  final int uniqueSongs;

  /// Timestamp of the first recorded play.
  final DateTime? firstPlayed;

  /// Timestamp of the most recent play.
  final DateTime? lastPlayed;

  const ListeningStats({
    this.totalPlays = 0,
    this.totalListeningTime = Duration.zero,
    this.mostPlayedSong,
    this.mostPlayedCount = 0,
    this.topGenre,
    this.topGenreCount = 0,
    this.topArtist,
    this.topArtistCount = 0,
    this.uniqueSongs = 0,
    this.firstPlayed,
    this.lastPlayed,
  });

  bool get isEmpty =>
      totalPlays == 0 &&
      mostPlayedSong == null &&
      topGenre == null &&
      topArtist == null;

  @override
  List<Object?> get props => [
        totalPlays,
        totalListeningTime,
        mostPlayedSong,
        mostPlayedCount,
        topGenre,
        topGenreCount,
        topArtist,
        topArtistCount,
        uniqueSongs,
        firstPlayed,
        lastPlayed,
      ];
}
