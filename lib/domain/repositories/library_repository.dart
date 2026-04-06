import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../entities/entities.dart';

/// Abstract repository for local library operations
/// Handles user's local music library (likes, playlists, history)
abstract class LibraryRepository {
  // ============ LIKED SONGS ============

  /// Get all liked songs
  Future<Either<Failure, List<Song>>> getLikedSongs();

  /// Add a song to liked songs
  Future<Either<Failure, void>> likeSong(Song song);

  /// Remove a song from liked songs
  Future<Either<Failure, void>> unlikeSong(String songId);

  /// Check if a song is liked
  Future<bool> isSongLiked(String songId);

  // ============ PLAYLISTS ============

  /// Get all user-created playlists
  Future<Either<Failure, List<Playlist>>> getUserPlaylists();

  /// Create a new playlist
  Future<Either<Failure, Playlist>> createPlaylist(
    String name, {
    String? description,
  });

  /// Delete a playlist
  Future<Either<Failure, void>> deletePlaylist(String playlistId);

  /// Update playlist details
  Future<Either<Failure, Playlist>> updatePlaylist(
    String playlistId, {
    String? name,
    String? description,
  });

  /// Add a song to a playlist
  Future<Either<Failure, void>> addSongToPlaylist(
    String playlistId,
    Song song,
  );

  /// Remove a song from a playlist
  Future<Either<Failure, void>> removeSongFromPlaylist(
    String playlistId,
    String songId,
  );

  /// Reorder songs in a playlist
  Future<Either<Failure, void>> reorderPlaylistSongs(
    String playlistId,
    int oldIndex,
    int newIndex,
  );

  // ============ LISTENING HISTORY ============

  /// Get listening history
  Future<Either<Failure, List<Song>>> getListeningHistory({
    int limit = 50,
    DateTime? since,
  });

  /// Add a song to listening history
  Future<Either<Failure, void>> addToHistory(Song song);

  /// Clear listening history
  Future<Either<Failure, void>> clearHistory();

  /// Get recently played songs
  Future<Either<Failure, List<Song>>> getRecentlyPlayed({
    int limit = 20,
  });

  // ============ DOWNLOADS ============

  /// Get all downloaded songs
  Future<Either<Failure, List<Song>>> getDownloadedSongs();

  /// Download a song for offline playback
  Future<Either<Failure, String>> downloadSong(
    Song song,
    String streamUrl, {
    void Function(double progress)? onProgress,
  });

  /// Delete a downloaded song
  Future<Either<Failure, void>> deleteDownload(String songId);

  /// Check if a song is downloaded
  Future<bool> isSongDownloaded(String songId);

  /// Get the local file path for a downloaded song
  Future<String?> getDownloadedSongPath(String songId);

  // ============ CACHED METADATA ============

  /// Cache song metadata
  Future<Either<Failure, void>> cacheSong(Song song);

  /// Get cached song by ID
  Future<Song?> getCachedSong(String songId);

  /// Clear all cached metadata
  Future<Either<Failure, void>> clearCache();
}
