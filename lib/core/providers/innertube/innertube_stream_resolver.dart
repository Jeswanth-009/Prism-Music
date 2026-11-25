import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../domain/entities/song.dart';
import '../../../domain/entities/stream_info.dart';
import '../../error/exceptions.dart';
import '../../services/stream_cache_service.dart';
import '../audio_stream_resolver.dart';
import 'innertube_client.dart';
import 'network_resolver_memory.dart';

/// Audio stream resolver using InnerTube client context ladder (Android / iOS / Web Remix)
/// with fallback to secondary resolvers and network memory tracking.
class InnerTubeStreamResolver implements AudioStreamResolver {
  static const List<InnerTubeClientContext> defaultContexts = [
    InnerTubeClientContext.android,
    InnerTubeClientContext.ios,
    InnerTubeClientContext.webRemix,
  ];

  final InnerTubeClient _client;
  final NetworkResolverMemory _memory;
  final AudioStreamResolver? _fallbackResolver;
  final List<InnerTubeClientContext> _contexts;

  InnerTubeStreamResolver({
    InnerTubeClient? client,
    NetworkResolverMemory? memory,
    AudioStreamResolver? fallbackResolver,
    List<InnerTubeClientContext>? contexts,
  })  : _client = client ?? InnerTubeClient(),
        _memory = memory ?? NetworkResolverMemory(),
        _fallbackResolver = fallbackResolver,
        _contexts = contexts ?? defaultContexts;

  @override
  String get resolverName => 'innertube_ladder';

  @override
  bool get isAvailable => true;

  @override
  Future<StreamInfo?> resolveStream(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    final videoId = song.playableId;
    final stopwatch = Stopwatch()..start();
    bool sawGeoRestriction = false;
    String? geoReason;

    for (final ctx in _contexts) {
      try {
        final formats = await _client.fetchAudioFormats(videoId, context: ctx);
        if (formats.isNotEmpty) {
          // Select format matching quality
          final selected = preferredQuality == AudioQuality.low
              ? formats.last
              : formats.first;

          stopwatch.stop();
          unawaited(
            _memory.recordResolution(
              networkType: 'default',
              resolverName: 'innertube_${ctx.name}',
              success: true,
              latency: stopwatch.elapsed,
            ),
          );

          final actualBitrate = selected.bitrateKbps;
          final quality = actualBitrate >= 320
              ? AudioQuality.ultra
              : actualBitrate >= 160
                  ? AudioQuality.high
                  : actualBitrate >= 96
                      ? AudioQuality.medium
                      : AudioQuality.low;

          return StreamInfo(
            url: selected.url,
            codec: selected.mimeType.contains('opus') ? 'opus' : 'mp4a',
            container: selected.mimeType.contains('webm') ? 'webm' : 'mp4',
            bitrate: actualBitrate,
            quality: quality,
            contentLength: selected.contentLength,
            expiresAt: StreamCacheService.extractExpiryFromUrl(selected.url),
            headers: ctx.playbackHeaders,
            isAudioOnly: true,
            streamProvenance: 'innertube_${ctx.name}',
            matchConfidence: 1.0,
          );
        }
      } catch (e) {
        final lower = e.toString().toLowerCase();
        if (lower.contains('your country') || lower.contains('geo')) {
          sawGeoRestriction = true;
          geoReason = e.toString();
        }
        debugPrint(
          'InnerTubeStreamResolver: Context ${ctx.name} failed for $videoId: $e',
        );
      }
    }

    // Attempt fallback resolver if configured
    if (_fallbackResolver != null) {
      try {
        final fallbackStream = await _fallbackResolver.resolveStream(
          song,
          preferredQuality: preferredQuality,
        );
        if (fallbackStream != null) {
          stopwatch.stop();
          unawaited(
            _memory.recordResolution(
              networkType: 'default',
              resolverName: _fallbackResolver.resolverName,
              success: true,
              latency: stopwatch.elapsed,
            ),
          );
          return fallbackStream;
        }
      } catch (e) {
        debugPrint(
          'InnerTubeStreamResolver: Fallback ${_fallbackResolver.resolverName} failed: $e',
        );
      }
    }

    stopwatch.stop();
    unawaited(
      _memory.recordResolution(
        networkType: 'default',
        resolverName: resolverName,
        success: false,
        latency: stopwatch.elapsed,
      ),
    );

    if (sawGeoRestriction) {
      throw GeoRestrictionException(
        provider: 'YouTube InnerTube',
        statusCode: 403,
        message: geoReason ?? 'This track is unavailable in your region.',
      );
    }

    return null;
  }
}
