import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../domain/entities/entities.dart';

/// Playlist metadata + tracks parsed from a public Spotify embed page.
class SpotifyPlaylistDetails {
  final String id;
  final String name;
  final String? owner;
  final String? coverUrl;
  final List<Song> tracks;

  const SpotifyPlaylistDetails({
    required this.id,
    required this.name,
    this.owner,
    this.coverUrl,
    required this.tracks,
  });
}

/// Data source for Spotify API operations (public endpoints / scraping)
abstract class SpotifyDataSource {
  /// Search for songs on Spotify (for metadata)
  Future<List<Song>> searchSongs(String query, {int limit = 20});

  /// Get Spotify Top 50 chart for [region] (e.g. global, US, IN)
  Future<List<Song>> getTopChart({String region = 'global'});

  /// Get "Fans Also Like" for an artist
  Future<List<Artist>> getSimilarArtists(String artistId, {int limit = 10});

  /// Parse and get tracks from a Spotify playlist URL
  Future<List<Song>> getPlaylistTracks(String playlistUrl);

  /// Parse a Spotify playlist URL (or raw playlist ID) into playlist
  /// metadata + tracks. Returns null when the playlist is private,
  /// deleted or the URL cannot be parsed.
  Future<SpotifyPlaylistDetails?> getPlaylistDetails(String playlistUrl);

  /// Get artist details
  Future<Artist> getArtistDetails(String artistId);
}

/// Implementation using the public Spotify embed pages (no auth required).
class SpotifyDataSourceImpl implements SpotifyDataSource {
  final Dio _dio;

  SpotifyDataSourceImpl({required Dio dio}) : _dio = dio;

  // Spotify embed endpoint that doesn't require auth
  static const String _embedBaseUrl = 'https://open.spotify.com/embed';

  // Well-known "Top 50" playlist IDs per region.
  static const Map<String, String> _topCharts = {
    'global': '37i9dQZEVXbMDoHDwVN2tF',
    'us': '37i9dQZEVXbLRQDuF5jeBZ',
    'in': '37i9dQZEVXbLZ52XmnySJg',
    'gb': '37i9dQZEVXbMwmH30k76LF',
  };

  @override
  Future<List<Song>> searchSongs(String query, {int limit = 20}) async {
    // Would require a client token or page scraping; unused by the app today.
    return const [];
  }

  @override
  Future<List<Song>> getTopChart({String region = 'global'}) async {
    final playlistId =
        _topCharts[region.toLowerCase()] ?? _topCharts['global']!;
    final details = await getPlaylistDetails(playlistId);
    return details?.tracks ?? const [];
  }

  @override
  Future<List<Artist>> getSimilarArtists(
    String artistId, {
    int limit = 10,
  }) async {
    // Would need to scrape artist pages or use the embed API.
    return const [];
  }

  @override
  Future<List<Song>> getPlaylistTracks(String playlistUrl) async {
    final details = await getPlaylistDetails(playlistUrl);
    return details?.tracks ?? const [];
  }

  @override
  Future<Artist> getArtistDetails(String artistId) async {
    return Artist(
      id: artistId,
      name: 'Unknown Artist',
    );
  }

  /// Parse the raw HTML of an open.spotify.com embed page.
  /// Visible for tests so saved page fixtures can drive regressions.
  @visibleForTesting
  SpotifyPlaylistDetails? parseEmbedHtml(String html) {
    final entity = _extractEntity(html);
    if (entity == null) return null;
    return _mapEntityToDetails('<fixture>', entity);
  }

  @override
  Future<SpotifyPlaylistDetails?> getPlaylistDetails(String playlistUrl) async {
    try {
      final playlistId = await _resolvePlaylistId(playlistUrl);
      if (playlistId == null) return null;

      final response = await _dio.get<String>(
        '$_embedBaseUrl/playlist/$playlistId',
        options: Options(responseType: ResponseType.plain),
      );
      final html = response.data;
      if (html == null || html.isEmpty) return null;

      final entity = _extractEntity(html);
      if (entity == null) return null;

      return _mapEntityToDetails(playlistId, entity);
    } catch (_) {
      return null;
    }
  }

  /// Resolve a playlist ID from any of the share formats:
  /// `open.spotify.com/playlist/ID?si=...`, `spotify:playlist:ID`,
  /// a spotify.link short URL, or a bare 22-character playlist ID.
  Future<String?> _resolvePlaylistId(String url) async {
    var candidate = url.trim();

    final bareId = RegExp(r'^[a-zA-Z0-9]{22}$').firstMatch(candidate);
    if (bareId != null) return candidate;

    var id = _extractPlaylistId(candidate);
    if (id != null) return id;

    // Short links (spotify.link/...) redirect to open.spotify.com —
    // follow the redirect and read the final URL.
    final uri = Uri.tryParse(candidate);
    if (uri != null && uri.host.contains('spotify.link')) {
      try {
        final response = await _dio.get<String>(candidate);
        id = _extractPlaylistId(response.realUri.toString());
      } catch (_) {
        return null;
      }
    }
    return id;
  }

