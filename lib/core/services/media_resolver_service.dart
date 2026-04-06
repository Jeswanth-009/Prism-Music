import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../domain/entities/entities.dart';
import 'download_service.dart';
import 'stream_loader_service.dart';

/// Result of resolving a [Song] into a playable media source.
class ResolvedMediaSource {
  final String uri;
  final Map<String, String>? headers;
  final bool isOffline;
  final String? videoId;

  const ResolvedMediaSource({
    required this.uri,
    this.headers,
    required this.isOffline,
    this.videoId,
  });
}

/// Central resolver that keeps PlayerBloc backend-agnostic.
class MediaResolverService {
  final StreamLoaderService _streamLoader;
  final DownloadService _downloadService;
  final Map<String, ResolvedMediaSource> _preResolved = {};
  final Set<String> _inflightPreResolve = {};

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  MediaResolverService({
    required StreamLoaderService streamLoader,
    required DownloadService downloadService,
  }) : _streamLoader = streamLoader,
       _downloadService = downloadService;

  Future<ResolvedMediaSource> resolveForPlayback(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    final songId = song.playableId;

    // Prefer local file when available for offline-safe playback.
    if (_downloadService.isDownloaded(songId)) {
      final localPath = _downloadService.getLocalPath(songId);
      if (localPath != null && File(localPath).existsSync()) {
        _log('MediaResolver: Offline HIT for ${song.title}');
        return ResolvedMediaSource(uri: localPath, isOffline: true);
      }
    }

    // Source-aware branch: if provider already supplied a direct stream URL,
    // use it directly and avoid unnecessary resolver round trips.
    if (_hasDirectStream(song)) {
      _log('MediaResolver: Direct stream HIT for ${song.title}');
      return ResolvedMediaSource(
        uri: song.streamUrl!,
        isOffline: false,
        videoId: song.playableId,
      );
    }

    final streamResolveStopwatch = Stopwatch()..start();
    final streamInfo = await _streamLoader.loadStream(
      song,
      preferredQuality: preferredQuality,
    );
    streamResolveStopwatch.stop();
    _log(
      'MediaResolver: StreamLoader resolved ${song.title} '
      'in ${streamResolveStopwatch.elapsedMilliseconds}ms',
    );

    return ResolvedMediaSource(
      uri: streamInfo.url,
      headers: streamInfo.headers,
      isOffline: false,
      videoId: songId,
    );
  }

  void preResolveSong(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) {
    final songId = song.playableId;
    if (_preResolved.containsKey(songId) ||
        _inflightPreResolve.contains(songId)) {
      return;
    }

    _inflightPreResolve.add(songId);
    resolveForPlayback(song, preferredQuality: preferredQuality)
        .then((resolved) {
          _preResolved[songId] = resolved;
        })
        .catchError((_) {
          // Keep preloading failures non-fatal.
        })
        .whenComplete(() {
          _inflightPreResolve.remove(songId);
        });
  }

  ResolvedMediaSource? takePreResolved(String songId) {
    return _preResolved.remove(songId);
  }

  bool _hasDirectStream(Song song) {
    final url = song.streamUrl?.trim();
    if (url == null || url.isEmpty) return false;
    if (!url.startsWith('http://') && !url.startsWith('https://')) return false;

    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final query = uri.query.toLowerCase();

    // Never treat web/watch pages as direct media URLs.
    if (path.contains('/watch') ||
        path.contains('/playlist') ||
        path.contains('/results')) {
      return false;
    }

    final isYouTubeSource =
        song.source == MusicSource.youtube ||
        song.source == MusicSource.youtubeMusic;
    final isYouTubeHost =
        host.contains('youtube.com') || host.contains('youtu.be');
    final isGoogleVideoHost = host.contains('googlevideo.com');

    // For YouTube-family sources, only accept links that look like audio streams.
    if (isYouTubeSource || isYouTubeHost || isGoogleVideoHost) {
      final itag = uri.queryParameters['itag'];
      const audioItags = {
        '139',
        '140',
        '141',
        '171',
        '172',
        '249',
        '250',
        '251',
      };

      final hasAudioMime =
          query.contains('mime=audio') || query.contains('audio%2f');
      final isKnownAudioItag = itag != null && audioItags.contains(itag);
      return hasAudioMime || isKnownAudioItag;
    }

    return true;
  }
}
