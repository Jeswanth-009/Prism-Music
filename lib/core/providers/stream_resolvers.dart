import '../../domain/entities/song.dart';
import '../../domain/entities/stream_info.dart';
import '../../data/datasources/remote/jiosaavn/jiosaavn_datasource.dart';
import '../../data/datasources/remote/youtube/youtube_music_datasource.dart';
import '../../data/datasources/remote/youtube/piped_datasource.dart';
import '../../data/datasources/remote/youtube/invidious_datasource.dart';
import 'audio_stream_resolver.dart';

/// Audio stream resolver backed by JioSaavn catalog with match confidence evaluation.
class JioSaavnAudioStreamResolver implements AudioStreamResolver {
  final JioSaavnDataSource _dataSource;

  JioSaavnAudioStreamResolver({JioSaavnDataSource? dataSource})
      : _dataSource = dataSource ?? JioSaavnDataSourceImpl();

  @override
  String get resolverName => 'jiosaavn';

  @override
  bool get isAvailable => true;

  @override
  Future<StreamInfo?> resolveStream(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    return _dataSource.getStreamUrl(song);
  }
}

/// Audio stream resolver backed by direct YouTube Explode extraction.
class YouTubeExplodeAudioStreamResolver implements AudioStreamResolver {
  final YouTubeMusicDataSource _dataSource;

  YouTubeExplodeAudioStreamResolver({required YouTubeMusicDataSource dataSource})
      : _dataSource = dataSource;

  @override
  String get resolverName => 'youtube_explode';

  @override
  bool get isAvailable => true;

  @override
  Future<StreamInfo?> resolveStream(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    try {
      final raw = await _dataSource.getStreamUrl(
        song.playableId,
        preferredQuality: preferredQuality,
      );
      if (raw.streamProvenance == null) {
        return StreamInfo(
          url: raw.url,
          codec: raw.codec,
          bitrate: raw.bitrate,
          container: raw.container,
          quality: raw.quality,
          contentLength: raw.contentLength,
          expiresAt: raw.expiresAt,
          isAudioOnly: raw.isAudioOnly,
          headers: raw.headers,
          streamProvenance: 'youtube_explode',
          matchConfidence: 1.0,
        );
      }
      return raw;
    } catch (_) {
      return null;
    }
  }
}

/// Audio stream resolver backed by Piped proxy with instance health management.
class PipedAudioStreamResolver implements AudioStreamResolver {
  final PipedDataSource _dataSource;

  PipedAudioStreamResolver({PipedDataSource? dataSource})
      : _dataSource = dataSource ?? PipedDataSource();

  @override
  String get resolverName => 'piped';

  @override
  bool get isAvailable => true;

  @override
  Future<StreamInfo?> resolveStream(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    try {
      final raw = await _dataSource.getStreamUrl(song.playableId);
      if (raw != null && raw.streamProvenance == null) {
        return StreamInfo(
          url: raw.url,
          codec: raw.codec,
          bitrate: raw.bitrate,
          container: raw.container,
          quality: raw.quality,
          contentLength: raw.contentLength,
          expiresAt: raw.expiresAt,
          isAudioOnly: raw.isAudioOnly,
          headers: raw.headers,
          streamProvenance: 'piped_proxy',
          matchConfidence: 0.95,
        );
      }
      return raw;
    } catch (_) {
      return null;
    }
  }
}

/// Audio stream resolver backed by Invidious with instance health management.
class InvidiousAudioStreamResolver implements AudioStreamResolver {
  final InvidiousDataSource _dataSource;

  InvidiousAudioStreamResolver({InvidiousDataSource? dataSource})
      : _dataSource = dataSource ?? InvidiousDataSource();

  @override
  String get resolverName => 'invidious';

  @override
  bool get isAvailable => true;

  @override
  Future<StreamInfo?> resolveStream(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    try {
      final raw = await _dataSource.getStreamUrl(song.playableId);
      if (raw != null && raw.streamProvenance == null) {
        return StreamInfo(
          url: raw.url,
          codec: raw.codec,
          bitrate: raw.bitrate,
          container: raw.container,
          quality: raw.quality,
          contentLength: raw.contentLength,
          expiresAt: raw.expiresAt,
          isAudioOnly: raw.isAudioOnly,
          headers: raw.headers,
          streamProvenance: 'invidious_instance',
          matchConfidence: 0.95,
        );
      }
      return raw;
    } catch (_) {
      return null;
    }
  }
}
