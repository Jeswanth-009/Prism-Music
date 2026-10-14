import '../../domain/entities/song.dart';

/// Contract for metadata providers (YouTube Music, Spotify, JioSaavn).
/// Allows querying search, albums, artists, and playlists without binding to stream extraction.
abstract class MusicMetadataProvider {
  /// Unique provider identifier.
  String get providerName;

  /// Associated music source enum.
  MusicSource get source;

  /// Search for songs matching [query].
  Future<List<Song>> searchSongs(String query, {int limit = 20});

  /// Retrieve track details for a specific [id].
  Future<Song?> getSongById(String id);

  /// Retrieve related or recommended tracks seeded by [song].
  Future<List<Song>> getRelatedSongs(Song song, {int limit = 20});
}
