import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../domain/entities/stream_info.dart';
import '../../../../domain/entities/song.dart';
import '../../../../core/services/instance_health_service.dart';

/// Legacy compatibility wrapper delegating to [InstanceHealthService].
class PipedInstances {
  static final InstanceHealthService _health = InstanceHealthService();

  static List<String> get apiInstances => InstanceHealthService.defaultPipedApiInstances;
  static List<String> get proxyInstances => InstanceHealthService.defaultPipedProxyInstances;

  static String get currentApiInstance => _health.getHealthyPipedApi();
  static String get currentProxyInstance => _health.getHealthyPipedProxy();

  static void rotateApiInstance() {}
  static void rotateProxyInstance() {}
  static void reset() {
    _health.resetQuarantines();
  }
}

/// Data source that uses Piped API for YouTube audio streaming with dynamic instance health
class PipedDataSource {
  final Dio _dio;
  final InstanceHealthService _healthService;
  
  PipedDataSource({Dio? dio, InstanceHealthService? healthService})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 4),
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              },
            )),
        _healthService = healthService ?? InstanceHealthService();
  
  /// Convert a direct YouTube stream URL to a Piped proxy URL
  String _convertToProxyUrl(String directUrl) {
    try {
      final uri = Uri.parse(directUrl);
      final originalHost = uri.host;
      final proxyBase = _healthService.getHealthyPipedProxy();
      
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
  
  /// Get proxied stream URL using Piped API with per-instance health and quarantine
  Future<StreamInfo?> getStreamUrl(String videoId) async {
    debugPrint('PipedDataSource: Getting stream for $videoId');
    
    // Try up to 2 healthy instances with fast timeouts
    for (int attempt = 0; attempt < 2; attempt++) {
      final instance = _healthService.getHealthyPipedApi();
      final stopwatch = Stopwatch()..start();
      try {
        debugPrint('PipedDataSource: Trying healthy instance $instance (attempt $attempt)');
        
        final response = await _dio.get(
          '$instance/streams/$videoId',
          options: Options(
            sendTimeout: const Duration(milliseconds: 4000),
            receiveTimeout: const Duration(milliseconds: 4000),
            validateStatus: (status) => status != null && status < 500,
          ),
        ).timeout(const Duration(milliseconds: 4500));
        stopwatch.stop();
        
        if (response.statusCode == 200) {
          final body = response.data;
          if (body is! Map<String, dynamic>) {
            debugPrint('PipedDataSource: Unexpected response type from $instance: ${body.runtimeType}');
            _healthService.recordFailure(instance, 'Unexpected response shape');
            continue;
          }
          final data = body;
          _healthService.recordSuccess(instance, stopwatch.elapsed);
          
          // Get audio streams from Piped response
          final audioStreams = data['audioStreams'] as List?;
          
          if (audioStreams != null && audioStreams.isNotEmpty) {
            debugPrint('PipedDataSource: Found ${audioStreams.length} streams on $instance');
            
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
                streamProvenance: 'piped_proxy',
                matchConfidence: 0.90,
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
              streamProvenance: 'piped_proxy',
              matchConfidence: 0.85,
            );
          }
        } else {
          _healthService.recordFailure(instance, 'HTTP ${response.statusCode}');
        }
      } catch (e) {
        stopwatch.stop();
        debugPrint('PipedDataSource: Error with $instance: $e');
        _healthService.recordFailure(instance, e);
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
  
  AudioQuality _bitrateToQuality(int bitrateKbps, [String? codec]) {
    final lowerCodec = codec?.toLowerCase() ?? '';
    if (lowerCodec.contains('flac') ||
        lowerCodec.contains('alac') ||
        lowerCodec.contains('wav')) {
      return AudioQuality.lossless;
    }
    if (bitrateKbps >= 320) return AudioQuality.lossless;
    if (bitrateKbps >= 160) return AudioQuality.high;
    if (bitrateKbps >= 96) return AudioQuality.medium;
    return AudioQuality.low;
  }
  
  void dispose() {
    _dio.close();
  }
}
