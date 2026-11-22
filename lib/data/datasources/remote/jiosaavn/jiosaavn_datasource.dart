import 'dart:async';
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
import '../../../../core/error/exceptions.dart';
import '../../../../core/matching/match_confidence_engine.dart';

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
  
  /// Generates an MP4 stream URL using JioSaavn's official API respecting [preferredQuality]
  Future<StreamInfo?> getStreamUrl(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  });
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
      if (response.statusCode == 451 ||
          (response.statusCode == 403 &&
              response.body.toLowerCase().contains('geo'))) {
        throw const GeoRestrictionException(
          provider: 'JioSaavn',
          statusCode: 403,
          message: 'JioSaavn API is restricted in your region.',
        );
      }
      debugPrint('JioSaavn: Request failed with status ${response.statusCode}');
      return await _fallbackOfficial(endpoint, params);
    } on GeoRestrictionException {
      rethrow;
    } catch (e) {
      debugPrint('JioSaavn: Request error: $e');
      return await _fallbackOfficial(endpoint, params);
    }
  }

  Future<Map<String, dynamic>?> _makeOfficialRequest(
    String call, {
    Map<String, String>? params,
  }) async {
    try {
      final queryParams = {
        '__call': call,
        '_format': 'json',
        '_marker': '0',
        'api_version': '4',
        'ctx': 'web6dot0',
        if (params != null) ...params,
      };
      final uri = Uri.https('www.jiosaavn.com', '/api.php', queryParams);
      debugPrint('JioSaavn: Official fallback requesting $uri');
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final decoded = json.decode(response.body.trim());
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
      return null;
    } catch (e) {
      debugPrint('JioSaavn: Official fallback error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fallbackOfficial(
    String endpoint,
    Map<String, String>? params,
  ) async {
    try {
      if (endpoint == '/song' && params?['id'] != null) {
        final data = await _makeOfficialRequest(
          'song.getDetails',
          params: {'pids': params!['id']!},
        );
        if (data != null && data.containsKey(params['id'])) {
          return {'results': [data[params['id']]]};
        }
      } else if (endpoint == '/album' && params?['id'] != null) {
        return await _makeOfficialRequest(
          'content.getAlbumDetails',
          params: {'albumid': params!['id']!},
        );
      } else if (endpoint == '/playlist' && params?['id'] != null) {
        return await _makeOfficialRequest(
          'playlist.getDetails',
          params: {'listid': params!['id']!},
        );
      } else if (endpoint == '/artist' && params?['id'] != null) {
        return await _makeOfficialRequest(
          'artist.getArtistPageDetails',
          params: {'artistId': params!['id']!},
        );
      }
    } catch (_) {}
    return null;
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

  /// Score a JioSaavn candidate against the target [Song].
  /// Returns a confidence score between 0.0 and 1.0 using [MatchConfidenceEngine].
  static double scoreCandidate(Song target, Map<String, dynamic> candidate) {
    // 1. Check verified provider ID match
    final candidateId = candidate['id']?.toString() ?? candidate['song_id']?.toString();
    if (target.jioSaavnId != null && target.jioSaavnId!.isNotEmpty && candidateId == target.jioSaavnId) {
      return 1.0;
    }

    final matchResult = MatchConfidenceEngine.evaluateMap(
      target: target,
      candidateMap: candidate,
      threshold: _confidenceThreshold,
      provenance: 'jiosaavn_matched',
    );
    return matchResult.score;
  }

  @override
  Future<StreamInfo?> getStreamUrl(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    try {
      final query = Uri.encodeComponent('${song.title} ${song.artist}');
      final searchUrl = 'https://www.jiosaavn.com/api.php?__call=search.getResults&q=$query&_format=json&_marker=0&api_version=4&ctx=web6dot0';

      debugPrint('JioSaavnDataSource: Searching for ${song.title} - ${song.artist}');
      final response = await _client
          .get(Uri.parse(searchUrl))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 451 ||
          (response.statusCode == 403 &&
              (response.body.toLowerCase().contains('geo') || response.body.toLowerCase().contains('region')))) {
        throw const GeoRestrictionException(
          provider: 'JioSaavn',
          statusCode: 403,
          message: 'JioSaavn API is restricted in your region.',
        );
      }
      
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        dynamic data = response.body;
        if (data is String) {
          data = jsonDecode(data.trim());
        }

        if (data['results'] != null && data['results'] is List) {
          final results = (data['results'] as List).whereType<Map<String, dynamic>>().toList();

          Map<String, dynamic>? bestCandidate;
          double bestScore = 0.0;
          MatchResult? bestMatchResult;

          for (final item in results) {
            final moreInfo = item['more_info'];
            if (moreInfo == null || moreInfo['encrypted_media_url'] == null) continue;

            final matchResult = MatchConfidenceEngine.evaluateMap(
              target: song,
              candidateMap: item,
              threshold: _confidenceThreshold,
              provenance: 'jiosaavn_matched',
            );
            debugPrint('JioSaavn candidate "${item['title'] ?? item['song']}" evaluated: ${matchResult.toString()}');

            if (matchResult.isAcceptable && matchResult.score > bestScore) {
              bestScore = matchResult.score;
              bestCandidate = item;
              bestMatchResult = matchResult;
            }
          }

          if (bestCandidate == null || bestMatchResult == null) {
            debugPrint('JioSaavnDataSource: No candidate passed confidence threshold for "${song.title}"');
            return null;
          }

          final moreInfo = bestCandidate['more_info'];

          if (moreInfo != null && moreInfo['encrypted_media_url'] != null) {
            String encryptedUrl = moreInfo['encrypted_media_url'];
            String decryptedUrl = _decryptUrl(encryptedUrl);

            // Select target bitrate suffix based on preferredQuality
            final String targetSuffix;
            switch (preferredQuality) {
              case AudioQuality.low:
                targetSuffix = '_96.mp4';
                break;
              case AudioQuality.medium:
                targetSuffix = '_160.mp4';
                break;
              case AudioQuality.high:
              case AudioQuality.lossless:
                targetSuffix = '_320.mp4';
                break;
            }

            final candidateDecryptedUrl = decryptedUrl.replaceAll('_96.mp4', targetSuffix);
            final uri = Uri.parse(candidateDecryptedUrl);
            final originalHost = uri.host;
            
            // Try to find a working CDN host
            String? finalUrl;
            int geoBlockCount = 0;

            final hostsToTry = _workingCdnHost != null 
                ? [_workingCdnHost!, ..._cdnHosts.where((h) => h != _workingCdnHost)]
                : _cdnHosts;

            Future<({String? host, String? url})> probeCdnHosts(
              List<String> hosts,
              String targetTemplate,
            ) async {
              // 1. If we have a cached working host, test it first
              if (_workingCdnHost != null && hosts.contains(_workingCdnHost)) {
                final testUrl = targetTemplate.replaceFirst(originalHost, _workingCdnHost!);
                try {
                  debugPrint('JioSaavnDataSource: Testing cached CDN $_workingCdnHost');
                  final headResponse = await _client
                      .head(Uri.parse(testUrl))
                      .timeout(const Duration(milliseconds: 1500));
                  if (headResponse.statusCode == 200 || headResponse.statusCode == 206) {
                    return (host: _workingCdnHost, url: testUrl);
                  } else if (headResponse.statusCode == 403 || headResponse.statusCode == 451) {
                    geoBlockCount++;
                  }
                } catch (_) {
                  debugPrint('JioSaavnDataSource: Cached CDN $_workingCdnHost unreachable/timed out');
                }
              }

              // 2. Parallel probing across candidate hosts
              final candidateHosts = hosts.where((h) => h != _workingCdnHost).toList();
              if (candidateHosts.isEmpty) return (host: null, url: null);

              final completer = Completer<({String host, String url})>();
              var remainingProbes = candidateHosts.length;

              for (final host in candidateHosts) {
                final testUrl = targetTemplate.replaceFirst(originalHost, host);
                debugPrint('JioSaavnDataSource: Parallel probing CDN $host');
                _client
                    .head(Uri.parse(testUrl))
                    .timeout(const Duration(milliseconds: 1500))
                    .then((headResponse) {
                  if (headResponse.statusCode == 200 || headResponse.statusCode == 206) {
                    if (!completer.isCompleted) {
                      completer.complete((host: host, url: testUrl));
                    }
                  } else if (headResponse.statusCode == 403 || headResponse.statusCode == 451) {
                    geoBlockCount++;
                  }
                }).catchError((_) {
                  // unreachable or timed out
                }).whenComplete(() {
                  remainingProbes--;
                  if (remainingProbes == 0 && !completer.isCompleted) {
                    completer.completeError(Exception('All CDN candidate probes failed'));
                  }
                });
              }

              try {
                final winner = await completer.future;
                _workingCdnHost = winner.host;
                debugPrint('JioSaavnDataSource: Found working CDN: ${winner.host}');
                return (host: winner.host as String?, url: winner.url as String?);
              } catch (_) {
                return (host: null, url: null);
              }
            }

            final initialProbe = await probeCdnHosts(hostsToTry, candidateDecryptedUrl);
            finalUrl = initialProbe.url;

            // Fallback: If requested high bitrate isn't served by CDN, try 160 or 96
            if (finalUrl == null && targetSuffix != '_96.mp4') {
              final fallbackSuffixes = targetSuffix == '_320.mp4' 
                  ? ['_160.mp4', '_96.mp4'] 
                  : ['_96.mp4'];
              for (final fbSuffix in fallbackSuffixes) {
                final fallbackDecrypted = decryptedUrl.replaceAll('_96.mp4', fbSuffix);
                final probeResult = await probeCdnHosts(hostsToTry, fallbackDecrypted);
                if (probeResult.url != null) {
                  finalUrl = probeResult.url;
                  break;
                }
              }
            }

            if (finalUrl == null) {
              if (geoBlockCount > 0 && geoBlockCount >= (hostsToTry.length / 2).ceil()) {
                debugPrint('JioSaavnDataSource: Geo-restriction detected ($geoBlockCount CDNs returned 403/451)');
                throw const GeoRestrictionException(
                  provider: 'JioSaavn',
                  statusCode: 403,
                  message: 'JioSaavn CDN audio streams are restricted in your geographical region.',
                );
              }
              debugPrint('JioSaavnDataSource: All CDNs failed validation (Unreachable/Timeout)');
              return null; // Fallback to YouTube Explode
            }

            final actualBitrate = finalUrl.contains('_320.mp4')
                ? 320
                : finalUrl.contains('_160.mp4')
                    ? 160
                    : 96;
            final actualQuality = actualBitrate >= 320
                ? AudioQuality.high
                : actualBitrate >= 160
                    ? AudioQuality.medium
                    : AudioQuality.low;

            return StreamInfo(
              url: finalUrl,
              quality: actualQuality,
              codec: 'mp4a',
              container: 'mp4',
              bitrate: actualBitrate,
              isAudioOnly: true,
              streamProvenance: 'jiosaavn_matched',
              matchConfidence: bestScore,
            );
          }
        }
      }
    } on GeoRestrictionException {
      rethrow;
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
    } on GeoRestrictionException {
      rethrow;
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
    } on GeoRestrictionException {
      rethrow;
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
    } on GeoRestrictionException {
      rethrow;
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
    } on GeoRestrictionException {
      rethrow;
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
    } on GeoRestrictionException {
      rethrow;
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

