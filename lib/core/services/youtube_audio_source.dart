import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;

/// Cached stream info with expiration tracking
class _CachedStream {
  final AudioOnlyStreamInfo streamInfo;
  final DateTime cachedAt;
  
  _CachedStream(this.streamInfo) : cachedAt = DateTime.now();
  
  bool get isExpired => DateTime.now().difference(cachedAt) > const Duration(minutes: 45);
}

/// Custom audio source that streams YouTube audio directly in Flutter
/// Inspired by BloomeeTunes implementation - no external proxy needed
class YouTubeAudioSource extends StreamAudioSource {
  final String videoId;
  final String quality;

  static final _ytExplode = YoutubeExplode();
  
  /// Global cache shared across all instances - avoids re-fetching for same video
  static final Map<String, _CachedStream> _globalCache = {};
  static const _maxCacheSize = 50; // Limit memory usage
  
  AudioOnlyStreamInfo? _cachedStreamInfo;
  DateTime? _cacheTime;
  int? _lastRequestPosition;
  
  // YouTube stream URLs can expire, cache for 45 minutes (conservative)
  static const _cacheExpirationDuration = Duration(minutes: 45);
  static const _maxRetries = 3;

  YouTubeAudioSource({
    required this.videoId,
    this.quality = 'high',
    dynamic tag,
  }) : super(tag: tag);

