import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/services/spotify_auth_service.dart';
import '../../../../core/utils/cancellation_token.dart';
import '../../../../core/utils/link_validation.dart';
import '../../../../domain/entities/entities.dart';

/// Playlist metadata + tracks parsed from a public Spotify embed page or Web API.
class SpotifyPlaylistDetails {
  final String id;
  final String name;
  final String? owner;
  final String? coverUrl;
  final List<Song> tracks;
  final int totalTracks;
  final bool isEmbedFallback;
  final bool hasMoreTracks;

  const SpotifyPlaylistDetails({
    required this.id,
    required this.name,
    this.owner,
    this.coverUrl,
    required this.tracks,
    int? totalTracks,
    this.isEmbedFallback = false,
    this.hasMoreTracks = false,
  }) : totalTracks = totalTracks ?? tracks.length;
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
  Future<SpotifyPlaylistDetails?> getPlaylistDetails(
    String playlistUrl, {
    ImportCancellationToken? cancelToken,
    void Function(int loaded, int total)? onProgress,
  });

  /// Get artist details
  Future<Artist> getArtistDetails(String artistId);
}

/// Implementation supporting both Spotify Web API (for uncapped paginated tracks
/// and ISRC codes) and zero-auth embed scraping as resilient fallback.
class SpotifyDataSourceImpl implements SpotifyDataSource {
  final Dio _dio;
  final SpotifyAuthService? _authService;

  SpotifyDataSourceImpl({
    required Dio dio,
    SpotifyAuthService? authService,
  })  : _dio = dio,
        _authService = authService;

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
  Future<SpotifyPlaylistDetails?> getPlaylistDetails(
    String playlistUrl, {
    ImportCancellationToken? cancelToken,
    void Function(int loaded, int total)? onProgress,
  }) async {
    try {
      final playlistId = await _resolvePlaylistId(playlistUrl);
      if (playlistId == null) return null;

      // 1. Try Spotify Web API if auth service is configured and valid token is acquired
      if (_authService != null) {
        final token = await _authService.getValidAccessToken();
        if (token != null) {
          final apiDetails = await _fetchPlaylistViaApi(
            playlistId,
            token,
            cancelToken: cancelToken,
            onProgress: onProgress,
          );
          if (apiDetails != null) {
            return apiDetails;
          }
        }
      }

      // 2. Fall back to Embed Scraper (first 100 tracks, 0 credentials required)
      return _fetchPlaylistViaEmbed(playlistId);
    } catch (_) {
      return null;
    }
  }

