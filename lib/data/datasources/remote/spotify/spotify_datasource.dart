import 'package:dio/dio.dart';
import '../../../../domain/entities/entities.dart';

/// Data source for Spotify API operations (public endpoints / scraping)
abstract class SpotifyDataSource {
  /// Search for songs on Spotify (for metadata)
  Future<List<Song>> searchSongs(String query, {int limit = 20});

  /// Get Spotify Top 50 Global chart
  Future<List<Song>> getTopChart({String region = 'global'});

  /// Get "Fans Also Like" for an artist
  Future<List<Artist>> getSimilarArtists(String artistId, {int limit = 10});

  /// Parse and get tracks from a Spotify playlist URL
  Future<List<Song>> getPlaylistTracks(String playlistUrl);

  /// Get artist details
  Future<Artist> getArtistDetails(String artistId);
}

/// Implementation using public Spotify endpoints
class SpotifyDataSourceImpl implements SpotifyDataSource {
  final Dio _dio;

  SpotifyDataSourceImpl({required Dio dio}) : _dio = dio;

  // Spotify embed endpoint that doesn't require auth
  static const String _embedBaseUrl = 'https://open.spotify.com/embed';

  @override
  Future<List<Song>> searchSongs(String query, {int limit = 20}) async {
    // Note: This would require a public client token or scraping
    // For now, return empty list - would be implemented with actual API
    return [];
  }

  @override
  Future<List<Song>> getTopChart({String region = 'global'}) async {
    try {
      // Spotify Top 50 playlist ID for Global
      const globalTop50Id = '37i9dQZEVXbMDoHDwVN2tF';
      
      // Try to get the embed page and parse it
      final response = await _dio.get(
        '$_embedBaseUrl/playlist/$globalTop50Id',
        options: Options(
          headers: {
            'Accept': 'text/html',
          },
        ),
      );

      // Parse the response to extract track data
      // This is a simplified example - real implementation would need proper parsing
      return _parsePlaylistHtml(response.data);
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Artist>> getSimilarArtists(String artistId, {int limit = 10}) async {
    // Would need to scrape artist page or use embed API
    return [];
  }

  @override
  Future<List<Song>> getPlaylistTracks(String playlistUrl) async {
    try {
      // Extract playlist ID from URL
      final playlistId = _extractPlaylistId(playlistUrl);
      if (playlistId == null) return [];

      final response = await _dio.get(
        '$_embedBaseUrl/playlist/$playlistId',
        options: Options(
          headers: {
            'Accept': 'text/html',
          },
        ),
      );

      return _parsePlaylistHtml(response.data);
    } catch (e) {
      return [];
    }
  }

  @override
  Future<Artist> getArtistDetails(String artistId) async {
    // Would need to scrape artist page
    return Artist(
      id: artistId,
      name: 'Unknown Artist',
    );
  }

  /// Extract playlist ID from Spotify URL
  String? _extractPlaylistId(String url) {
    // Handles formats like:
    // https://open.spotify.com/playlist/37i9dQZEVXbMDoHDwVN2tF
    // spotify:playlist:37i9dQZEVXbMDoHDwVN2tF
    final regex = RegExp(r'playlist[/:]([a-zA-Z0-9]+)');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  /// Parse playlist HTML to extract track information
  List<Song> _parsePlaylistHtml(String html) {
    // This is a simplified parser
    // Real implementation would use proper HTML parsing
    final songs = <Song>[];
    
    // Look for JSON data in the page
    final jsonRegex = RegExp(r'<script[^>]*>.*?Spotify\.Entity\s*=\s*(\{.*?\});', dotAll: true);
    final match = jsonRegex.firstMatch(html);
    
    if (match != null) {
      // Parse JSON and extract tracks
      // This would need actual JSON parsing
    }
    
    return songs;
  }
}
