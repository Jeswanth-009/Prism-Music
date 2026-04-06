import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../entities/entities.dart';

/// Abstract repository for music operations
/// This defines the contract for fetching music from multiple sources
/// (YouTube Music, Spotify metadata, local storage)
abstract class MusicRepository {
  // ============ SEARCH OPERATIONS ============
  
  /// Search for songs across all available sources
  /// Uses YouTube Music for audio, enhanced with Spotify metadata when available
  Future<Either<Failure, List<Song>>> searchSongs(
    String query, {
    int limit = 20,
    String? filter,
  });

  /// Search for artists
  Future<Either<Failure, List<Artist>>> searchArtists(
    String query, {
    int limit = 20,
  });

  /// Search for albums
  Future<Either<Failure, List<Album>>> searchAlbums(
    String query, {
    int limit = 20,
  });

  /// Search for playlists
  Future<Either<Failure, List<Playlist>>> searchPlaylists(
    String query, {
    int limit = 20,
  });

  /// Universal search - returns all types
  Future<Either<Failure, SearchResults>> searchAll(
    String query, {
    int limit = 10,
  });

  // ============ STREAM OPERATIONS ============

  /// Get the stream URL for a song
  /// Implements quality fallback: High -> Medium -> Low
  /// If high quality stream buffers for > 3s, auto-switch to medium
  Future<Either<Failure, StreamInfo>> getStreamUrl(
    String videoId, {
    AudioQuality preferredQuality = AudioQuality.high,
  });

  /// Get multiple stream options for a song (for quality selection)
  Future<Either<Failure, List<StreamInfo>>> getAvailableStreams(String videoId);

  // ============ CONTENT FETCHING ============

  /// Get song details by ID
  Future<Either<Failure, Song>> getSongDetails(String songId);

  /// Get artist details with their top songs
  Future<Either<Failure, ArtistDetails>> getArtistDetails(String artistId);

  /// Get album details with all tracks
  Future<Either<Failure, Album>> getAlbumDetails(String albumId);

  /// Get playlist details with all tracks
  Future<Either<Failure, Playlist>> getPlaylistDetails(String playlistId);

  // ============ RECOMMENDATIONS ============

  /// Get recommendations based on a song (YouTube's "Watch Next")
  Future<Either<Failure, List<Song>>> getRelatedSongs(
    String songId, {
    int limit = 20,
  });

  /// Get song suggestions from JioSaavn based on a song ID
  Future<Either<Failure, List<Song>>> getJioSaavnSuggestions(
    String songId, {
    int limit = 10,
  });

  /// Get personalized recommendations based on listening history
  /// Uses local listening history + hybrid algorithm
  Future<Either<Failure, List<Song>>> getRecommendations({
    int limit = 20,
  });

  /// Get "Fans Also Like" for an artist (from Spotify)
  Future<Either<Failure, List<Artist>>> getSimilarArtists(
    String artistId, {
    int limit = 10,
  });

  // ============ CHARTS & TRENDING ============

  /// Get Spotify Top 50 Global chart
  Future<Either<Failure, Chart>> getSpotifyTopChart({
    String region = 'global',
  });

  /// Get YouTube Music Top 100 chart
  Future<Either<Failure, Chart>> getYouTubeMusicChart({
    String region = 'global',
  });

  /// Get trending music
  Future<Either<Failure, List<Song>>> getTrending({
    String region = 'US',
    int limit = 50,
  });

  /// Get new releases
  Future<Either<Failure, List<Album>>> getNewReleases({
    int limit = 20,
  });

  // ============ PLAYLIST IMPORT ============

  /// Import a Spotify playlist by URL
  /// Converts Spotify tracks to YouTube video IDs
  Future<Either<Failure, Playlist>> importSpotifyPlaylist(String playlistUrl);

  /// Import a YouTube playlist by URL
  Future<Either<Failure, Playlist>> importYouTubePlaylist(String playlistUrl);

  // ============ LYRICS ============

  /// Get lyrics for a song
  Future<Either<Failure, Lyrics>> getLyrics(
    String songTitle,
    String artistName, {
    Duration? duration,
  });

  // ============ HELPER METHODS ============

  /// Convert a Spotify track to YouTube video ID
  Future<Either<Failure, String>> spotifyToYouTubeId(
    String trackTitle,
    String artistName,
  );
}

/// Search results containing all types
class SearchResults {
  final List<Song> songs;
  final List<Artist> artists;
  final List<Album> albums;
  final List<Playlist> playlists;

  const SearchResults({
    this.songs = const [],
    this.artists = const [],
    this.albums = const [],
    this.playlists = const [],
  });

  bool get isEmpty =>
      songs.isEmpty && artists.isEmpty && albums.isEmpty && playlists.isEmpty;
}

/// Extended artist details with songs and albums
class ArtistDetails {
  final Artist artist;
  final List<Song> topSongs;
  final List<Album> albums;
  final List<Song>? singles;

  const ArtistDetails({
    required this.artist,
    this.topSongs = const [],
    this.albums = const [],
    this.singles,
  });
}