  Future<SpotifyPlaylistDetails?> _fetchPlaylistViaEmbed(String playlistId) async {
    try {
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

  Future<SpotifyPlaylistDetails?> _fetchPlaylistViaApi(
    String playlistId,
    String token, {
    ImportCancellationToken? cancelToken,
    void Function(int loaded, int total)? onProgress,
  }) async {
    try {
      // 1. Fetch playlist metadata
      final metaResponse = await _dio.get<Map<String, dynamic>>(
        'https://api.spotify.com/v1/playlists/$playlistId',
        queryParameters: {
          'fields': 'id,name,description,owner(display_name),images,tracks.total',
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          responseType: ResponseType.json,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (metaResponse.statusCode == 401) {
        _authService?.invalidateToken();
        return null;
      }
      if (metaResponse.statusCode != 200 || metaResponse.data == null) {
        return null;
      }

      final metaData = metaResponse.data!;
      final name = (metaData['name'] ?? '').toString().trim();
      final owner = metaData['owner']?['display_name']?.toString();
      final coverUrl = _bestCoverUrlFromList(metaData['images'] as List?);
      final total = (metaData['tracks']?['total'] as num?)?.toInt() ?? 0;

      // 2. Paginate tracks in batches of 100
      final tracks = <Song>[];
      var offset = 0;
      const limit = 100;

      while (offset < total) {
        if (cancelToken?.isCancelled ?? false) break;

        final tracksResponse = await _dio.get<Map<String, dynamic>>(
          'https://api.spotify.com/v1/playlists/$playlistId/tracks',
          queryParameters: {
            'offset': offset,
            'limit': limit,
            'fields':
                'items(track(id,name,duration_ms,explicit,external_ids,artists(name),album(name,images)))',
          },
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
            responseType: ResponseType.json,
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        if (tracksResponse.statusCode == 401) {
          _authService?.invalidateToken();
          if (tracks.isNotEmpty) break;
          return null;
        }

        if (tracksResponse.statusCode != 200 || tracksResponse.data == null) {
          break;
        }

        final items = tracksResponse.data!['items'];
        if (items is! List || items.isEmpty) break;

        for (final item in items) {
          if (item is! Map<String, dynamic>) continue;
          final trackData = item['track'];
          if (trackData is! Map<String, dynamic>) continue;
          final song = _mapApiTrack(trackData);
          if (song != null) tracks.add(song);
        }

        onProgress?.call(tracks.length, total);
        offset += limit;
      }

      if (tracks.isEmpty) return null;

      return SpotifyPlaylistDetails(
        id: playlistId,
        name: name.isNotEmpty ? name : 'Spotify Playlist',
        owner: owner,
        coverUrl: coverUrl,
        tracks: tracks,
        totalTracks: total > 0 ? total : tracks.length,
        isEmbedFallback: false,
        hasMoreTracks: tracks.length < total && (cancelToken?.isCancelled ?? false),
      );
    } catch (_) {
      return null;
    }
  }

  Song? _mapApiTrack(Map<String, dynamic> track) {
    final title = (track['name'] ?? '').toString().trim();
    if (title.isEmpty) return null;

    final id = (track['id'] ?? '').toString().trim();
    final uri = id.isNotEmpty ? 'spotify:track:$id' : '';

    final artistsList = (track['artists'] as List?)
            ?.map((a) => (a is Map ? (a['name'] ?? '').toString().trim() : ''))
            .where((name) => name.isNotEmpty)
            .toList() ??
        const [];
    final primaryArtist =
        artistsList.isNotEmpty ? artistsList.first : 'Unknown Artist';

    final externalIds = track['external_ids'];
    final isrc = (externalIds is Map ? (externalIds['isrc'] ?? '').toString() : '')
        .trim();

    final album = track['album'];
    final albumName = album is Map ? album['name']?.toString() : null;
    final albumImages = album is Map ? album['images'] as List? : null;
    final trackThumb = _bestCoverUrlFromList(albumImages);

    return Song(
      id: uri.isNotEmpty ? uri : 'spotify_track_${title.hashCode}',
      title: title,
      artist: primaryArtist,
      artists: artistsList,
      album: albumName,
      duration:
          Duration(milliseconds: (track['duration_ms'] as num?)?.toInt() ?? 0),
      thumbnails: trackThumb != null
          ? Thumbnails.fromUrl(trackThumb)
          : const Thumbnails(),
      source: MusicSource.spotify,
      spotifyId: id.isNotEmpty ? id : null,
      isrc: isrc.isNotEmpty ? isrc : null,
      isExplicit: track['explicit'] == true,
    );
  }

  String? _bestCoverUrlFromList(List<dynamic>? images) {
    if (images == null || images.isEmpty) return null;
    String? best;
    var bestHeight = -1;
    for (final image in images) {
      if (image is! Map) continue;
      final url = (image['url'] ?? '').toString();
      if (url.isEmpty) continue;
      final height = (image['height'] as num?)?.toInt() ?? 0;
      if (height > bestHeight) {
        bestHeight = height;
        best = url;
      }
    }
    return best ?? (images.first is Map ? images.first['url']?.toString() : null);
  }

  /// Resolve a playlist ID from any of the share formats:
  /// `open.spotify.com/playlist/ID?si=...`, `spotify:playlist:ID`,
  /// a spotify.link short URL, or a bare 22-character playlist ID.
  ///
  /// User-supplied URLs are untrusted: hosts are matched exactly (never by
  /// substring, which would admit lookalikes like `spotify.link.evil.com`),
  /// and a followed short-link redirect only counts when it lands on
  /// `open.spotify.com` over HTTPS.
  Future<String?> _resolvePlaylistId(String url) async {
    var candidate = url.trim();

    final bareId = RegExp(r'^[a-zA-Z0-9]{22}$').firstMatch(candidate);
    if (bareId != null) return candidate;

    final uri = Uri.tryParse(candidate);
    if (uri != null && uri.host.isNotEmpty) {
      final host = uri.host.toLowerCase();
      final isPlaylistHost = isSpotifyPlaylistHost(host);
      final isShortLink = isSpotifyShortLinkHost(host);
      if (!isPlaylistHost && !isShortLink) return null;

      if (isShortLink) {
        // Short links (spotify.link/...) redirect to open.spotify.com.
        // We set followRedirects: false so we can inspect and validate the
        // redirect target BEFORE any request is sent to it, preventing SSRF
        // and redirection to arbitrary/private hosts.
        try {
          final response = await _dio.get<void>(
            candidate,
            options: Options(
              followRedirects: false,
              validateStatus: (status) => status != null && status < 400,
            ),
          );
          final location = response.headers.value('location');
          if (location == null) return null;
          final targetUri = Uri.tryParse(location);
          if (targetUri == null || !isTrustedSpotifyRedirectTarget(targetUri)) {
            return null;
          }
          return _extractPlaylistId(targetUri.toString());
        } catch (_) {
          return null;
        }
      }
    }

    return _extractPlaylistId(candidate);
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
      totalTracks: tracks.length,
      isEmbedFallback: true,
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