  /// Get stream info with global + instance caching
  Future<AudioOnlyStreamInfo> _getStreamInfo({bool forceRefresh = false}) async {
    // Check global cache first (shared across all instances)
    final globalCached = _globalCache[videoId];
    if (!forceRefresh && globalCached != null && !globalCached.isExpired) {
      debugPrint('YouTubeAudioSource: Global cache HIT for $videoId');
      _cachedStreamInfo = globalCached.streamInfo;
      _cacheTime = globalCached.cachedAt;
      return globalCached.streamInfo;
    }
    
    // Check instance cache
    final now = DateTime.now();
    final isCacheValid = _cachedStreamInfo != null && 
                        _cacheTime != null && 
                        now.difference(_cacheTime!) < _cacheExpirationDuration;
    
    // Clear cache if force refresh or if expired
    if (forceRefresh || !isCacheValid) {
      _cachedStreamInfo = null;
      _cacheTime = null;
    }
    
    if (_cachedStreamInfo != null) {
      debugPrint('YouTubeAudioSource: Instance cache HIT for $videoId');
      return _cachedStreamInfo!;
    }

    try {
      debugPrint('YouTubeAudioSource: Fetching fresh manifest for $videoId');
      
      StreamManifest manifest;
      try {
        // Use AndroidVr client for better reliability (learned from BloomeeTunes)
        manifest = await _ytExplode.videos.streams.getManifest(
          videoId,
          requireWatchPage: true,
          ytClients: [YoutubeApiClient.androidVr],
        );
      } catch (e) {
        debugPrint('YouTubeAudioSource: AndroidVr client failed, trying default clients: $e');
        // Fallback to default clients
        manifest = await _ytExplode.videos.streamsClient.getManifest(videoId);
      }

      final supportedStreams = manifest.audioOnly.sortByBitrate();
      
      if (supportedStreams.isEmpty) {
        throw Exception('No audio streams available for video: $videoId');
      }

      // Select stream based on quality
      final audioStream = quality == 'high'
          ? supportedStreams.lastOrNull
          : supportedStreams.firstOrNull;

      if (audioStream == null) {
        throw Exception('No suitable audio stream found');
      }

      debugPrint('YouTubeAudioSource: Selected stream - ${audioStream.codec.subtype} ${audioStream.bitrate.kiloBitsPerSecond}kbps');
      
      // Store in instance cache
      _cachedStreamInfo = audioStream;
      _cacheTime = DateTime.now();
      
      // Store in global cache (with size limit)
      if (_globalCache.length >= _maxCacheSize) {
        // Remove oldest expired entries first, then oldest entries
        _globalCache.removeWhere((_, v) => v.isExpired);
        if (_globalCache.length >= _maxCacheSize) {
          final oldestKey = _globalCache.keys.first;
          _globalCache.remove(oldestKey);
        }
      }
      _globalCache[videoId] = _CachedStream(audioStream);
      
      return audioStream;
    } catch (e) {
      dev.log('Failed to get stream info: $e', name: 'YouTubeAudioSource');
      rethrow;
    }
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    debugPrint('YouTubeAudioSource: request(start: $start, end: $end)');
    start ??= 0;
    
    // Detect backward seeking (seeking to earlier position than last request)
    final isSeekingBackward = _lastRequestPosition != null && start < _lastRequestPosition! - 1024 * 1024; // Only reset if seeking back more than 1MB
    if (isSeekingBackward) {
      debugPrint('YouTubeAudioSource: Detected significant backward seek from $_lastRequestPosition to $start');
      // Don't clear cache on minor backward seeks - only on major jumps
    }
    _lastRequestPosition = start;
    
    // Try up to 3 times with fresh URLs
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        // Only force refresh on retry attempts, not the first try
        final forceRefresh = attempt > 0;
        
        var audioStream = await _getStreamInfo(forceRefresh: forceRefresh);
        final totalBytes = audioStream.size.totalBytes;
        
        // Ensure end doesn't exceed total bytes
        if (end != null && end > totalBytes) {
          end = totalBytes;
        }
        
        final rangeEnd = end ?? totalBytes;

        debugPrint('YouTubeAudioSource: Requesting bytes $start-$rangeEnd/$totalBytes (attempt ${attempt + 1}/$_maxRetries)');

        // Use HTTP client with proper range headers for better reliability
        final streamUrl = audioStream.url.toString();
        debugPrint('YouTubeAudioSource: Stream URL: $streamUrl');
        
        final request = http.Request('GET', Uri.parse(streamUrl));
        
        // Add range header for seeking support
        request.headers['range'] = 'bytes=$start-${rangeEnd - 1}';
        request.headers['user-agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
        
        final response = await request.send();
        debugPrint('YouTubeAudioSource: Response status: ${response.statusCode}');
        debugPrint('YouTubeAudioSource: Response headers: ${response.headers}');
        
        if (response.statusCode != 206 && response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}: Failed to get stream');
        }

        return StreamAudioResponse(
          sourceLength: totalBytes,
          contentLength: rangeEnd - start,
          offset: start,
          stream: response.stream,
          contentType: audioStream.codec.mimeType,
        );
      } catch (e) {
        debugPrint('YouTubeAudioSource: Stream error (attempt ${attempt + 1}/$_maxRetries): $e');
        
        // If this isn't the last attempt, wait a bit before retrying
        if (attempt < _maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          // Clear cache to force fresh URL on next attempt
          clearCache();
        } else {
          // All retries failed
          dev.log('Failed to load audio after $_maxRetries attempts: $e', name: 'YouTubeAudioSource');
          throw Exception('Failed to load audio from YouTube after $_maxRetries attempts: $e');
        }
      }
    }
    
    // Should never reach here, but just in case
    throw Exception('Failed to load audio from YouTube');
  }

  /// Clear cached stream info (useful when stream expires)
  void clearCache() {
    _cachedStreamInfo = null;
    _cacheTime = null;
    _lastRequestPosition = null;
  }

  /// Pre-warm the global cache for a video ID (call from prefetch logic)
  static Future<void> prewarmCache(String videoId, {String quality = 'high'}) async {
    // Check if already cached
    final cached = _globalCache[videoId];
    if (cached != null && !cached.isExpired) {
      debugPrint('YouTubeAudioSource.prewarmCache: Already cached for $videoId');
      return;
    }
    
    try {
      debugPrint('YouTubeAudioSource.prewarmCache: Pre-warming cache for $videoId');
      
      StreamManifest manifest;
      try {
        manifest = await _ytExplode.videos.streams.getManifest(
          videoId,
          requireWatchPage: true,
          ytClients: [YoutubeApiClient.androidVr],
        );
      } catch (e) {
        manifest = await _ytExplode.videos.streamsClient.getManifest(videoId);
      }

      final supportedStreams = manifest.audioOnly.sortByBitrate();
      if (supportedStreams.isEmpty) return;

      final audioStream = quality == 'high'
          ? supportedStreams.lastOrNull
          : supportedStreams.firstOrNull;

      if (audioStream != null) {
        // Store in global cache
        if (_globalCache.length >= _maxCacheSize) {
          _globalCache.removeWhere((_, v) => v.isExpired);
          if (_globalCache.length >= _maxCacheSize) {
            final oldestKey = _globalCache.keys.first;
            _globalCache.remove(oldestKey);
          }
        }
        _globalCache[videoId] = _CachedStream(audioStream);
        debugPrint('YouTubeAudioSource.prewarmCache: Cached stream for $videoId');
      }
    } catch (e) {
      debugPrint('YouTubeAudioSource.prewarmCache: Failed for $videoId: $e');
    }
  }

  /// Clear all global cached streams
  static void clearGlobalCache() {
    _globalCache.clear();
    debugPrint('YouTubeAudioSource: Global cache cleared');
  }

  /// Dispose resources
  static void dispose() {
    _globalCache.clear();
    _ytExplode.close();
  }
}
