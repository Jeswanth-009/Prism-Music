import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../domain/entities/song.dart';
import '../../../../domain/entities/artist.dart';
import '../../../../domain/entities/album.dart';
import '../../../../domain/entities/playlist.dart';

/// Data source for JioSaavn API operations
/// Using working JioSaavn API endpoint
abstract class JioSaavnDataSource {
  /// Get song details by ID
  Future<Song?> getSongById(String songId);

  /// Get song suggestions/recommendations based on a song ID
  Future<List<Song>> getSongSuggestions(String songId, {int limit = 10});

  /// Get album details by ID
  Future<Album?> getAlbumById(String albumId);

  /// Get playlist details by ID
  Future<Playlist?> getPlaylistById(String playlistId, {int page = 1, int limit = 50});

  /// Get artist details by ID
  Future<Artist?> getArtistById(String artistId);

  /// Get artist's songs
  Future<List<Song>> getArtistSongs(String artistId, {int page = 1, int limit = 20});

  /// Get artist's albums
  Future<List<Album>> getArtistAlbums(String artistId, {int page = 1, int limit = 20});
}

/// Implementation of JioSaavn data source using HTTP API
class JioSaavnDataSourceImpl implements JioSaavnDataSource {
  // Using working JioSaavn API endpoint
  static const String _baseUrl = 'https://jiosaavn-api-privatecvc2.vercel.app';

  final http.Client _client;

  JioSaavnDataSourceImpl({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>?> _makeRequest(String endpoint, {Map<String, String>? params}) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint').replace(queryParameters: params);
      debugPrint('JioSaavn: Requesting $uri');

      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        // This API uses "status": "SUCCESS" format
        if (data['status'] == 'SUCCESS') {
          return data['data'] as Map<String, dynamic>?;
        }
      }
      debugPrint('JioSaavn: Request failed with status ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('JioSaavn: Request error: $e');
      return null;
    }
  }

  @override
  Future<Song?> getSongById(String songId) async {
    final data = await _makeRequest('/song', params: {'id': songId});
    if (data == null) return null;

    // API might return array or single object
    final results = data['results'] as List?;
    if (results != null && results.isNotEmpty) {
      return _parseSong(results[0] as Map<String, dynamic>);
    }
    return null;
  }

  @override
  Future<List<Song>> getSongSuggestions(String songId, {int limit = 10}) async {
    final data = await _makeRequest('/song/recommend', params: {
      'id': songId,
      'limit': limit.toString(),
    });

    if (data == null) return [];

    // Parse results from data map
    final results = data['results'] as List? ?? data['songs'] as List?;
    if (results != null) {
      return results.map((item) => _parseSong(item as Map<String, dynamic>)).whereType<Song>().toList();
    }

    return [];
  }

  @override
  Future<Album?> getAlbumById(String albumId) async {
    final data = await _makeRequest('/album', params: {'id': albumId});
    if (data == null) return null;
    return _parseAlbumDetails(data);
  }

  @override
  Future<Playlist?> getPlaylistById(String playlistId, {int page = 1, int limit = 50}) async {
    final data = await _makeRequest('/playlist', params: {
      'id': playlistId,
      'page': page.toString(),
      'limit': limit.toString(),
    });
    if (data == null) return null;
    return _parsePlaylistDetails(data);
  }

  @override
  Future<Artist?> getArtistById(String artistId) async {
    final data = await _makeRequest('/artist', params: {'id': artistId});
    if (data == null) return null;
    return _parseArtistDetails(data);
  }

  @override
  Future<List<Song>> getArtistSongs(String artistId, {int page = 1, int limit = 20}) async {
    final data = await _makeRequest('/artist/songs', params: {
      'id': artistId,
      'page': page.toString(),
      'limit': limit.toString(),
    });

    if (data == null) return [];

    final results = data['results'] as List? ?? [];
    return results.map((item) => _parseSong(item as Map<String, dynamic>)).whereType<Song>().toList();
  }

