import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../domain/entities/stream_info.dart';
import '../../../../domain/entities/song.dart';

/// Piped API instance URLs (FOSS YouTube frontend with proxy)
class PipedInstances {
  static const List<String> apiInstances = [
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.tokhmi.xyz',
    'https://pipedapi.moomoo.me',
    'https://pipedapi.syncpundit.io',
    'https://api.piped.yt',
  ];
  
  /// Piped proxy instances for streaming audio
  /// These proxy the actual YouTube content
  static const List<String> proxyInstances = [
    'https://pipedproxy.kavin.rocks',
    'https://pipedproxy-cdg.kavin.rocks',
    'https://pipedproxy-ams.kavin.rocks',
    'https://pipedproxy-fra.kavin.rocks',
  ];
  
  static int _currentApiIndex = 0;
  static int _currentProxyIndex = 0;
  
  static String get currentApiInstance => apiInstances[_currentApiIndex];
  static String get currentProxyInstance => proxyInstances[_currentProxyIndex];
  
  static void rotateApiInstance() {
    _currentApiIndex = (_currentApiIndex + 1) % apiInstances.length;
  }
  
  static void rotateProxyInstance() {
    _currentProxyIndex = (_currentProxyIndex + 1) % proxyInstances.length;
  }
  
  static void reset() {
    _currentApiIndex = 0;
    _currentProxyIndex = 0;
  }
}

/// Data source that uses Piped API for YouTube audio streaming
/// Piped provides proxy URLs that are more reliable than direct YouTube URLs
class PipedDataSource {
  final Dio _dio;
  
