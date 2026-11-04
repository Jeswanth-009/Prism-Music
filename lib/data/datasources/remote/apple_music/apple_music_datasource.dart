import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/utils/cancellation_token.dart';
import '../../../../core/utils/link_validation.dart';
import '../../../../domain/entities/song.dart';

/// Metadata + tracks extracted from an Apple Music public playlist web page.
class AppleMusicPlaylistDetails {
  final String id;
  final String name;
  final String? curator;
  final String? coverUrl;
  final String? description;
  final List<Song> tracks;
  final int totalTracks;

  const AppleMusicPlaylistDetails({
    required this.id,
    required this.name,
    this.curator,
    this.coverUrl,
    this.description,
    required this.tracks,
    int? totalTracks,
  }) : totalTracks = totalTracks ?? tracks.length;
}

/// Data source interface for Apple Music playlist importing.
abstract class AppleMusicDataSource {
  Future<AppleMusicPlaylistDetails?> getPlaylistDetails(
    String playlistUrl, {
    ImportCancellationToken? cancelToken,
    void Function(int loaded, int total)? onProgress,
  });

  @visibleForTesting
  AppleMusicPlaylistDetails? parsePlaylistHtml(String html, {String? url});
}

class AppleMusicDataSourceImpl implements AppleMusicDataSource {
  final Dio _dio;

  AppleMusicDataSourceImpl({Dio? dio}) : _dio = dio ?? Dio();

  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  @override
  Future<AppleMusicPlaylistDetails?> getPlaylistDetails(
    String playlistUrl, {
    ImportCancellationToken? cancelToken,
    void Function(int loaded, int total)? onProgress,
  }) async {
    final trimmedUrl = playlistUrl.trim();
    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null || !isAppleMusicPlaylistHost(uri.host)) {
      return null;
    }

    try {
      final response = await _dio.get<String>(
        trimmedUrl,
        options: Options(
          headers: {
            'User-Agent': _defaultUserAgent,
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
          },
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        return null;
      }

      if (cancelToken?.isCancelled ?? false) {
        return null;
      }

      return parsePlaylistHtml(response.data!, url: trimmedUrl);
    } catch (e) {
      debugPrint('AppleMusicDataSource: Failed to fetch playlist page: $e');
      return null;
    }
  }

  @override
  @visibleForTesting
  AppleMusicPlaylistDetails? parsePlaylistHtml(String html, {String? url}) {
    if (html.isEmpty) return null;

    final playlistId = _extractPlaylistId(url, html);
    final ogTitle = _extractMeta(html, 'og:title');
    final ogImage = _extractMeta(html, 'og:image');
    final ogDescription = _extractMeta(html, 'og:description');

    // 1. Try serialized-server-data first (richest metadata + ISRC codes)
    final serializedDetails = _parseSerializedServerData(html, playlistId, ogTitle, ogImage, ogDescription);
    if (serializedDetails != null && serializedDetails.tracks.isNotEmpty) {
      return serializedDetails;
    }

    // 2. Try JSON-LD schemas
    final jsonLdDetails = _parseJsonLd(html, playlistId, ogTitle, ogImage, ogDescription);
    if (jsonLdDetails != null && jsonLdDetails.tracks.isNotEmpty) {
      return jsonLdDetails;
    }

    // 3. Fallback to HTML pattern scraping
    final scrapedTracks = _scrapeTracksFromHtml(html);
    if (scrapedTracks.isNotEmpty) {
      return AppleMusicPlaylistDetails(
        id: playlistId,
        name: ogTitle?.replaceAll(' on Apple Music', '').trim() ?? 'Apple Music Playlist',
        curator: 'Apple Music',
        coverUrl: ogImage,
        description: ogDescription,
        tracks: scrapedTracks,
      );
    }

    return null;
  }

  String _extractPlaylistId(String? url, String html) {
    if (url != null && url.isNotEmpty) {
      final uri = Uri.tryParse(url.trim());
      if (uri != null) {
        for (final segment in uri.pathSegments.reversed) {
          if (segment.startsWith('pl.') || segment.startsWith('pl.u-')) {
            return segment;
          }
        }
        if (uri.pathSegments.isNotEmpty) {
          return uri.pathSegments.last;
        }
      }
    }

    final idMatch = RegExp(r'(pl\.[a-zA-Z0-9]+|pl\.u-[a-zA-Z0-9]+)').firstMatch(html);
    return idMatch?.group(1) ?? 'am_playlist';
  }

