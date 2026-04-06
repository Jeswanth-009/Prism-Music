import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service to download YouTube audio streams with proper headers
/// This bypasses IP restrictions by downloading with proper headers first
class AudioDownloaderService {
  static final Dio _dio = Dio();
  
  /// Download audio stream and save to temporary file
  /// Returns the local file path
  static Future<String> downloadAndCache(String streamUrl, String songId) async {
    try {
      debugPrint('AudioDownloader: Downloading $streamUrl');
      
      // Get temp directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/prism_audio_$songId.webm';
      
      // Check if already cached
      final file = File(filePath);
      if (await file.exists()) {
        final fileSize = await file.length();
        if (fileSize > 1000) { // At least 1KB
          debugPrint('AudioDownloader: Using cached file $filePath');
          return filePath;
        }
      }
      
      // Download with proper headers
      await _dio.download(
        streamUrl,
        filePath,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': '*/*',
            'Accept-Encoding': 'identity;q=1, *;q=0',
            'Accept-Language': 'en-US,en;q=0.9',
            'Connection': 'keep-alive',
            'Origin': 'https://www.youtube.com',
            'Referer': 'https://www.youtube.com/',
          },
          responseType: ResponseType.stream,
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = (received / total * 100).toStringAsFixed(0);
            debugPrint('AudioDownloader: Download progress: $progress%');
          }
        },
      );
      
      debugPrint('AudioDownloader: Downloaded to $filePath');
      return filePath;
      
    } catch (e) {
      debugPrint('AudioDownloader: Error downloading - $e');
      rethrow;
    }
  }
  
  /// Clear old cached audio files
  static Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      
      for (final file in files) {
        if (file is File && file.path.contains('prism_audio_')) {
          await file.delete();
        }
      }
      
      debugPrint('AudioDownloader: Cache cleared');
    } catch (e) {
      debugPrint('AudioDownloader: Error clearing cache - $e');
    }
  }
}
