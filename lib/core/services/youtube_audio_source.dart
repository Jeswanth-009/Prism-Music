// ignore_for_file: experimental_member_use
import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;
import 'stream_cache_service.dart';
import 'youtube_manifest_resolver.dart';

/// Metadata for an external fallback audio stream resolved outside [YouTubeManifestResolver].
class ResolvedExternalAudioStream {
  final String url;
  final int? contentLength;
  final String? contentType;
  final Map<String, String>? headers;

  const ResolvedExternalAudioStream({
    required this.url,
    this.contentLength,
    this.contentType,
    this.headers,
  });
}

/// Callback type for resolving streams when [YouTubeManifestResolver] cannot.
typedef ExternalAudioStreamResolver =
    Future<ResolvedExternalAudioStream?> Function(String videoId, String quality);

const String _defaultStreamUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/// Parses the total byte length from an HTTP `Content-Range` header value.
int? parseTotalBytesFromContentRange(String? contentRange) {
  if (contentRange == null) return null;
  final slashIdx = contentRange.lastIndexOf('/');
  if (slashIdx == -1) return null;
  return int.tryParse(contentRange.substring(slashIdx + 1).trim());
}

/// Parses the chunk byte length (`end - start + 1`) from a `Content-Range` header value.
int? parseRangeSpanFromContentRange(String? contentRange) {
  if (contentRange == null) return null;
  final match = RegExp(r'bytes\s+(\d+)-(\d+)/').firstMatch(contentRange);
  if (match == null) return null;
  final start = int.tryParse(match.group(1)!);
  final end = int.tryParse(match.group(2)!);
  if (start == null || end == null || end < start) return null;
  return end - start + 1;
}

/// Opens an upstream HTTP byte-range stream for `just_audio`'s local proxy without
/// aborting concurrent sibling range requests and ensuring socket cleanup on cancel.
Future<StreamAudioResponse> openHttpRangeAudioStream({
  required String streamUrl,
  required int start,
  int? end,
  required int totalBytes,
  required String fallbackContentType,
  Map<String, String>? headers,
  required Set<http.Client> activeClients,
}) async {
  final clampedEnd = (totalBytes > 0 && end != null && end > totalBytes) ? totalBytes : end;
  final rangeEnd = clampedEnd ?? (totalBytes > 0 ? totalBytes : null);

  final request = http.Request('GET', Uri.parse(streamUrl));
  if (rangeEnd != null && rangeEnd > start) {
    request.headers['range'] = 'bytes=$start-${rangeEnd - 1}';
  } else {
    request.headers['range'] = 'bytes=$start-';
  }
  if (headers != null && headers.isNotEmpty) {
    headers.forEach((key, value) {
      final lower = key.toLowerCase();
      if (lower == 'range' || lower == 'connection' || lower == 'host') return;
      request.headers[key] = value;
    });
  }
  if (!request.headers.keys.any((k) => k.toLowerCase() == 'user-agent')) {
    request.headers['User-Agent'] = _defaultStreamUserAgent;
  }

  final client = http.Client();
  activeClients.add(client);

  void closeClient() {
    if (activeClients.remove(client)) {
      client.close();
    }
  }

  try {
    final response = await client.send(request).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        closeClient();
        throw TimeoutException('HTTP stream request timed out');
      },
    );

    if (response.statusCode != 206 && response.statusCode != 200) {
      closeClient();
      throw Exception('HTTP ${response.statusCode}: Failed to get stream');
    }

    int resolvedSourceLength = totalBytes;
    final contentRange = response.headers['content-range'];
    if (resolvedSourceLength <= 0 && contentRange != null) {
      resolvedSourceLength = parseTotalBytesFromContentRange(contentRange) ?? 0;
    }

    int? resolvedContentLength = response.contentLength ??
        parseRangeSpanFromContentRange(contentRange) ??
        (rangeEnd != null && rangeEnd > start ? rangeEnd - start : null) ??
        (resolvedSourceLength > start ? resolvedSourceLength - start : null);

    // just_audio's proxy computes `offset! + contentLength! - 1` whenever a
    // Range header is present and offset != null. A null contentLength causes an
    // unhandled Null check crash (HTTP 500). If length is unknown, read-buffer
    // small responses or fail so caller can re-resolve a size-known stream.
    List<int>? bufferedBytes;
    if (resolvedContentLength == null) {
      if (response.statusCode == 200 && start == 0 && clampedEnd == null) {
        final bytes = await response.stream.toBytes().timeout(
          const Duration(seconds: 15),
        );
        closeClient();
        resolvedContentLength = bytes.length;
        if (resolvedSourceLength <= 0) {
          resolvedSourceLength = bytes.length;
        }
        bufferedBytes = bytes;
      } else {
        closeClient();
        throw Exception('Upstream omitted content-length on range response');
      }
    }

    final Stream<List<int>> byteStream;
    if (bufferedBytes != null) {
      byteStream = Stream<List<int>>.value(bufferedBytes);
    } else {
      late final StreamController<List<int>> controller;
      StreamSubscription<List<int>>? subscription;
      controller = StreamController<List<int>>(
        onListen: () {
          subscription = response.stream.listen(
            controller.add,
            onError: (Object error, StackTrace stack) {
              closeClient();
              if (!controller.isClosed) {
                controller.addError(error, stack);
              }
            },
            onDone: () {
              closeClient();
              if (!controller.isClosed) {
                controller.close();
              }
            },
            cancelOnError: false,
          );
        },
        onPause: () => subscription?.pause(),
        onResume: () => subscription?.resume(),
        onCancel: () async {
          await subscription?.cancel();
          closeClient();
        },
      );
      byteStream = controller.stream;
    }

    return StreamAudioResponse(
      sourceLength: resolvedSourceLength > 0 ? resolvedSourceLength : resolvedContentLength,
      contentLength: resolvedContentLength,
      offset: start,
      stream: byteStream,
      contentType: response.headers['content-type'] ?? fallbackContentType,
    );
  } catch (_) {
    closeClient();
    rethrow;
  }
}

