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

  /// Downloaded songs
  final List<Song> downloads;

  /// Set of liked song IDs for quick lookup
  final Set<String> likedSongIds;

  /// Set of downloaded song IDs for quick lookup
  final Set<String> downloadedSongIds;

  /// Import progress (0.0 to 1.0) during playlist import
  final double? importProgress;

  /// Error message if status is error
  final String? errorMessage;

  const LibraryState({
    this.status = LibraryStatus.initial,
    this.likedSongs = const [],
    this.playlists = const [],
    this.history = const [],
    this.recentlyPlayed = const [],
    this.downloads = const [],
    this.likedSongIds = const {},
    this.downloadedSongIds = const {},
    this.importProgress,
    this.errorMessage,
  });

  /// Check if a song is liked
  bool isSongLiked(String songId) => likedSongIds.contains(songId);

  /// Check if a song is downloaded
  bool isSongDownloaded(String songId) => downloadedSongIds.contains(songId);

  LibraryState copyWith({
    LibraryStatus? status,
    List<Song>? likedSongs,
    List<Playlist>? playlists,
    List<Song>? history,
    List<Song>? recentlyPlayed,
    List<Song>? downloads,
    Set<String>? likedSongIds,
    Set<String>? downloadedSongIds,
    double? importProgress,
    String? errorMessage,
  }) {
    return LibraryState(
      status: status ?? this.status,
      likedSongs: likedSongs ?? this.likedSongs,
      playlists: playlists ?? this.playlists,
      history: history ?? this.history,
      recentlyPlayed: recentlyPlayed ?? this.recentlyPlayed,
      downloads: downloads ?? this.downloads,
      likedSongIds: likedSongIds ?? this.likedSongIds,
      downloadedSongIds: downloadedSongIds ?? this.downloadedSongIds,
      importProgress: importProgress ?? this.importProgress,
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
        downloads,
        likedSongIds,
        downloadedSongIds,
        importProgress,
        errorMessage,
      ];
}
