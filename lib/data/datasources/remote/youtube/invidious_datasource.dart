import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../domain/entities/stream_info.dart';
import '../../../../domain/entities/song.dart';

/// Invidious instance URLs (public proxies for YouTube).
/// Health-checked 2026-09: the first two serve playlist/video data reliably.
class InvidiousInstances {
  static const List<String> instances = [
    'https://inv.nadeko.net',
    'https://invidious.f5.si',
    'https://invidious.private.coffee',
    'https://inv.tux.pizza',
    'https://yewtu.be',
    'https://invidious.nerdvpn.de',
  ];
  
  static String _currentInstance = instances[0];
  static int _currentIndex = 0;
  
  static String get currentInstance => _currentInstance;
  
  static void rotateInstance() {
    _currentIndex = (_currentIndex + 1) % instances.length;
    _currentInstance = instances[_currentIndex];
  }
  
  static void reset() {
    _currentIndex = 0;
    _currentInstance = instances[0];
  }
}

/// Playlist metadata + tracks fetched from an Invidious instance.
class InvidiousPlaylistData {
  final String title;
  final String? author;
  final String? description;
  final String? thumbnailUrl;
  final List<Song> songs;

  const InvidiousPlaylistData({
    required this.title,
    this.author,
    this.description,
    this.thumbnailUrl,
    required this.songs,
  });
}

/// Data source that uses Invidious API as a fallback for YouTube streams
class InvidiousDataSource {
  final Dio _dio;
  