/// Cached stream info with expiration tracking
class _CachedStream {
  final String url;
  final int totalBytes;
  final String contentType;
  final Map<String, String>? headers;
  final DateTime cachedAt;

  _CachedStream({
    required this.url,
    required this.totalBytes,
    required this.contentType,
    this.headers,
  }) : cachedAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(cachedAt) > const Duration(minutes: 45) ||
      StreamCacheService.isUrlExpired(url);
}

/// Custom audio source that streams YouTube audio directly in Flutter
class YouTubeAudioSource extends StreamAudioSource {
  final String videoId;
  final String quality;
  final String? initialStreamUrl;
  final int? initialContentLength;
  final String? initialContentType;
  final Map<String, String>? initialHeaders;

  static final _ytExplode = YoutubeExplode();

  /// Optional fallback resolver wired at app startup so queued YouTube tracks
  /// can fall back cleanly to InnerTube/StreamLoader if YouTubeExplode fails.
  static ExternalAudioStreamResolver? streamFallbackResolver;

  /// Global cache shared across all instances - avoids re-fetching for same video
  static final Map<String, _CachedStream> _globalCache = {};
  static const _maxCacheSize = 50; // Limit memory usage

  _CachedStream? _cachedStreamInfo;
  DateTime? _cacheTime;
  int? _lastRequestPosition;
  final Set<http.Client> _activeClients = {};

  // YouTube stream URLs can expire, cache for 45 minutes (conservative)
  static const _cacheExpirationDuration = Duration(minutes: 45);
  static const _maxRetries = 3;

  YouTubeAudioSource({
    required this.videoId,
    this.quality = 'high',
    this.initialStreamUrl,
    this.initialContentLength,
    this.initialContentType,
    this.initialHeaders,
    super.tag,
  });

  /// Selects the stream matching [quality] from bitrate-descending sorted [streams].
  static AudioOnlyStreamInfo? selectStreamForQuality(
    List<AudioOnlyStreamInfo> sortedDescStreams,
    String quality,
  ) {
    if (sortedDescStreams.isEmpty) return null;
    switch (quality.toLowerCase()) {
      case 'low':
        return sortedDescStreams.lastOrNull;
      case 'medium':
        final midStreams = sortedDescStreams.where((s) {
          final kbps = s.bitrate.kiloBitsPerSecond;
          return kbps >= 96 && kbps <= 160;
        }).toList();
        if (midStreams.isNotEmpty) return midStreams.first;
        return sortedDescStreams[sortedDescStreams.length ~/ 2];
      case 'high':
      case 'lossless':
      default:
        // youtube_explode_dart 3.1.0 sortByBitrate() sorts descending (highest first).
        return sortedDescStreams.firstOrNull;
    }
  }