  String? _extractMeta(String html, String property) {
    final match = RegExp(
      '<meta[^>]+(?:property|name)=["\']$property["\'][^>]+content=["\']([^"\']+)["\']',
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) return _unescapeHtml(match.group(1));

    final matchReversed = RegExp(
      '<meta[^>]+content=["\']([^"\']+)["\'][^>]+(?:property|name)=["\']$property["\']',
      caseSensitive: false,
    ).firstMatch(html);
    return matchReversed != null ? _unescapeHtml(matchReversed.group(1)) : null;
  }

  AppleMusicPlaylistDetails? _parseSerializedServerData(
    String html,
    String playlistId,
    String? fallbackTitle,
    String? fallbackImage,
    String? fallbackDescription,
  ) {
    final scriptMatch = RegExp(
      r'<script[^>]*id=["\x27]serialized-server-data["\x27][^>]*>([\s\S]*?)<\/script>',
      caseSensitive: false,
    ).firstMatch(html);

    if (scriptMatch == null) return null;
    final jsonContent = scriptMatch.group(1)?.trim();
    if (jsonContent == null || jsonContent.isEmpty) return null;

    try {
      final dynamic decoded = jsonDecode(jsonContent);
      List<dynamic> items = [];
      if (decoded is List) {
        items = decoded;
      } else if (decoded is Map) {
        items = [decoded];
      }

      String? name;
      String? curator;
      String? coverUrl;
      String? description;
      final tracks = <Song>[];

      for (final root in items) {
        _searchServerData(root, (dataMap) {
          // Look for playlist attributes
          if (dataMap['type'] == 'playlists') {
            final attrs = dataMap['attributes'] as Map<String, dynamic>?;
            if (attrs != null) {
              name ??= attrs['name'] as String?;
              curator ??= attrs['curatorName'] as String?;
              final descObj = attrs['description'];
              if (descObj is Map) {
                description ??= descObj['standard'] as String? ?? descObj['short'] as String?;
              } else if (descObj is String) {
                description ??= descObj;
              }
              final artwork = attrs['artwork'] as Map<String, dynamic>?;
              if (artwork != null && artwork['url'] is String) {
                coverUrl ??= (artwork['url'] as String)
                    .replaceAll('{w}', '500')
                    .replaceAll('{h}', '500');
              }
            }
          }

          // Look for song items
          if (dataMap['type'] == 'songs' || dataMap['type'] == 'music-videos') {
            final attrs = dataMap['attributes'] as Map<String, dynamic>?;
            if (attrs != null && attrs['name'] != null) {
              final songName = attrs['name'] as String;
              final artistName = attrs['artistName'] as String? ?? 'Unknown Artist';
              final albumName = attrs['albumName'] as String?;
              final durationMs = (attrs['durationInMillis'] as num?)?.toInt() ?? 0;
              final isrc = attrs['isrc'] as String?;
              final trackId = dataMap['id'] as String? ?? attrs['playParams']?['id'] as String? ?? '$songName-$artistName';

              String trackArtwork = '';
              final artwork = attrs['artwork'] as Map<String, dynamic>?;
              if (artwork != null && artwork['url'] is String) {
                trackArtwork = (artwork['url'] as String)
                    .replaceAll('{w}', '300')
                    .replaceAll('{h}', '300');
              }

              final thumbUrl = trackArtwork.isNotEmpty ? trackArtwork : (coverUrl ?? fallbackImage ?? '');

              tracks.add(
                Song(
                  id: 'am_$trackId',
                  title: songName,
                  artist: artistName,
                  album: albumName,
                  duration: Duration(milliseconds: durationMs),
                  thumbnails: Thumbnails.fromUrl(thumbUrl),
                  isrc: isrc,
                  source: MusicSource.spotify,
                ),
              );
            }
          }
        });
      }

      if (tracks.isNotEmpty) {
        return AppleMusicPlaylistDetails(
          id: playlistId,
          name: name ?? fallbackTitle?.replaceAll(' on Apple Music', '').trim() ?? 'Apple Music Playlist',
          curator: curator ?? 'Apple Music',
          coverUrl: coverUrl ?? fallbackImage,
          description: description ?? fallbackDescription,
          tracks: tracks,
        );
      }
    } catch (e) {
      debugPrint('AppleMusicDataSource: JSON parse error in serialized-server-data: $e');
    }

    return null;
  }

