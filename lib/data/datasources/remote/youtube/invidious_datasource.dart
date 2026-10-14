import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../domain/entities/stream_info.dart';
import '../../../../domain/entities/song.dart';
import '../../../../core/services/instance_health_service.dart';

/// Legacy compatibility wrapper delegating to [InstanceHealthService].
class InvidiousInstances {
  static final InstanceHealthService _health = InstanceHealthService();

  static List<String> get instances => InstanceHealthService.defaultInvidiousInstances;
  
  static String get currentInstance => _health.getHealthyInvidious();
  
  static void rotateInstance() {}
  static void reset() {
    _health.resetQuarantines();
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

/// Data source that uses Invidious API as a fallback for YouTube streams with dynamic health tracking
class InvidiousDataSource {
  final Dio _dio;
  final InstanceHealthService _healthService;
  
  InvidiousDataSource({Dio? dio, InstanceHealthService? healthService})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 4),
              sendTimeout: const Duration(seconds: 4),
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Accept': 'application/json',
                'Accept-Language': 'en-US,en;q=0.9',
              },
            )),
        _healthService = healthService ?? InstanceHealthService();
  
  /// Get PROXIED stream URL using Invidious API with health tracking and quarantine
  Future<StreamInfo?> getStreamUrl(String videoId) async {
    debugPrint('InvidiousDataSource: Getting stream for $videoId');
    
    // Try up to 2 healthy instances with fast timeouts
    for (int attempt = 0; attempt < 2; attempt++) {
      final instance = _healthService.getHealthyInvidious();
      final stopwatch = Stopwatch()..start();
      try {
        debugPrint('InvidiousDataSource: Trying healthy instance $instance (attempt $attempt)');
        
        final response = await _dio.get(
          '$instance/api/v1/videos/$videoId',
          queryParameters: {
            'local': 'true',  // Tells Invidious to proxy the stream
          },
          options: Options(
            sendTimeout: const Duration(milliseconds: 4000),
            receiveTimeout: const Duration(milliseconds: 4000),
            validateStatus: (status) => status != null && status < 500,
          ),
        ).timeout(const Duration(milliseconds: 4500));
        stopwatch.stop();
        
        debugPrint('InvidiousDataSource: Response from $instance - Status: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final body = response.data;
          if (body is! Map<String, dynamic>) {
            debugPrint('InvidiousDataSource: Unexpected response type from $instance: ${body.runtimeType}');
            _healthService.recordFailure(instance, 'Unexpected response shape');
            continue;
          }
          final data = body;
          
          // Check if video has an error message
          if (data['error'] != null) {
            debugPrint('InvidiousDataSource: Video error from $instance: ${data['error']}');
            _healthService.recordFailure(instance, data['error']);
            continue;
          }
          
          _healthService.recordSuccess(instance, stopwatch.elapsed);
          
          // Get adaptive formats (audio streams)
          final adaptiveFormats = data['adaptiveFormats'] as List?;
          
          if (adaptiveFormats != null && adaptiveFormats.isNotEmpty) {
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
                  streamProvenance: 'invidious_instance',
                  matchConfidence: 0.95,
                );
              }
            }
          }
          
          // Fallback: Use Invidious's direct audio endpoint
          final proxyUrl = '$instance/latest_version?id=$videoId&itag=140';
          debugPrint('InvidiousDataSource: Using direct proxy: $proxyUrl');
          
          return StreamInfo(
            url: proxyUrl,
            codec: 'aac',
            bitrate: 128,
            container: 'm4a',
            quality: AudioQuality.medium,
            isAudioOnly: true,
            streamProvenance: 'invidious_instance',
            matchConfidence: 0.90,
          );
        } else {
          _healthService.recordFailure(instance, 'HTTP ${response.statusCode}');
        }
      } catch (e) {
        stopwatch.stop();
        debugPrint('InvidiousDataSource: Error with $instance: $e');
        _healthService.recordFailure(instance, e);
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
