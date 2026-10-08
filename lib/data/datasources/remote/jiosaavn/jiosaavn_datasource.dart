import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/block/desede_engine.dart';
import 'package:pointycastle/block/modes/ecb.dart';
import 'package:pointycastle/api.dart';
import '../../../../domain/entities/song.dart';
import '../../../../domain/entities/artist.dart';
import '../../../../domain/entities/album.dart';
import '../../../../domain/entities/playlist.dart';
import '../../../../domain/entities/stream_info.dart';

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
  
  /// Generates a 320kbps MP4 stream URL using JioSaavn's official API
  Future<StreamInfo?> getStreamUrl(Song song);
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

  // Static cache for the known working CDN host across instances
  static String? _workingCdnHost;
  
  static const List<String> _cdnHosts = [
    'jiosaavn.cdn.jio.com',
    'aac.saavncdn.com',
    'jiotune.saavncdn.com',
    'snz.saavncdn.com',
  ];

  static const double _confidenceThreshold = 0.65;

  static const List<String> _versionKeywords = [
    'remix',
    'mix',
    'live',
    'cover',
    'instrumental',
    'acoustic',
    'lofi',
    'lo-fi',
    'karaoke',
    'slowed',
    'reverb',
    'sped up',
    'speed up',
    'unplugged',
    'orchestral',
    'tribute',
    'mashup',
    'reprise',
  ];

  static const List<String> _junkPhrases = [
    'official video',
    'official music video',
    'official audio',
    'official visualizer',
    'official lyric video',
    'lyric video',
    'lyrics',
    'lyrics video',
    'audio',
    'video',
    'visualizer',
    'mv',
    'm/v',
    'hd',
    'hq',
    '4k',
    'remaster',
    'remastered',
    'full song',
    'full video',
    'full audio',
    'color coded',
  ];

  static String _unescapeHtml(String input) {
    return input
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  static String _cleanText(String input) {
    return _unescapeHtml(input)
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _stripJunk(String input) {
    var text = _unescapeHtml(input).toLowerCase();
    for (final junk in _junkPhrases) {
      text = text.replaceAll(junk, ' ');
    }
    return _cleanText(text);
  }

  static Set<String> _extractVersionTags(String input) {
    final clean = _cleanText(input);
    final tokens = clean.split(' ').where((t) => t.isNotEmpty).toSet();
    final matched = <String>{};
    for (final kw in _versionKeywords) {
      if (tokens.contains(kw) || clean.contains(kw)) {
        matched.add(kw);
      }
    }
    return matched;
  }

  /// Score a JioSaavn candidate against the target [Song].
  /// Returns a confidence score between 0.0 and 1.0.
  static double scoreCandidate(Song target, Map<String, dynamic> candidate) {
    // 1. Check verified provider ID match
    final candidateId = candidate['id']?.toString() ?? candidate['song_id']?.toString();
    if (target.jioSaavnId != null && target.jioSaavnId!.isNotEmpty && candidateId == target.jioSaavnId) {
      return 1.0;
    }

    final candidateTitleRaw = candidate['title']?.toString() ??
        candidate['song']?.toString() ??
        candidate['name']?.toString() ??
        '';
    if (candidateTitleRaw.isEmpty) return 0.0;

    final targetTitle = target.title;

    // 2. Version Gate: Check version keywords
    final targetVersions = _extractVersionTags(targetTitle);
    final candidateVersions = _extractVersionTags(candidateTitleRaw);

    // If candidate has version tags (e.g. remix, live, cover) that target does not have:
    final unwantedVersions = candidateVersions.difference(targetVersions);
    if (unwantedVersions.isNotEmpty) {
      return 0.0; // Strictly reject remixes, covers, instrumental, live recordings
    }

    // If target has version tags that candidate lacks:
    final missingVersions = targetVersions.difference(candidateVersions);
    if (missingVersions.isNotEmpty) {
      return 0.0;
    }

    // 3. Title token similarity (Jaccard similarity on Unicode tokens)
    final targetTitleTokens = _stripJunk(targetTitle).split(' ').where((t) => t.isNotEmpty).toSet();
    final candidateTitleTokens = _stripJunk(candidateTitleRaw).split(' ').where((t) => t.isNotEmpty).toSet();

    if (targetTitleTokens.isEmpty || candidateTitleTokens.isEmpty) return 0.0;

    final titleIntersection = targetTitleTokens.intersection(candidateTitleTokens).length;
    final titleUnion = targetTitleTokens.union(candidateTitleTokens).length;
    final titleScore = titleUnion > 0 ? titleIntersection / titleUnion : 0.0;

    // Require reasonable title overlap
    if (titleScore < 0.4) return 0.0;

    // 4. Artist matching
    final moreInfo = candidate['more_info'] as Map<String, dynamic>?;
    final candidateArtistRaw = [
      moreInfo?['primary_artists']?.toString() ?? '',
      moreInfo?['singers']?.toString() ?? '',
      candidate['subtitle']?.toString() ?? '',
      candidate['primaryArtists']?.toString() ?? '',
    ].join(' ');

    final targetArtist = target.artist.trim();
    double artistScore = 0.5; // Neutral if artist unknown

    if (targetArtist.isNotEmpty && targetArtist.toLowerCase() != 'unknown' && targetArtist.toLowerCase() != 'various artists') {
      final targetArtistTokens = _cleanText(targetArtist).split(' ').where((t) => t.length >= 2).toSet();
      final candidateArtistClean = _cleanText(candidateArtistRaw);

      if (targetArtistTokens.isNotEmpty) {
        final matches = targetArtistTokens.where((token) => candidateArtistClean.contains(token)).length;
        if (matches > 0) {
          artistScore = 1.0;
        } else {
          // Zero artist token match: heavy penalty or reject if title isn't exact
          if (titleScore < 0.8) {
            return 0.0;
          }
          artistScore = 0.1;
        }
      }
    }

    // 5. Duration gate
    double durationScore = 0.5;
    final targetDurationSec = target.duration.inSeconds;
    final rawDuration = moreInfo?['duration'] ?? candidate['duration'];
    final candidateDurationSec = int.tryParse(rawDuration?.toString() ?? '0') ?? 0;

    if (targetDurationSec > 30 && candidateDurationSec > 0) {
      final diff = (candidateDurationSec - targetDurationSec).abs();
      if (diff > 30) {
        // Over 30s discrepancy: reject different recording/cut
        return 0.0;
      } else if (diff <= 5) {
        durationScore = 1.0;
      } else if (diff <= 15) {
        durationScore = 0.7;
      } else {
        durationScore = 0.3;
      }
    }

    // 6. Aggregate score
    // Title is 50%, Artist is 30%, Duration is 20%
    final compositeScore = (titleScore * 0.50) + (artistScore * 0.30) + (durationScore * 0.20);
    return compositeScore.clamp(0.0, 1.0);
  }

  @override
  Future<StreamInfo?> getStreamUrl(Song song) async {
    try {
      final query = Uri.encodeComponent('${song.title} ${song.artist}');
      final searchUrl = 'https://www.jiosaavn.com/api.php?__call=search.getResults&q=$query&_format=json&_marker=0&api_version=4&ctx=web6dot0';

      debugPrint('JioSaavnDataSource: Searching for ${song.title} - ${song.artist}');
      final response = await _client.get(Uri.parse(searchUrl)).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        dynamic data = response.body;
        if (data is String) {
          data = jsonDecode(data.trim());
        }

        if (data['results'] != null && data['results'] is List) {
          final results = (data['results'] as List).whereType<Map<String, dynamic>>().toList();

          Map<String, dynamic>? bestCandidate;
          double bestScore = 0.0;

          for (final item in results) {
            final moreInfo = item['more_info'];
            if (moreInfo == null || moreInfo['encrypted_media_url'] == null) continue;

            final score = scoreCandidate(song, item);
            debugPrint('JioSaavn candidate "${item['title'] ?? item['song']}" score: $score');
            if (score > bestScore && score >= _confidenceThreshold) {
              bestScore = score;
              bestCandidate = item;
            }
          }

          if (bestCandidate == null) {
            debugPrint('JioSaavnDataSource: No candidate passed confidence threshold for "${song.title}"');
            return null;
          }

          final moreInfo = bestCandidate['more_info'];

          if (moreInfo != null && moreInfo['encrypted_media_url'] != null) {
            String encryptedUrl = moreInfo['encrypted_media_url'];
            String decryptedUrl = _decryptUrl(encryptedUrl);
            decryptedUrl = decryptedUrl.replaceAll('_96.mp4', '_320.mp4');
            
            final uri = Uri.parse(decryptedUrl);
            final originalHost = uri.host;
            
            // Try to find a working CDN host
            String? finalUrl;
            
            // Re-order CDNs to try the cached working one first
            final hostsToTry = _workingCdnHost != null 
                ? [_workingCdnHost!, ..._cdnHosts.where((h) => h != _workingCdnHost)]
                : _cdnHosts;

            for (final host in hostsToTry) {
              final testUrl = decryptedUrl.replaceFirst(originalHost, host);
              try {
                debugPrint('JioSaavnDataSource: Testing CDN $host');
                final headResponse = await _client
                    .head(Uri.parse(testUrl))
                    .timeout(const Duration(milliseconds: 1500));
                
                if (headResponse.statusCode == 200 || headResponse.statusCode == 206) {
                  _workingCdnHost = host;
                  finalUrl = testUrl;
                  debugPrint('JioSaavnDataSource: Found working CDN: $host');
                  break; // Found a working CDN
                }
              } catch (e) {
                debugPrint('JioSaavnDataSource: CDN $host unreachable/timed out');
              }
            }

            if (finalUrl == null) {
              debugPrint('JioSaavnDataSource: All CDNs failed validation (Unreachable/Timeout)');
              return null; // Fallback to YouTube Explode
            }

            return StreamInfo(
              url: finalUrl,
              quality: AudioQuality.high,
              codec: 'mp4a',
              container: 'mp4',
              bitrate: 320,
              isAudioOnly: true,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('JioSaavnDataSource Error: $e');
    }
    return null;
  }

  String _decryptUrl(String encryptedText) {
    final keyStr = '38346591';
    final keyStr3 = keyStr + keyStr + keyStr; // 3DES with K1=K2=K3 is equivalent to DES
    final key = utf8.encode(keyStr3);
    final cipher = DESedeEngine()..init(false, KeyParameter(Uint8List.fromList(key)));
    final ecb = ECBBlockCipher(cipher);
    
    final encryptedBytes = base64Decode(encryptedText);
    final decryptedBytes = Uint8List(encryptedBytes.length);
    
    for (var i = 0; i < encryptedBytes.length; i += ecb.blockSize) {
      ecb.processBlock(encryptedBytes, i, decryptedBytes, i);
    }
    
    final paddingLength = decryptedBytes.last;
    final unpadded = decryptedBytes.sublist(0, decryptedBytes.length - paddingLength);
    
    return utf8.decode(unpadded);
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

