import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../domain/entities/song.dart';
import '../../../../domain/entities/stream_info.dart';

/// Cobalt API instances for YouTube audio extraction
/// Cobalt provides actual proxy streams that work on mobile
class CobaltInstances {
  static const List<String> instances = [
    'https://api.cobalt.tools',
    'https://co.wuk.sh',
  ];
  
  static int _currentIndex = 0;
  
  static String get currentInstance => instances[_currentIndex];
  
  static void rotateInstance() {
    _currentIndex = (_currentIndex + 1) % instances.length;
  }
  
  static void reset() {
    _currentIndex = 0;
  }
}

/// Data source that uses Cobalt API for YouTube audio streaming
/// Cobalt provides direct download/stream URLs that work without auth
class CobaltDataSource {
  final Dio _dio;
  
  CobaltDataSource({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    },
  ));
  
  /// Get audio stream URL using Cobalt API
  Future<StreamInfo?> getStreamUrl(String videoId) async {
    final youtubeUrl = 'https://www.youtube.com/watch?v=$videoId';
    
    for (int attempt = 0; attempt < CobaltInstances.instances.length; attempt++) {
      try {
        final instance = CobaltInstances.currentInstance;
        debugPrint('CobaltDataSource: Trying $instance for video $videoId');
        
        final response = await _dio.post(
          '$instance/api/json',
          data: {
            'url': youtubeUrl,
            'vCodec': 'h264',
            'vQuality': '360',
            'aFormat': 'mp3',
            'isAudioOnly': true,
            'isNoTTWatermark': true,
            'isTTFullAudio': false,
            'disableMetadata': false,
          },
          options: Options(
            validateStatus: (status) => status != null && status < 500,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        );
        
        debugPrint('CobaltDataSource: Response status ${response.statusCode}');
        debugPrint('CobaltDataSource: Response data ${response.data}');
        
        if (response.statusCode == 200) {
          final data = response.data;
          
          if (data is Map<String, dynamic>) {
            // Check for stream URL in response
            final url = data['url'] as String?;
            
            if (url != null && url.isNotEmpty) {
              debugPrint('CobaltDataSource: Got stream URL: $url');
              
              return StreamInfo(
                url: url,
                codec: 'mp3',
                bitrate: 128,
                container: 'mp3',
                quality: AudioQuality.medium,
                isAudioOnly: true,
              );
            }
            
            // Check for audio array
            final audio = data['audio'] as String?;
            if (audio != null && audio.isNotEmpty) {
              debugPrint('CobaltDataSource: Got audio URL: $audio');
              
              return StreamInfo(
                url: audio,
                codec: 'mp3',
                bitrate: 128,
                container: 'mp3',
                quality: AudioQuality.medium,
                isAudioOnly: true,
              );
            }
          }
        }
        
        CobaltInstances.rotateInstance();
      } catch (e) {
        debugPrint('CobaltDataSource: Error with ${CobaltInstances.currentInstance}: $e');
        CobaltInstances.rotateInstance();
        continue;
      }
    }
    
    return null;
  }
  
  void dispose() {
    _dio.close();
  }
}