  InvidiousDataSource({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    sendTimeout: const Duration(seconds: 8),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'application/json',
      'Accept-Language': 'en-US,en;q=0.9',
    },
  ));
  
  /// Get PROXIED stream URL using Invidious API
  /// Invidious can proxy audio when using local=true parameter
  Future<StreamInfo?> getStreamUrl(String videoId) async {
    debugPrint('InvidiousDataSource: Getting stream for $videoId');
    debugPrint('InvidiousDataSource: Available instances: ${InvidiousInstances.instances}');
    
    // Try up to 3 instances (not all) to fail fast
    final maxAttempts = InvidiousInstances.instances.length.clamp(0, 3);
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final instance = InvidiousInstances.currentInstance;
        debugPrint('InvidiousDataSource: Trying $instance');
        
        // Use local=true to get proxied streams through Invidious
        final response = await _dio.get(
          '$instance/api/v1/videos/$videoId',
          queryParameters: {
            'local': 'true',  // This tells Invidious to proxy the stream
          },
          options: Options(
            // Let Dio throw only for 5xx; we'll handle 4xx here
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        
        debugPrint('InvidiousDataSource: Response from $instance - Status: ${response.statusCode}, Data type: ${response.data.runtimeType}');
        
        if (response.statusCode == 200) {
          final body = response.data;
          if (body is! Map<String, dynamic>) {
            debugPrint('InvidiousDataSource: Unexpected response type from $instance: ${body.runtimeType}');
            if (body is String && body.length < 500) {
              debugPrint('InvidiousDataSource: Response preview: ${body.substring(0, body.length.clamp(0, 200))}...');
            }
            InvidiousInstances.rotateInstance();
            continue;
          }
          final data = body;
          debugPrint('InvidiousDataSource: Got valid JSON response from $instance');
          debugPrint('InvidiousDataSource: Response keys: ${data.keys.toList()}');
          
          // Check if video is available
          if (data['error'] != null) {
            debugPrint('InvidiousDataSource: Video error from $instance: ${data['error']}');
            InvidiousInstances.rotateInstance();
            continue;
          }
          
          // Get adaptive formats (audio streams)
          final adaptiveFormats = data['adaptiveFormats'] as List?;
          
          debugPrint('InvidiousDataSource: adaptiveFormats found: ${adaptiveFormats?.length ?? 0}');
          if (adaptiveFormats == null) {
            debugPrint('InvidiousDataSource: No adaptiveFormats in response from $instance');
            debugPrint('InvidiousDataSource: Available data fields: ${data.keys.toList()}');
            InvidiousInstances.rotateInstance();
            continue;
          }
          
          if (adaptiveFormats.isNotEmpty) {
            debugPrint('InvidiousDataSource: Found ${adaptiveFormats.length} adaptive formats');
            
            // Find audio-only streams
            final audioStreams = adaptiveFormats.where((format) {
              final type = format['type'] as String?;
              return type != null && type.startsWith('audio/');
            }).toList();
            
            if (audioStreams.isNotEmpty) {
              debugPrint('InvidiousDataSource: Found ${audioStreams.length} audio streams');
              
              // Sort by bitrate (descending)
              audioStreams.sort((a, b) {
                final bitrateA = (a['bitrate'] as num?) ?? 0;
                final bitrateB = (b['bitrate'] as num?) ?? 0;
                return bitrateB.compareTo(bitrateA);
              });
              
              // Prefer m4a/aac for compatibility, then opus
              var selectedStream = audioStreams.firstWhere(
                (s) => (s['type'] as String?)?.contains('mp4a') ?? false,
                orElse: () => audioStreams.firstWhere(
                  (s) => (s['type'] as String?)?.contains('opus') ?? false,
                  orElse: () => audioStreams.first,
                ),
              );
              
              final url = selectedStream['url'] as String?;
              final bitrate = (selectedStream['bitrate'] as num?)?.toInt() ?? 128000;
              final type = selectedStream['type'] as String? ?? 'audio/webm';
              final contentLength = (selectedStream['contentLength'] as num?)?.toInt();
              
              if (url != null && url.isNotEmpty) {
                // If the URL still points to YouTube, proxy it through Invidious
                String finalUrl = url;
                if (url.contains('googlevideo.com')) {
                  finalUrl = _proxyThroughInvidious(instance, url);
                }
                
                debugPrint('InvidiousDataSource: Final URL: $finalUrl');
                
                return StreamInfo(
                  url: finalUrl,
                  codec: _extractCodec(type),
                  bitrate: bitrate ~/ 1000,
                  container: _extractContainer(type),
                  quality: _bitrateToQuality(bitrate ~/ 1000),
                  contentLength: contentLength,
                  isAudioOnly: true,
                );
              }
            }
          }
          
          // Fallback: Use Invidious's direct audio endpoint
          // This always proxies through Invidious
          final proxyUrl = '$instance/latest_version?id=$videoId&itag=140'; // itag 140 = m4a audio
          debugPrint('InvidiousDataSource: Using direct proxy: $proxyUrl');
          
          return StreamInfo(
            url: proxyUrl,
            codec: 'aac',
            bitrate: 128,
            container: 'm4a',
            quality: AudioQuality.medium,
            isAudioOnly: true,
          );
        } else {
          debugPrint('InvidiousDataSource: Non-200 status from $instance: ${response.statusCode}');
          InvidiousInstances.rotateInstance();
        }
      } catch (e) {
        debugPrint('InvidiousDataSource: Error with ${InvidiousInstances.currentInstance}: $e');
        InvidiousInstances.rotateInstance();
        continue;
      }
    }
    
    return null;
  }
  
  /// Fetch a YouTube playlist's metadata and tracks from Invidious.
  ///
  /// Fallback for playlist imports: youtube_explode's playlist pagination
  /// currently returns zero videos against YouTube's live API. Rotates
  /// through every instance before giving up. Returns null when no
  /// instance can serve the playlist.
  ///
  /// IDs starting with `RD` are mixes/radio stations ("My Mix", artist
  /// radio, the music playlists YouTube Music hands out) — those are served
  /// by the separate `/api/v1/mixes` endpoint. Some instances disable one
  /// endpoint or the other, so rotation matters here.
  Future<InvidiousPlaylistData?> getPlaylistDetails(String playlistId) async {
    final isMix = playlistId.startsWith('RD');
    final path = isMix
        ? '/api/v1/mixes/$playlistId'
        : '/api/v1/playlists/$playlistId';

    for (var attempt = 0;
        attempt < InvidiousInstances.instances.length;
        attempt++) {
      final instance = InvidiousInstances.currentInstance;
      try {
        debugPrint(
          'InvidiousDataSource: Fetching ${isMix ? 'mix' : 'playlist'} '
          'from $instance',
        );
        final response = await _dio.get(
          '$instance$path',
          options: Options(
            // Playlist payloads run large (one entry per track, each with
            // thumbnail variants) — allow more time than stream lookups.
            receiveTimeout: const Duration(seconds: 25),
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        final data = response.data;
        if (response.statusCode != 200 || data is! Map<String, dynamic>) {
          debugPrint(
            'InvidiousDataSource: Bad playlist response from $instance '
            '(${response.statusCode})',
          );
          InvidiousInstances.rotateInstance();
          continue;
        }
        if (data['error'] != null) {
          debugPrint(
            'InvidiousDataSource: Playlist error from $instance: '
            '${data['error']}',
          );
          InvidiousInstances.rotateInstance();
          continue;
        }

        final songs = <Song>[];
        final videos = data['videos'] as List? ?? const [];
        for (final video in videos) {
          if (video is! Map<String, dynamic>) continue;
          final videoId = video['videoId']?.toString() ?? '';
          final title = (video['title'] ?? '').toString().trim();
          if (videoId.isEmpty || title.isEmpty) continue;

          final author = (video['author'] ?? '').toString().trim();
          final thumbnails = video['videoThumbnails'] as List? ?? const [];
          String? thumbnailUrl;
          for (final thumb in thumbnails) {
            if (thumb is! Map<String, dynamic>) continue;
            if (thumb['quality'] == 'high') {
              thumbnailUrl = thumb['url']?.toString();
              break;
            }
          }
          thumbnailUrl ??= thumbnails
              .whereType<Map<String, dynamic>>()
              .map((t) => t['url']?.toString())
              .firstWhere((url) => url != null && url.isNotEmpty,
                  orElse: () => null);

          songs.add(Song(
            id: videoId,
            title: title,
            artist: author.isEmpty ? 'Unknown Artist' : author,
            duration:
                Duration(seconds: (video['lengthSeconds'] as num?)?.toInt() ?? 0),
            thumbnails: thumbnailUrl == null
                ? const Thumbnails()
                : Thumbnails.fromUrl(thumbnailUrl),
            source: MusicSource.youtube,
            youtubeId: videoId,
          ));
        }

        if (songs.isEmpty) {
          debugPrint(
            'InvidiousDataSource: $instance returned no videos, rotating',
          );
          InvidiousInstances.rotateInstance();
          continue;
        }

        final title = (data['title'] ?? '').toString().trim();
        return InvidiousPlaylistData(
          title: title.isEmpty
              ? (isMix ? 'YouTube Mix' : 'YouTube Playlist')
              : title,
          author: _optionalText(data['author']),
          description: _optionalText(data['description']),
          thumbnailUrl: _optionalText(data['playlistThumbnail']),
          songs: songs,
        );
      } catch (e) {
        debugPrint('InvidiousDataSource: Playlist fetch failed on $instance: $e');
        InvidiousInstances.rotateInstance();
        continue;
      }
    }
    return null;
  }

  String? _optionalText(Object? value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }

  /// Proxy a googlevideo URL through Invidious
  String _proxyThroughInvidious(String instance, String googleUrl) {    try {
      final uri = Uri.parse(googleUrl);
      // Invidious proxy format
      return '$instance/videoplayback?${uri.query}&host=${uri.host}';
    } catch (e) {
      return googleUrl;
    }
  }
  
  String _extractCodec(String mimeType) {
    if (mimeType.contains('opus')) return 'opus';
    if (mimeType.contains('mp4a')) return 'aac';
    if (mimeType.contains('vorbis')) return 'vorbis';
    return 'unknown';
  }
  
  String _extractContainer(String mimeType) {
    if (mimeType.contains('webm')) return 'webm';
    if (mimeType.contains('mp4')) return 'mp4';
    if (mimeType.contains('ogg')) return 'ogg';
    return 'webm';
  }
  
  AudioQuality _bitrateToQuality(int bitrateKbps) {
    if (bitrateKbps >= 256) return AudioQuality.lossless;
    if (bitrateKbps >= 160) return AudioQuality.high;
    if (bitrateKbps >= 96) return AudioQuality.medium;
    return AudioQuality.low;
  }
  
  void dispose() {
    _dio.close();
  }
}