  PipedDataSource({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    },
  ));
  
  /// Convert a direct YouTube stream URL to a Piped proxy URL
  String _convertToProxyUrl(String directUrl) {
    try {
      final uri = Uri.parse(directUrl);
      final originalHost = uri.host;
      final proxyBase = PipedInstances.currentProxyInstance;
      
      // Build proxy URL with host parameter
      final queryParams = Map<String, String>.from(
        uri.queryParameters.map((k, v) => MapEntry(k, v)),
      );
      queryParams['host'] = originalHost;
      
      final proxyUri = Uri.parse(proxyBase).replace(
        path: uri.path,
        queryParameters: queryParams,
      );
      
      debugPrint('PipedDataSource: Proxy URL: $proxyUri');
      return proxyUri.toString();
    } catch (e) {
      debugPrint('PipedDataSource: Error converting URL: $e');
      return directUrl;
    }
  }
  
  /// Get proxied stream URL using Piped API
  Future<StreamInfo?> getStreamUrl(String videoId) async {
    debugPrint('PipedDataSource: Getting stream for $videoId');
    
    // Try each instance until one works
    for (int attempt = 0; attempt < PipedInstances.apiInstances.length; attempt++) {
      try {
        final instance = PipedInstances.currentApiInstance;
        debugPrint('PipedDataSource: Trying $instance');
        
        final response = await _dio.get(
          '$instance/streams/$videoId',
          options: Options(
            // Let Dio throw only for 5xx; we'll handle 4xx here
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        
        if (response.statusCode == 200) {
          final body = response.data;
          if (body is! Map<String, dynamic>) {
            debugPrint('PipedDataSource: Unexpected response type from $instance: ${body.runtimeType}');
            PipedInstances.rotateApiInstance();
            continue;
          }
          final data = body;
          
          // Get audio streams from Piped response
          final audioStreams = data['audioStreams'] as List?;
          
          if (audioStreams != null && audioStreams.isNotEmpty) {
            debugPrint('PipedDataSource: Found ${audioStreams.length} streams');
            
            // Sort by bitrate (descending)
            final sortedStreams = List<Map<String, dynamic>>.from(audioStreams);
            sortedStreams.sort((a, b) {
              final bitrateA = (a['bitrate'] as num?) ?? 0;
              final bitrateB = (b['bitrate'] as num?) ?? 0;
              return bitrateB.compareTo(bitrateA);
            });
            
            // Try to find m4a first (better compatibility), then opus
            Map<String, dynamic>? selectedStream;
            selectedStream = sortedStreams.cast<Map<String, dynamic>?>().firstWhere(
              (s) => s != null && ((s['mimeType'] as String?)?.contains('mp4') ?? false),
              orElse: () => null,
            );
            selectedStream ??= sortedStreams.cast<Map<String, dynamic>?>().firstWhere(
              (s) => s != null && ((s['mimeType'] as String?)?.contains('opus') ?? false),
              orElse: () => null,
            );
            selectedStream ??= sortedStreams.first;
            
            final directUrl = selectedStream['url'] as String?;
            final bitrate = (selectedStream['bitrate'] as num?)?.toInt() ?? 128000;
            final mimeType = selectedStream['mimeType'] as String? ?? 'audio/webm';
            final contentLength = (selectedStream['contentLength'] as num?)?.toInt();
            
            if (directUrl != null && directUrl.isNotEmpty) {
              // Convert to proxy URL
              final proxyUrl = _convertToProxyUrl(directUrl);
              
              return StreamInfo(
                url: proxyUrl,
                codec: _extractCodec(mimeType),
                bitrate: bitrate ~/ 1000,
                container: _extractContainer(mimeType),
                quality: _bitrateToQuality(bitrate ~/ 1000),
                contentLength: contentLength,
                isAudioOnly: true,
              );
            }
          }
          
          // Fallback: Try HLS stream
          final hlsUrl = data['hls'] as String?;
          if (hlsUrl != null && hlsUrl.isNotEmpty) {
            debugPrint('PipedDataSource: Using HLS: $hlsUrl');
            return StreamInfo(
              url: hlsUrl,
              codec: 'aac',
              bitrate: 128,
              container: 'm3u8',
              quality: AudioQuality.medium,
              isAudioOnly: false,
            );
          }
        }
        
        PipedInstances.rotateApiInstance();
      } on DioException catch (e) {
        // Network / HTTP errors from this instance: log and rotate
        debugPrint('PipedDataSource: Error with ${PipedInstances.currentApiInstance}: $e');
        PipedInstances.rotateApiInstance();
        continue;
      } catch (e) {
        // Any other unexpected error: log and rotate
        debugPrint('PipedDataSource: Unexpected error with ${PipedInstances.currentApiInstance}: $e');
        PipedInstances.rotateApiInstance();
        continue;
      }
    }
    
    return null;
  }
  
  /// Get video details from Piped
  Future<Map<String, dynamic>?> getVideoDetails(String videoId) async {
    for (int attempt = 0; attempt < PipedInstances.apiInstances.length; attempt++) {
      try {
        final instance = PipedInstances.currentApiInstance;
        final response = await _dio.get(
          '$instance/streams/$videoId',
          options: Options(
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        
        if (response.statusCode == 200) {
          final body = response.data;
          if (body is! Map<String, dynamic>) {
            debugPrint('PipedDataSource: Unexpected response type from $instance: ${body.runtimeType}');
            PipedInstances.rotateApiInstance();
            continue;
          }
          return body;
        }
        
        PipedInstances.rotateApiInstance();
      } on DioException catch (e) {
        debugPrint('PipedDataSource: Error getting video details from ${PipedInstances.currentApiInstance}: $e');
        PipedInstances.rotateApiInstance();
        continue;
      } catch (e) {
        debugPrint('PipedDataSource: Unexpected error getting video details from ${PipedInstances.currentApiInstance}: $e');
        PipedInstances.rotateApiInstance();
        continue;
      }
    }
    return null;
  }
  
  /// Search for videos using Piped
  Future<List<Map<String, dynamic>>> search(String query, {String filter = 'music_songs'}) async {
    for (int attempt = 0; attempt < PipedInstances.apiInstances.length; attempt++) {
      try {
        final instance = PipedInstances.currentApiInstance;
        final response = await _dio.get(
          '$instance/search',
          queryParameters: {
            'q': query,
            'filter': filter,
          },
          options: Options(
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        
        if (response.statusCode == 200) {
          final body = response.data;
          if (body is! Map<String, dynamic>) {
            debugPrint('PipedDataSource: Unexpected search response type from $instance: ${body.runtimeType}');
            PipedInstances.rotateApiInstance();
            continue;
          }
          final data = body;
          final items = data['items'] as List?;
          if (items != null) {
            return items.whereType<Map<String, dynamic>>().toList();
          }
        }
        
        PipedInstances.rotateApiInstance();
      } on DioException catch (e) {
        debugPrint('PipedDataSource: Error searching on ${PipedInstances.currentApiInstance}: $e');
        PipedInstances.rotateApiInstance();
        continue;
      } catch (e) {
        debugPrint('PipedDataSource: Unexpected error searching on ${PipedInstances.currentApiInstance}: $e');
        PipedInstances.rotateApiInstance();
        continue;
      }
    }
    return [];
  }
  
  String _extractCodec(String mimeType) {
    if (mimeType.contains('opus')) return 'opus';
    if (mimeType.contains('mp4a') || mimeType.contains('aac')) return 'aac';
    if (mimeType.contains('vorbis')) return 'vorbis';
    return 'unknown';
  }
  
  String _extractContainer(String mimeType) {
    if (mimeType.contains('webm')) return 'webm';
    if (mimeType.contains('mp4')) return 'mp4';
    if (mimeType.contains('ogg')) return 'ogg';
    if (mimeType.contains('mpeg')) return 'mp3';
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