  /// Clear cached stream manifests globally for a videoId
  static void invalidate(String videoId) {
    _globalCache.removeWhere(
      (k, _) => k == videoId || k.startsWith('${videoId}_'),
    );
  }

  /// Get stream info with global + instance caching.
  ///
  /// When [preferFallback] is `true` (e.g. a previously resolved manifest stream
  /// returned HTTP 403/network failure during streaming), [streamFallbackResolver]
  /// is attempted before retrying [YouTubeManifestResolver] so retries fail over
  /// cleanly to InnerTube/Piped/Invidious instead of looping on the same client.
  Future<_CachedStream> _getStreamInfo({
    bool forceRefresh = false,
    bool preferFallback = false,
  }) async {
    final cacheKey = '${videoId}_$quality';
    if (!forceRefresh) {
      final globalCached = _globalCache[cacheKey];
      if (globalCached != null && !globalCached.isExpired) {
        debugPrint('YouTubeAudioSource: Global cache HIT for $cacheKey');
        _cachedStreamInfo = globalCached;
        _cacheTime = globalCached.cachedAt;
        return globalCached;
      }
    }

    // Check instance cache
    final now = DateTime.now();
    final isCacheValid = _cachedStreamInfo != null &&
        !_cachedStreamInfo!.isExpired &&
        _cacheTime != null &&
        now.difference(_cacheTime!) < _cacheExpirationDuration;

    if (forceRefresh || !isCacheValid) {
      _cachedStreamInfo = null;
      _cacheTime = null;
    }

    if (_cachedStreamInfo != null) {
      debugPrint('YouTubeAudioSource: Instance cache HIT for $videoId');
      return _cachedStreamInfo!;
    }

    try {
      debugPrint(
        'YouTubeAudioSource: Fetching fresh manifest for $videoId '
        '(preferFallback=$preferFallback)',
      );
      _CachedStream? resolved;

      Future<_CachedStream?> tryFallback() async {
        if (streamFallbackResolver == null) return null;
        final fallback = await streamFallbackResolver!(videoId, quality);
        if (fallback != null && fallback.url.isNotEmpty) {
          return _CachedStream(
            url: fallback.url,
            totalBytes: fallback.contentLength ?? 0,
            contentType: fallback.contentType ?? 'audio/mp4',
            headers: fallback.headers,
          );
        }
        return null;
      }

      if (preferFallback) {
        resolved = await tryFallback();
      }

      if (resolved == null) {
        try {
          final manifest = await YouTubeManifestResolver.fetchAudioManifest(
            _ytExplode,
            videoId,
          );
          final supportedStreams = manifest.audioOnly.sortByBitrate();
          final audioStream = selectStreamForQuality(supportedStreams, quality);
          if (audioStream != null) {
            resolved = _CachedStream(
              url: audioStream.url.toString(),
              totalBytes: audioStream.size.totalBytes,
              contentType: audioStream.codec.mimeType,
            );
            debugPrint(
              'YouTubeAudioSource: Selected stream - ${audioStream.codec.subtype} ${audioStream.bitrate.kiloBitsPerSecond}kbps',
            );
          }
        } catch (e) {
          dev.log(
            'YouTubeManifestResolver failed for $videoId: $e; trying fallback resolver',
            name: 'YouTubeAudioSource',
          );
        }
      }

      resolved ??= await tryFallback();

      if (resolved == null) {
        throw Exception('No audio streams available for video: $videoId');
      }

      _cachedStreamInfo = resolved;
      _cacheTime = DateTime.now();

      if (_globalCache.length >= _maxCacheSize) {
        _globalCache.removeWhere((_, v) => v.isExpired);
        if (_globalCache.length >= _maxCacheSize) {
          _globalCache.remove(_globalCache.keys.first);
        }
      }
      _globalCache[cacheKey] = resolved;

      return resolved;
    } catch (e) {
      dev.log('Failed to get stream info: $e', name: 'YouTubeAudioSource');
      rethrow;
    }
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    debugPrint('YouTubeAudioSource: request(start: $start, end: $end)');
    start ??= 0;

    final isSeekingBackward = _lastRequestPosition != null &&
        start < _lastRequestPosition! - 1024 * 1024;
    if (isSeekingBackward) {
      debugPrint(
        'YouTubeAudioSource: Detected significant backward seek from $_lastRequestPosition to $start',
      );
    }
    _lastRequestPosition = start;

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        String streamUrl;
        int totalBytes;
        String contentType;
        Map<String, String>? headers;

        final useInitialUrl = attempt == 0 &&
            initialStreamUrl != null &&
            initialStreamUrl!.isNotEmpty &&
            !StreamCacheService.isUrlExpired(initialStreamUrl!);

        if (useInitialUrl) {
          streamUrl = initialStreamUrl!;
          totalBytes = initialContentLength ?? 0;
          contentType = initialContentType ?? 'audio/mp4';
          headers = initialHeaders;
        } else {
          final forceRefresh = attempt > 0 || initialStreamUrl != null;
          final resolved = await _getStreamInfo(
            forceRefresh: forceRefresh,
            preferFallback: attempt > 0,
          );
          streamUrl = resolved.url;
          totalBytes = resolved.totalBytes;
          contentType = resolved.contentType;
          headers = resolved.headers;
        }

        return await openHttpRangeAudioStream(
          streamUrl: streamUrl,
          start: start,
          end: end,
          totalBytes: totalBytes,
          fallbackContentType: contentType,
          headers: headers,
          activeClients: _activeClients,
        );
      } catch (e) {
        debugPrint(
          'YouTubeAudioSource: Stream error (attempt ${attempt + 1}/$_maxRetries): $e',
        );

        if (attempt < _maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
          clearCache();
        } else {
          dev.log(
            'Failed to load audio after $_maxRetries attempts: $e',
            name: 'YouTubeAudioSource',
          );
          throw Exception(
            'Failed to load audio from YouTube after $_maxRetries attempts: $e',
          );
        }
      }
    }

    throw Exception('Failed to load audio from YouTube');
  }

  /// Clear cached stream info (useful when stream expires) without killing active sibling sockets
  void clearCache() {
    _cachedStreamInfo = null;
    _cacheTime = null;
    _lastRequestPosition = null;
    invalidate(videoId);
  }

  /// Check if stream info is cached and valid for a video ID
  static bool isStreamCached(String videoId, {String quality = 'high'}) {
    final cacheKey = '${videoId}_$quality';
    final cached = _globalCache[cacheKey];
    return cached != null && !cached.isExpired;
  }

  /// Pre-warm the global cache for a video ID (call from prefetch logic)
  static Future<void> prewarmCache(String videoId, {String quality = 'high'}) async {
    final cacheKey = '${videoId}_$quality';
    final cached = _globalCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      debugPrint('YouTubeAudioSource.prewarmCache: Already cached for $cacheKey');
      return;
    }

    try {
      debugPrint('YouTubeAudioSource.prewarmCache: Pre-warming cache for $cacheKey');

      _CachedStream? resolved;
      try {
        final manifest = await YouTubeManifestResolver.fetchAudioManifest(
          _ytExplode,
          videoId,
        );
        final supportedStreams = manifest.audioOnly.sortByBitrate();
        final audioStream = selectStreamForQuality(supportedStreams, quality);
        if (audioStream != null) {
          resolved = _CachedStream(
            url: audioStream.url.toString(),
            totalBytes: audioStream.size.totalBytes,
            contentType: audioStream.codec.mimeType,
          );
        }
      } catch (e) {
        debugPrint('YouTubeAudioSource.prewarmCache: Manifest resolver failed for $videoId ($e)');
      }

      if (resolved == null && streamFallbackResolver != null) {
        final fallback = await streamFallbackResolver!(videoId, quality);
        if (fallback != null && fallback.url.isNotEmpty) {
          resolved = _CachedStream(
            url: fallback.url,
            totalBytes: fallback.contentLength ?? 0,
            contentType: fallback.contentType ?? 'audio/mp4',
            headers: fallback.headers,
          );
        }
      }

      if (resolved != null) {
        if (_globalCache.length >= _maxCacheSize) {
          _globalCache.removeWhere((_, v) => v.isExpired);
          if (_globalCache.length >= _maxCacheSize) {
            _globalCache.remove(_globalCache.keys.first);
          }
        }
        _globalCache[cacheKey] = resolved;
        debugPrint('YouTubeAudioSource.prewarmCache: Cached stream for $cacheKey');
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
