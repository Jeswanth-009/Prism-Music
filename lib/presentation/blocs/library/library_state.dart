import 'package:equatable/equatable.dart';
import '../../../domain/entities/entities.dart';

/// Library state status
enum LibraryStatus {
  initial,
  loading,
  success,
  importing,
  error,
}

/// Represents the complete library state
class LibraryState extends Equatable {
  /// Current status
  final LibraryStatus status;

  /// Liked songs
  final List<Song> likedSongs;

  /// User playlists
  final List<Playlist> playlists;

  /// Listening history
  final List<Song> history;

  /// Recently played songs
  final List<Song> recentlyPlayed;

  /// Listening history entries with timestamps
  final List<HistoryEntry> historyEntries;

  /// Aggregated listening statistics
  final ListeningStats? stats;

  /// Downloaded songs
  final List<Song> downloads;

  /// Set of liked song IDs for quick lookup
  final Set<String> likedSongIds;

  /// Set of downloaded song IDs for quick lookup
  final Set<String> downloadedSongIds;

  /// Import progress (0.0 to 1.0) during playlist import
  final double? importProgress;

  /// Current track index being matched during import
  final int? importCurrentTrack;

  /// Total tracks being matched during import
  final int? importTotalTracks;

  /// Most recent import outcome (contains matched and unmatched tracks)
  final ImportPlaylistResult? lastImportResult;

  /// Favorite artists
  final List<Artist> favoriteArtists;

  /// Set of favorite artist IDs for quick lookup
  final Set<String> favoriteArtistIds;

  /// Error message if status is error
  final String? errorMessage;

  const LibraryState({
    this.status = LibraryStatus.initial,
    this.likedSongs = const [],
    this.playlists = const [],
    this.history = const [],
    this.recentlyPlayed = const [],
    this.historyEntries = const [],
    this.stats,
    this.downloads = const [],
    this.likedSongIds = const {},
    this.downloadedSongIds = const {},
    this.favoriteArtists = const [],
    this.favoriteArtistIds = const {},
    this.importProgress,
    this.importCurrentTrack,
    this.importTotalTracks,
    this.lastImportResult,
    this.errorMessage,
  });

  /// Check if a song is liked
  bool isSongLiked(String songId) => likedSongIds.contains(songId);

  /// Check if a song is downloaded
  bool isSongDownloaded(String songId) => downloadedSongIds.contains(songId);

  /// Check if an artist is favorited
  bool isArtistFavorite(String artistId) => favoriteArtistIds.contains(artistId);

  LibraryState copyWith({
    LibraryStatus? status,
    List<Song>? likedSongs,
    List<Playlist>? playlists,
    List<Song>? history,
    List<Song>? recentlyPlayed,
    List<HistoryEntry>? historyEntries,
    ListeningStats? stats,
    List<Song>? downloads,
    Set<String>? likedSongIds,
    Set<String>? downloadedSongIds,
    List<Artist>? favoriteArtists,
    Set<String>? favoriteArtistIds,
    double? importProgress,
    int? importCurrentTrack,
    int? importTotalTracks,
    ImportPlaylistResult? lastImportResult,
    String? errorMessage,
  }) {
    return LibraryState(
      status: status ?? this.status,
      likedSongs: likedSongs ?? this.likedSongs,
      playlists: playlists ?? this.playlists,
      history: history ?? this.history,
      recentlyPlayed: recentlyPlayed ?? this.recentlyPlayed,
      historyEntries: historyEntries ?? this.historyEntries,
      stats: stats ?? this.stats,
      downloads: downloads ?? this.downloads,
      likedSongIds: likedSongIds ?? this.likedSongIds,
      downloadedSongIds: downloadedSongIds ?? this.downloadedSongIds,
      favoriteArtists: favoriteArtists ?? this.favoriteArtists,
      favoriteArtistIds: favoriteArtistIds ?? this.favoriteArtistIds,
      importProgress: importProgress ?? this.importProgress,
      importCurrentTrack: importCurrentTrack ?? this.importCurrentTrack,
      importTotalTracks: importTotalTracks ?? this.importTotalTracks,
      lastImportResult: lastImportResult ?? this.lastImportResult,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        likedSongs,
        playlists,
        history,
        recentlyPlayed,
        historyEntries,
        stats,
        downloads,
        likedSongIds,
        downloadedSongIds,
        favoriteArtists,
        favoriteArtistIds,
        importProgress,
        importCurrentTrack,
        importTotalTracks,
        lastImportResult,
        errorMessage,
      ];
}