  @override
  Future<List<Album>> getArtistAlbums(String artistId, {int page = 1, int limit = 20}) async {
    final data = await _makeRequest('/artist/albums', params: {
      'id': artistId,
      'page': page.toString(),
      'limit': limit.toString(),
    });

    if (data == null) return [];

    final results = data['results'] as List? ?? [];
    return results.map((item) => _parseAlbum(item as Map<String, dynamic>)).whereType<Album>().toList();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Parsing helpers - adapted for the working API's response format
  // ─────────────────────────────────────────────────────────────────────────────

  Song? _parseSong(Map<String, dynamic> data) {
    try {
      final id = data['id']?.toString();
      if (id == null) return null;

      final name = data['name']?.toString() ?? data['title']?.toString() ?? 'Unknown';

      // Parse primary artists
      final artistName = data['primaryArtists']?.toString() ?? 'Unknown Artist';
      final artists = artistName.split(', ').where((a) => a.isNotEmpty).toList();

      // Parse duration (in seconds as string)
      final durationSec = int.tryParse(data['duration']?.toString() ?? '0') ?? 0;

      // Parse thumbnails from image array
      final thumbnails = _parseThumbnails(data['image']);

      // Parse album info
      final albumData = data['album'];
      String? albumName;
      String? albumId;
      if (albumData is Map) {
        albumName = albumData['name']?.toString();
        albumId = albumData['id']?.toString();
      }

      // Get the best quality download URL
      String? downloadUrl;
      final downloadUrls = data['downloadUrl'] as List?;
      if (downloadUrls != null && downloadUrls.isNotEmpty) {
        // Prefer highest quality (320kbps, then 160kbps, etc.)
        for (final quality in ['320kbps', '160kbps', '96kbps', '48kbps', '12kbps']) {
          final match = downloadUrls.firstWhere(
            (u) => u is Map && u['quality'] == quality,
            orElse: () => null,
          );
          if (match != null && match is Map) {
            downloadUrl = match['link']?.toString();
            break;
          }
        }
        if (downloadUrl == null && downloadUrls.isNotEmpty) {
          final last = downloadUrls.last;
          if (last is Map) {
            downloadUrl = last['link']?.toString();
          }
        }
      }

      // Parse year
      int? year;
      final yearStr = data['year']?.toString();
      if (yearStr != null && yearStr.isNotEmpty) {
        year = int.tryParse(yearStr);
      }

      return Song(
        id: id,
        title: name,
        artist: artists.isNotEmpty ? artists.first : artistName,
        artists: artists,
        album: albumName,
        albumId: albumId,
        duration: Duration(seconds: durationSec),
        thumbnails: thumbnails,
        source: MusicSource.jiosaavn,
        jioSaavnId: id,
        isExplicit: data['explicitContent'] == 1 || data['explicitContent'] == true,
        year: year,
        playCount: int.tryParse(data['playCount']?.toString() ?? ''),
        streamUrl: downloadUrl,
      );
    } catch (e) {
      debugPrint('JioSaavn: Error parsing song: $e');
      return null;
    }
  }

  Artist? _parseArtistDetails(Map<String, dynamic> data) {
    try {
      final id = data['id']?.toString();
      if (id == null) return null;

      return Artist(
        id: id,
        name: data['name']?.toString() ?? 'Unknown',
        thumbnails: _parseThumbnails(data['image']),
        subscriberCount: int.tryParse(data['followerCount']?.toString() ?? ''),
      );
    } catch (e) {
      return null;
    }
  }

  Album? _parseAlbum(Map<String, dynamic> data) {
    try {
      final id = data['id']?.toString();
      if (id == null) return null;

      // Get artist name
      String artistName = data['primaryArtists']?.toString() ??
                         data['artist']?.toString() ??
                         'Unknown Artist';

      return Album(
        id: id,
        title: data['name']?.toString() ?? data['title']?.toString() ?? 'Unknown Album',
        artist: artistName,
        thumbnails: _parseThumbnails(data['image']),
        year: int.tryParse(data['year']?.toString() ?? ''),
        trackCount: int.tryParse(data['songCount']?.toString() ?? ''),
      );
    } catch (e) {
      return null;
    }
  }

  Album? _parseAlbumDetails(Map<String, dynamic> data) {
    try {
      final id = data['id']?.toString();
      if (id == null) return null;

      // Parse songs
      final songsData = data['songs'] as List? ?? [];
      final songs = songsData.map((s) => _parseSong(s as Map<String, dynamic>)).whereType<Song>().toList();

      String artistName = data['primaryArtists']?.toString() ??
                         data['artist']?.toString() ??
                         'Unknown Artist';

      return Album(
        id: id,
        title: data['name']?.toString() ?? 'Unknown Album',
        artist: artistName,
        thumbnails: _parseThumbnails(data['image']),
        year: int.tryParse(data['year']?.toString() ?? ''),
        trackCount: songs.length,
        songs: songs,
      );
    } catch (e) {
      return null;
    }
  }

  Playlist? _parsePlaylistDetails(Map<String, dynamic> data) {
    try {
      final id = data['id']?.toString();
      if (id == null) return null;

      // Parse songs
      final songsData = data['songs'] as List? ?? [];
      final songs = songsData.map((s) => _parseSong(s as Map<String, dynamic>)).whereType<Song>().toList();

      return Playlist(
        id: id,
        name: data['name']?.toString() ?? 'Unknown Playlist',
        description: data['description']?.toString(),
        thumbnails: _parseThumbnails(data['image']),
        trackCount: int.tryParse(data['songCount']?.toString() ?? '') ?? songs.length,
        songs: songs,
      );
    } catch (e) {
      return null;
    }
  }

  Thumbnails _parseThumbnails(dynamic imageData) {
    if (imageData == null) return const Thumbnails();

    if (imageData is List) {
      String? low, medium, high, max;

      for (final img in imageData) {
        if (img is Map) {
          final quality = img['quality']?.toString().toLowerCase() ?? '';
          final url = img['link']?.toString() ?? img['url']?.toString();
          if (url == null) continue;

          if (quality.contains('50x50') || quality == '50') {
            low = url;
          } else if (quality.contains('150x150') || quality == '150') {
            medium = url;
          } else if (quality.contains('500x500') || quality == '500') {
            high = url;
            max = url;
          }
        }
      }

      // If quality-based parsing didn't work, use position-based
      if (low == null && medium == null && high == null && imageData.isNotEmpty) {
        final urls = imageData
            .map((img) => img is Map ? (img['link']?.toString() ?? img['url']?.toString()) : null)
            .whereType<String>()
            .toList();

        if (urls.isNotEmpty) {
          low = urls.first;
          medium = urls.length > 1 ? urls[1] : urls.first;
          high = urls.length > 2 ? urls[2] : urls.last;
          max = urls.last;
        }
      }

      return Thumbnails(low: low, medium: medium, high: high, max: max);
    }

    if (imageData is String) {
      return Thumbnails.fromUrl(imageData);
    }

    return const Thumbnails();
  }

  void dispose() {
    _client.close();
  }
}