  String? _extractPlaylistId(String url) {
    // Handles formats like:
    // https://open.spotify.com/playlist/37i9dQZEVXbMDoHDwVN2tF?si=...
    // spotify:playlist:37i9dQZEVXbMDoHDwVN2tF
    final regex = RegExp(r'playlist[/:]([a-zA-Z0-9]+)');
    return regex.firstMatch(url)?.group(1);
  }

  /// Upper bound on the embedded app-state JSON we are willing to decode.
  static const int _maxEmbedJsonChars = 20 * 1024 * 1024;

  /// Upper bound on tracks parsed from one embed playlist payload.
  static const int _maxEmbedTracks = 1000;

  /// Pull the embedded app-state JSON (`__NEXT_DATA__`) out of the page
  /// and navigate to the playlist entity it carries.
  Map<String, dynamic>? _extractEntity(String html) {
    final match = RegExp(
      r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>',
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return null;

    final raw = match.group(1)!;
    if (raw.length > _maxEmbedJsonChars) return null;

    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;
      return _navigate(data, const [
        'props',
        'pageProps',
        'state',
        'data',
        'entity',
      ]);
    } catch (_) {
      return null;
    }
  }

  SpotifyPlaylistDetails? _mapEntityToDetails(
    String fallbackId,
    Map<String, dynamic> entity,
  ) {
    final name = (entity['name'] ?? entity['title'] ?? '').toString().trim();
    final trackList = entity['trackList'];
    if (name.isEmpty || trackList is! List) return null;

    final tracks = <Song>[];
    for (final item in trackList.take(_maxEmbedTracks)) {
      if (item is! Map<String, dynamic>) continue;
      final song = _mapTrack(item);
      if (song != null) tracks.add(song);
    }
    if (tracks.isEmpty) return null;

    return SpotifyPlaylistDetails(
      id: (entity['id'] ?? fallbackId).toString(),
      name: name,
      owner: _optionalString(entity['subtitle']),
      coverUrl: _bestCoverUrl(entity['coverArt']),
      tracks: tracks,
    );
  }

  /// Map one embed trackList entry to a [Song]. Tracks keep their Spotify
  /// metadata; playback IDs are matched on YouTube later in the repository.
  Song? _mapTrack(Map<String, dynamic> track) {
    final uri = (track['uri'] ?? '').toString();
    final title = (track['title'] ?? '').toString().trim();
    if (title.isEmpty) return null;

    final spotifyId =
        uri.startsWith('spotify:track:') ? uri.split(':').last : null;
    final artists = _splitArtists((track['subtitle'] ?? '').toString());

    return Song(
      id: uri.isNotEmpty ? uri : 'spotify_track_${title.hashCode}',
      title: title,
      artist: artists.isNotEmpty ? artists.first : 'Unknown Artist',
      artists: artists,
      duration: Duration(milliseconds: (track['duration'] as num?)?.toInt() ?? 0),
      thumbnails: const Thumbnails(),
      source: MusicSource.spotify,
      spotifyId: spotifyId,
      isExplicit: track['isExplicit'] == true,
    );
  }

  /// "Arijit Singh,\u00a0Ramya Behara" -> ['Arijit Singh', 'Ramya Behara']
  List<String> _splitArtists(String subtitle) {
    final names = subtitle
        .replaceAll('\u00a0', ' ')
        .split(RegExp(r'\s*[,/&]\s*'))
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet();
    return names.take(8).toList();
  }

  String? _bestCoverUrl(Map<String, dynamic>? coverArt) {
    final sources = coverArt?['sources'];
    if (sources is! List) return null;

    String? best;
    var bestHeight = -1;
    for (final source in sources) {
      if (source is! Map<String, dynamic>) continue;
      final url = (source['url'] ?? '').toString();
      if (url.isEmpty) continue;
      final height = (source['height'] as num?)?.toInt() ?? 0;
      if (height > bestHeight) {
        bestHeight = height;
        best = url;
      }
    }
    return best;
  }

  String? _optionalString(Object? value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }

  Map<String, dynamic>? _navigate(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    dynamic current = map;
    for (final key in keys) {
      if (current is! Map<String, dynamic>) return null;
      current = current[key];
    }
    return current is Map<String, dynamic> ? current : null;
  }
}
