import 'dart:convert';

import 'package:dart_ytmusic_api/yt_music.dart';
import 'package:dart_ytmusic_api/types.dart';
import 'package:logging/logging.dart';

class YtMusicApiService {
  final dynamic _ytMusic = YTMusic();
  final Logger _logger = Logger('YtMusicApiService');

  static const String _songsParams = 'Eg-KAQwIARAAGAAgACgAMABqChAEEAMQCRAFEAo%3D';
  static const String _artistsParams = 'Eg-KAQwIABAAGAAgASgAMABqChAEEAMQCRAFEAo%3D';
  static const String _albumsParams = 'Eg-KAQwIABAAGAEgACgAMABqChAEEAMQCRAFEAo%3D';
  static const String _playlistsParams = 'Eg-KAQwIABAAGAAgACgBMABqChAEEAMQCRAFEAo%3D';

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }

    await _ytMusic.initialize();
    _initialized = true;
  }

  Future<List<Map<String, dynamic>>> searchSongs(String query) async {
    await _ensureInitialized();
    try {
      final raw = await _ytMusic.searchSongs(query);
      final list = _normalizeToList(raw)
          .map(_toMap)
          .whereType<Map<String, dynamic>>()
          .toList();

      if (list.isNotEmpty) {
        return list;
      }

      _logger.warning('searchSongs typed parser returned 0 for "$query", trying raw fallback');
      return await _searchFromRawRequest(
        query: query,
        params: _songsParams,
        expectedType: 'song',
      );
    } catch (e, st) {
      _logger.severe('searchSongs failed for "$query"', e, st);
      return _searchFromRawRequest(
        query: query,
        params: _songsParams,
        expectedType: 'song',
      );
    }
  }

  Future<List<Map<String, dynamic>>> search(String query) async {
    await _ensureInitialized();
    try {
      final raw = await _ytMusic.search(query);
      final list = _normalizeToList(raw)
          .map(_toMap)
          .whereType<Map<String, dynamic>>()
          .toList();
      if (list.isNotEmpty) {
        return list;
      }

      _logger.warning('search typed parser returned 0 for "$query", trying raw fallback');
      return await _searchFromRawRequest(query: query);
    } catch (e, st) {
      _logger.severe('search failed for "$query"', e, st);
      return _searchFromRawRequest(query: query);
    }
  }

  Future<List<Map<String, dynamic>>> searchArtists(String query) async {
    await _ensureInitialized();
    try {
      final raw = await _ytMusic.searchArtists(query);
      final list = _normalizeToList(raw)
          .map(_toMap)
          .whereType<Map<String, dynamic>>()
          .toList();
      if (list.isNotEmpty) {
        return list;
      }

      return await _searchFromRawRequest(
        query: query,
        params: _artistsParams,
        expectedType: 'artist',
      );
    } catch (e, st) {
      _logger.severe('searchArtists failed for "$query"', e, st);
      return _searchFromRawRequest(
        query: query,
        params: _artistsParams,
        expectedType: 'artist',
      );
    }
  }

  Future<List<Map<String, dynamic>>> searchAlbums(String query) async {
    await _ensureInitialized();
    try {
      final raw = await _ytMusic.searchAlbums(query);
      final list = _normalizeToList(raw)
          .map(_toMap)
          .whereType<Map<String, dynamic>>()
          .toList();
      if (list.isNotEmpty) {
        return list;
      }

      return await _searchFromRawRequest(
        query: query,
        params: _albumsParams,
        expectedType: 'album',
      );
    } catch (e, st) {
      _logger.severe('searchAlbums failed for "$query"', e, st);
      return _searchFromRawRequest(
        query: query,
        params: _albumsParams,
        expectedType: 'album',
      );
    }
  }

  Future<List<Map<String, dynamic>>> searchPlaylists(String query) async {
    await _ensureInitialized();
    try {
      final raw = await _ytMusic.searchPlaylists(query);
      final list = _normalizeToList(raw)
          .map(_toMap)
          .whereType<Map<String, dynamic>>()
          .toList();
      if (list.isNotEmpty) {
        return list;
      }

      return await _searchFromRawRequest(
        query: query,
        params: _playlistsParams,
        expectedType: 'playlist',
      );
    } catch (e, st) {
      _logger.severe('searchPlaylists failed for "$query"', e, st);
      return _searchFromRawRequest(
        query: query,
        params: _playlistsParams,
        expectedType: 'playlist',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _searchFromRawRequest({
    required String query,
    String? params,
    String? expectedType,
  }) async {
    try {
      final body = <String, dynamic>{'query': query, 'params': params};
      final raw = await _ytMusic.constructRequest('search', body: body);
      final items = _extractRawSearchItems(raw, expectedType: expectedType);
      _logger.info('raw fallback search("$query") -> ${items.length} items');
      return items;
    } catch (e, st) {
      _logger.severe('raw fallback search failed for "$query"', e, st);
      return const [];
    }
  }

  List<Map<String, dynamic>> _extractRawSearchItems(
    dynamic root, {
    String? expectedType,
  }) {
    final sections = _extractSections(root);
    final out = <Map<String, dynamic>>[];

    for (final section in sections) {
      if (section is! Map) continue;
      final renderer = section['musicShelfRenderer'] ?? section['musicCardShelfRenderer'];
      if (renderer is! Map) continue;

      final entries = renderer['contents'];
      if (entries is! List) continue;

      for (final entry in entries) {
        if (entry is! Map) continue;
        final parsed = _parseListItem(entry);
        if (parsed == null) continue;
        if (expectedType != null) {
          final t = (parsed['type']?.toString() ?? '').toLowerCase();
          if (t != expectedType && !(expectedType == 'song' && t == 'video')) {
            continue;
          }
        }
        out.add(parsed);
      }
    }

    return out;
  }

  List _extractSections(dynamic root) {
    final paths = <List<dynamic>>[
      [
        'contents',
        'tabbedSearchResultsRenderer',
        'tabs',
        0,
        'tabRenderer',
        'content',
        'sectionListRenderer',
        'contents',
      ],
      [
        'contents',
        'sectionListRenderer',
        'contents',
      ],
      [
        'contents',
        'twoColumnSearchResultsRenderer',
        'primaryContents',
        'sectionListRenderer',
        'contents',
      ],
    ];

    for (final path in paths) {
      final value = _dig(root, path);
      if (value is List && value.isNotEmpty) {
        return value;
      }
    }

    return const [];
  }

  Map<String, dynamic>? _parseListItem(Map entry) {
    final item = entry['musicResponsiveListItemRenderer'];
    if (item is! Map) {
      return null;
    }

    final title = _readText(_dig(item, ['flexColumns', 0, 'musicResponsiveListItemFlexColumnRenderer', 'text']));
    if (title.isEmpty) {
      return null;
    }

    final subtitleRuns = _readRuns(_dig(
      item,
      ['flexColumns', 1, 'musicResponsiveListItemFlexColumnRenderer', 'text', 'runs'],
    ));

    String? videoId = _dig(item, ['playlistItemData', 'videoId'])?.toString();
    videoId ??= _dig(item, ['navigationEndpoint', 'watchEndpoint', 'videoId'])?.toString();

    String? browseId = _dig(item, ['navigationEndpoint', 'browseEndpoint', 'browseId'])?.toString();

    final info = _parseSubtitleInfo(subtitleRuns);
    final type = _detectType(subtitleRuns, videoId: videoId, browseId: browseId);

    final thumb = _dig(item, ['thumbnail', 'musicThumbnailRenderer', 'thumbnail', 'thumbnails']);
    String image = '';
    if (thumb is List && thumb.isNotEmpty) {
      final last = thumb.last;
      if (last is Map) {
        image = last['url']?.toString() ?? '';
      }
    }

    return {
      'type': type,
      'id': (videoId ?? browseId ?? '').toString(),
      'videoId': videoId,
      'title': title,
      'name': title,
      'artist': info['artist'] ?? '',
      'album': info['album'],
      'durationSeconds': info['duration'] ?? 0,
      'duration': info['duration'] ?? 0,
      'thumbnails': [
        if (image.isNotEmpty) {'url': image}
      ],
    };
  }

  String _detectType(List<Map<String, dynamic>> runs, {String? videoId, String? browseId}) {
    for (final run in runs) {
      final pageType = run['pageType']?.toString() ?? '';
      if (pageType.endsWith('ARTIST')) return 'artist';
      if (pageType.endsWith('ALBUM')) return 'album';
      if (pageType.endsWith('PLAYLIST')) return 'playlist';
    }

    if (videoId != null && videoId.isNotEmpty) {
      return 'song';
    }

    if (browseId != null) {
      if (browseId.startsWith('UC')) return 'artist';
      if (browseId.startsWith('MPRE')) return 'album';
      if (browseId.startsWith('VL')) return 'playlist';
    }

    return 'song';
  }

  Map<String, dynamic> _parseSubtitleInfo(List<Map<String, dynamic>> runs) {
    final artists = <String>[];
    String? album;
    int? duration;

    for (final run in runs) {
      final text = (run['text']?.toString() ?? '').trim();
      if (text.isEmpty || text == '•') continue;

      final pageType = run['pageType']?.toString() ?? '';
      if (pageType.endsWith('ARTIST')) {
        artists.add(text);
        continue;
      }
      if (pageType.endsWith('ALBUM')) {
        album = text;
        continue;
      }

      final d = _parseDurationToSeconds(text);
      if (d != null) {
        duration = d;
      }
    }

    return {
      'artist': artists.join(', '),
      'album': album,
      'duration': duration,
    };
  }

  int? _parseDurationToSeconds(String text) {
    if (!RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$').hasMatch(text)) {
      return null;
    }
    final parts = text.split(':').map((e) => int.tryParse(e) ?? 0).toList();
    if (parts.length == 2) {
      return parts[0] * 60 + parts[1];
    }
    if (parts.length == 3) {
      return parts[0] * 3600 + parts[1] * 60 + parts[2];
    }
    return null;
  }

  List<Map<String, dynamic>> _readRuns(dynamic node) {
    if (node is! List) {
      return const [];
    }

    final output = <Map<String, dynamic>>[];
    for (final run in node) {
      if (run is! Map) continue;
      final endpoint = run['navigationEndpoint'];
      output.add({
        'text': run['text']?.toString() ?? '',
        'pageType': endpoint is Map
            ? _dig(endpoint, [
                'browseEndpoint',
                'browseEndpointContextSupportedConfigs',
                'browseEndpointContextMusicConfig',
                'pageType',
              ])
                ?.toString()
            : null,
      });
    }

    return output;
  }

  String _readText(dynamic node) {
    if (node == null) return '';
    if (node is String) return node;
    if (node is Map) {
      final simpleText = node['simpleText'];
      if (simpleText is String) return simpleText;
      final runs = node['runs'];
      if (runs is List) {
        return runs
            .whereType<Map>()
            .map((r) => r['text']?.toString() ?? '')
            .where((t) => t.isNotEmpty)
            .join();
      }
    }
    return '';
  }

  dynamic _dig(dynamic data, List<dynamic> path) {
    dynamic current = data;
    for (final key in path) {
      if (current is Map && key is String) {
        current = current[key];
      } else if (current is List && key is int) {
        if (key < 0 || key >= current.length) return null;
        current = current[key];
      } else {
        return null;
      }
      if (current == null) return null;
    }
    return current;
  }

  Future<Map<String, dynamic>> getSong(String videoId) async {
    await _ensureInitialized();
    try {
      final raw = await _ytMusic.getSong(videoId);
      return _toMap(raw) ?? <String, dynamic>{};
    } catch (e, st) {
      _logger.severe('getSong failed for "$videoId"', e, st);
      return const <String, dynamic>{};
    }
  }

  Future<List<Map<String, dynamic>>> getUpNexts(
    String videoId, {
    int limit = 20,
  }) async {
    await _ensureInitialized();
    try {
      final raw = await _ytMusic.getUpNexts(videoId);
      return _normalizeToList(raw)
          .map(_toMap)
          .whereType<Map<String, dynamic>>()
          .where((item) {
            final id = (item['videoId'] ?? item['id'])?.toString() ?? '';
            return id.isNotEmpty;
          })
          .take(limit)
          .toList();
    } catch (e, st) {
      _logger.severe('getUpNexts failed for "$videoId"', e, st);
      return const [];
    }
  }

  List<dynamic> _normalizeToList(dynamic raw) {
    if (raw is List) {
      return raw;
    }

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final directCandidates = <String>[
        'results',
        'items',
        'content',
        'songs',
        'artists',
        'albums',
        'playlists',
      ];
      for (final key in directCandidates) {
        final value = map[key];
        if (value is List) {
          return value;
        }
      }
    }

    return const [];
  }

  Map<String, dynamic>? _toMap(dynamic raw) {
    if (raw == null) {
      return null;
    }

    // Explicit support for dart_ytmusic_api typed models.
    if (raw is SongDetailed) {
      return {
        'type': raw.type,
        'videoId': raw.videoId,
        'title': raw.name,
        'name': raw.name,
        'artist': raw.artist.name,
        'artists': [
          {
            'artistId': raw.artist.artistId,
            'name': raw.artist.name,
          }
        ],
        'album': raw.album == null
            ? null
            : {
                'albumId': raw.album!.albumId,
                'name': raw.album!.name,
              },
        'durationSeconds': raw.duration,
        'duration': raw.duration,
        'thumbnails': raw.thumbnails
            .map((t) => {
                  'url': t.url,
                  'width': t.width,
                  'height': t.height,
                })
            .toList(),
      };
    }

    if (raw is VideoDetailed) {
      return {
        'type': raw.type,
        'videoId': raw.videoId,
        'title': raw.name,
        'name': raw.name,
        'artist': raw.artist.name,
        'artists': [
          {
            'artistId': raw.artist.artistId,
            'name': raw.artist.name,
          }
        ],
        'durationSeconds': raw.duration,
        'duration': raw.duration,
        'thumbnails': raw.thumbnails
            .map((t) => {
                  'url': t.url,
                  'width': t.width,
                  'height': t.height,
                })
            .toList(),
      };
    }

    if (raw is ArtistDetailed) {
      return {
        'type': raw.type,
        'artistId': raw.artistId,
        'browseId': raw.artistId,
        'id': raw.artistId,
        'title': raw.name,
        'name': raw.name,
        'thumbnails': raw.thumbnails
            .map((t) => {
                  'url': t.url,
                  'width': t.width,
                  'height': t.height,
                })
            .toList(),
      };
    }

    if (raw is AlbumDetailed) {
      return {
        'type': raw.type,
        'albumId': raw.albumId,
        'browseId': raw.albumId,
        'id': raw.albumId,
        'playlistId': raw.playlistId,
        'title': raw.name,
        'name': raw.name,
        'artist': raw.artist.name,
        'year': raw.year,
        'thumbnails': raw.thumbnails
            .map((t) => {
                  'url': t.url,
                  'width': t.width,
                  'height': t.height,
                })
            .toList(),
      };
    }

    if (raw is PlaylistDetailed) {
      return {
        'type': raw.type,
        'playlistId': raw.playlistId,
        'browseId': raw.playlistId,
        'id': raw.playlistId,
        'title': raw.name,
        'name': raw.name,
        'artist': raw.artist.name,
        'thumbnails': raw.thumbnails
            .map((t) => {
                  'url': t.url,
                  'width': t.width,
                  'height': t.height,
                })
            .toList(),
      };
    }

    if (raw is SongFull) {
      return {
        'type': raw.type,
        'videoId': raw.videoId,
        'title': raw.name,
        'name': raw.name,
        'artist': raw.artist.name,
        'artists': [
          {
            'artistId': raw.artist.artistId,
            'name': raw.artist.name,
          }
        ],
        'durationSeconds': raw.duration,
        'duration': raw.duration,
        'thumbnails': raw.thumbnails
            .map((t) => {
                  'url': t.url,
                  'width': t.width,
                  'height': t.height,
                })
            .toList(),
      };
    }

    if (raw is UpNextsDetails) {
      return {
        'type': 'song',
        'videoId': raw.videoId,
        'id': raw.videoId,
        'title': raw.title,
        'name': raw.title,
        'artist': raw.artists.name,
        'artists': [
          {
            'artistId': raw.artists.artistId,
            'name': raw.artists.name,
          }
        ],
        'album': raw.album == null
            ? null
            : {
                'albumId': raw.album!.albumId,
                'name': raw.album!.name,
              },
        'durationSeconds': raw.duration,
        'duration': raw.duration,
        'thumbnails': raw.thumbnails
            .map((t) => {
                  'url': t.url,
                  'width': t.width,
                  'height': t.height,
                })
            .toList(),
      };
    }

    if (raw is Map<String, dynamic>) {
      return raw;
    }

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    // Fallback for typed model classes with toJson().
    try {
      final dynamic dyn = raw;
      final jsonMap = dyn.toJson();
      if (jsonMap is Map<String, dynamic>) {
        return jsonMap;
      }
      if (jsonMap is Map) {
        return Map<String, dynamic>.from(jsonMap);
      }
    } catch (_) {
      // ignored
    }

    // Last-resort: JSON roundtrip if encodable.
    try {
      final encoded = jsonEncode(raw);
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // ignored
    }

    return null;
  }
}