  void _searchServerData(dynamic node, void Function(Map<String, dynamic> map) visitor) {
    if (node is Map<String, dynamic>) {
      visitor(node);
      for (final val in node.values) {
        _searchServerData(val, visitor);
      }
    } else if (node is List) {
      for (final item in node) {
        _searchServerData(item, visitor);
      }
    }
  }

  AppleMusicPlaylistDetails? _parseJsonLd(
    String html,
    String playlistId,
    String? fallbackTitle,
    String? fallbackImage,
    String? fallbackDescription,
  ) {
    final matches = RegExp(
      r'<script[^>]*type=["\x27]application\/ld\+json["\x27][^>]*>([\s\S]*?)<\/script>',
      caseSensitive: false,
    ).allMatches(html);

    for (final m in matches) {
      final raw = m.group(1)?.trim();
      if (raw == null || raw.isEmpty) continue;

      try {
        final decoded = jsonDecode(raw);
        final candidates = decoded is List ? decoded : [decoded];

        for (final item in candidates) {
          if (item is Map && (item['@type'] == 'MusicPlaylist' || item['@type'] == 'MusicAlbum')) {
            final name = item['name'] as String? ?? fallbackTitle;
            final desc = item['description'] as String? ?? fallbackDescription;
            final curator = item['author'] is Map ? item['author']['name'] as String? : 'Apple Music';
            final tracks = <Song>[];

            final rawTracks = item['track'] ?? item['tracks'];
            if (rawTracks is List) {
              for (final t in rawTracks) {
                if (t is Map) {
                  final title = t['name'] as String?;
                  if (title == null || title.isEmpty) continue;

                  String artist = 'Unknown Artist';
                  if (t['byArtist'] is Map) {
                    artist = t['byArtist']['name'] as String? ?? artist;
                  } else if (t['byArtist'] is List && (t['byArtist'] as List).isNotEmpty) {
                    artist = (t['byArtist'] as List).first['name'] as String? ?? artist;
                  }

                  String? album;
                  if (t['inAlbum'] is Map) {
                    album = t['inAlbum']['name'] as String?;
                  }

                  final isrc = t['isrcCode'] as String? ?? t['isrc'] as String?;
                  final duration = _parseIso8601Duration(t['duration'] as String?) ?? Duration.zero;

                  tracks.add(
                    Song(
                      id: 'am_${tracks.length}_${title.hashCode}',
                      title: title,
                      artist: artist,
                      album: album,
                      duration: duration,
                      thumbnails: Thumbnails.fromUrl(fallbackImage ?? ''),
                      isrc: isrc,
                      source: MusicSource.spotify,
                    ),
                  );
                }
              }
            }

            if (tracks.isNotEmpty) {
              return AppleMusicPlaylistDetails(
                id: playlistId,
                name: name?.replaceAll(' on Apple Music', '').trim() ?? 'Apple Music Playlist',
                curator: curator,
                coverUrl: fallbackImage,
                description: desc,
                tracks: tracks,
              );
            }
          }
        }
      } catch (_) {}
    }

    return null;
  }

  List<Song> _scrapeTracksFromHtml(String html) {
    final tracks = <Song>[];
    // Regex looking for track rows in Apple Music page markup
    final rowRegex = RegExp(
      r'class=["\x27][^"\x27]*songs-list-row[^"\x27]*["\x27][\s\S]*?class=["\x27][^"\x27]*songs-list-row__song-name[^"\x27]*["\x27]>([^<]+)<\/[\s\S]*?class=["\x27][^"\x27]*songs-list-row__link[^"\x27]*["\x27]>([^<]+)<\/',
      caseSensitive: false,
    );

    for (final match in rowRegex.allMatches(html)) {
      final title = _unescapeHtml(match.group(1)?.trim());
      final artist = _unescapeHtml(match.group(2)?.trim());
      if (title != null && title.isNotEmpty) {
        tracks.add(
          Song(
            id: 'am_scrape_${tracks.length}',
            title: title,
            artist: artist ?? 'Unknown Artist',
            duration: Duration.zero,
            thumbnails: const Thumbnails(),
            source: MusicSource.spotify,
          ),
        );
      }
    }

    return tracks;
  }

  Duration? _parseIso8601Duration(String? text) {
    if (text == null || text.isEmpty) return null;
    final regex = RegExp(r'^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$');
    final match = regex.firstMatch(text.trim());
    if (match == null) return null;
    final hours = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '') ?? 0;
    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }

  String? _unescapeHtml(String? text) {
    if (text == null) return null;
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }
}
