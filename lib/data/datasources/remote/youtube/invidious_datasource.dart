import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../domain/entities/stream_info.dart';
import '../../../../domain/entities/song.dart';

/// Invidious instance URLs (public proxies for YouTube)
class InvidiousInstances {
  static const List<String> instances = [
    // More reliable instances (updated November 2024)
    'https://invidious.io',
    'https://iv.ggtyler.dev',
    'https://invidious.projectsegfau.lt',
    'https://inv.riverside.rocks',
    'https://y.com.sb',
    // Fallback instances
    'https://inv.nadeko.net',
    'https://invidious.snopyta.org',
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

/// Data source that uses Invidious API as a fallback for YouTube streams
class InvidiousDataSource {
  final Dio _dio;
  
  InvidiousDataSource({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
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
    
    // Try each instance until one works
    for (int attempt = 0; attempt < InvidiousInstances.instances.length; attempt++) {
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
  
  /// Proxy a googlevideo URL through Invidious
  String _proxyThroughInvidious(String instance, String googleUrl) {
    try {
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
