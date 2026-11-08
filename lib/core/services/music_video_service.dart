import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

import '../../domain/entities/song.dart';
import '../../domain/entities/stream_info.dart';

/// Service responsible for resolving and managing music video streams from YouTube.
class MusicVideoService {
  final yt.YoutubeExplode _youtube;
  final Map<String, StreamInfo> _cache = {};

  MusicVideoService({yt.YoutubeExplode? youtube})
      : _youtube = youtube ?? yt.YoutubeExplode();

  /// Check whether a song can potentially stream a music video
  bool isVideoAvailable(Song? song) {
    if (song == null) return false;
    if (song.youtubeId != null && song.youtubeId!.isNotEmpty) return true;
    if (song.source == MusicSource.youtube && song.id.isNotEmpty) return true;
    return false;
  }

  /// Resolve video stream URL (preferring muxed 720p/480p/360p MP4)
  Future<StreamInfo?> getVideoStream(
    String videoId, {
    String preferredQuality = '720p',
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache.containsKey(videoId)) {
      final cached = _cache[videoId]!;
      if (!cached.isExpired) {
        return cached;
      }
      _cache.remove(videoId);
    }

    try {
      final manifest = await _fetchManifest(videoId);
      
      // Look for muxed streams first (combined video + audio)
      final muxedStreams = manifest.muxed.toList();
      if (muxedStreams.isNotEmpty) {
        yt.MuxedStreamInfo? selectedStream;

        if (preferredQuality == '720p') {
          selectedStream = muxedStreams.firstWhere(
            (s) => s.videoQuality.name.contains('720') || s.videoResolution.height == 720,
            orElse: () => muxedStreams.first,
          );
        } else if (preferredQuality == '480p') {
          selectedStream = muxedStreams.firstWhere(
            (s) => s.videoQuality.name.contains('480') || s.videoResolution.height == 480,
            orElse: () => muxedStreams.first,
          );
        } else {
          selectedStream = muxedStreams.firstWhere(
            (s) => s.videoQuality.name.contains('360') || s.videoResolution.height == 360,
            orElse: () => muxedStreams.first,
          );
        }

        final directUrl = selectedStream.url.toString();
        final streamInfo = StreamInfo(
          url: directUrl,
          codec: selectedStream.videoCodec,
          bitrate: selectedStream.bitrate.kiloBitsPerSecond.toInt(),
          container: selectedStream.container.name,
          quality: AudioQuality.high,
          contentLength: selectedStream.size.totalBytes,
          expiresAt: DateTime.now().add(const Duration(hours: 4)),
          isAudioOnly: false,
          streamProvenance: 'youtube_video',
          headers: const {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        );

        _cache[videoId] = streamInfo;
        return streamInfo;
      }

      // If no muxed streams, try video-only streams
      final videoOnlyStreams = manifest.videoOnly.toList();
      if (videoOnlyStreams.isNotEmpty) {
        final videoStream = videoOnlyStreams.first;
        final directUrl = videoStream.url.toString();
        final streamInfo = StreamInfo(
          url: directUrl,
          codec: videoStream.videoCodec,
          bitrate: videoStream.bitrate.kiloBitsPerSecond.toInt(),
          container: videoStream.container.name,
          quality: AudioQuality.medium,
          contentLength: videoStream.size.totalBytes,
          expiresAt: DateTime.now().add(const Duration(hours: 4)),
          isAudioOnly: false,
          streamProvenance: 'youtube_video_only',
        );

        _cache[videoId] = streamInfo;
        return streamInfo;
      }
    } catch (e) {
      debugPrint('MusicVideoService: Failed to resolve video stream for $videoId: $e');
    }

    return null;
  }

  Future<yt.StreamManifest> _fetchManifest(String videoId) async {
    final candidateClients = [
      yt.YoutubeApiClient.androidSdkless,
      yt.YoutubeApiClient.android,
      yt.YoutubeApiClient.ios,
      yt.YoutubeApiClient.mweb,
    ];

    Object? lastError;
    for (final client in candidateClients) {
      try {
        final manifest = await _youtube.videos.streamsClient.getManifest(
          videoId,
          ytClients: [client],
          requireWatchPage: false,
        ).timeout(const Duration(seconds: 6));
        return manifest;
      } catch (e) {
        lastError = e;
      }
    }

    throw lastError ?? Exception('Failed to get video stream manifest for $videoId');
  }

  /// Clear in-memory cached stream URLs
  void clearCache() {
    _cache.clear();
  }

  void dispose() {
    _cache.clear();
  }
}
