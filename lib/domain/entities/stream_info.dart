import 'package:equatable/equatable.dart';
import 'song.dart';

/// Represents a stream URL with metadata
class StreamInfo extends Equatable {
  /// Stream URL
  final String url;
  
  /// Audio codec (opus, aac, vorbis, etc.)
  final String codec;
  
  /// Bitrate in kbps
  final int bitrate;
  
  /// Container format (webm, mp4, etc.)
  final String container;
  
  /// Audio quality level
  final AudioQuality quality;
  
  /// Content length in bytes
  final int? contentLength;
  
  /// Expiration timestamp (YouTube streams expire)
  final DateTime? expiresAt;
  
  /// Whether this is audio-only
  final bool isAudioOnly;
  
  /// HTTP headers required for accessing the stream
  final Map<String, String>? headers;

  const StreamInfo({
    required this.url,
    required this.codec,
    required this.bitrate,
    required this.container,
    required this.quality,
    this.contentLength,
    this.expiresAt,
    this.isAudioOnly = true,
    this.headers,
  });

  /// Check if the stream URL is still valid
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  @override
  List<Object?> get props => [
        url,
        codec,
        bitrate,
        container,
        quality,
        contentLength,
        expiresAt,
        isAudioOnly,
        headers,
      ];
}

/// Represents lyrics for a song
class Lyrics extends Equatable {
  /// Song ID this lyrics belong to
  final String songId;
  
  /// Plain text lyrics
  final String? plainLyrics;
  
  /// Synced lyrics with timestamps
  final List<LyricLine>? syncedLyrics;
  
  /// Source of lyrics (Musixmatch, LRCLIB, etc.)
  final String source;
  
  /// Whether lyrics are synced
  bool get isSynced => syncedLyrics != null && syncedLyrics!.isNotEmpty;

  const Lyrics({
    required this.songId,
    this.plainLyrics,
    this.syncedLyrics,
    required this.source,
  });

  @override
  List<Object?> get props => [songId, plainLyrics, syncedLyrics, source];
}

/// Represents a single line of synced lyrics
class LyricLine extends Equatable {
  /// Start time in milliseconds
  final int startTimeMs;
  
  /// End time in milliseconds (optional)
  final int? endTimeMs;
  
  /// Lyric text
  final String text;

  const LyricLine({
    required this.startTimeMs,
    this.endTimeMs,
    required this.text,
  });

  /// Get start time as Duration
  Duration get startTime => Duration(milliseconds: startTimeMs);
  
  /// Get end time as Duration
  Duration? get endTime =>
      endTimeMs != null ? Duration(milliseconds: endTimeMs!) : null;

  @override
  List<Object?> get props => [startTimeMs, endTimeMs, text];
}

/// Represents chart/trending data
class Chart extends Equatable {
  /// Chart identifier
  final String id;
  
  /// Chart name
  final String name;
  
  /// Chart type
  final ChartType type;
  
  /// Source (Spotify, YouTube Music)
  final MusicSource source;
  
  /// Region/country code
  final String? region;
  
  /// Songs in the chart
  final List<Song> songs;
  
  /// Last updated timestamp
  final DateTime? updatedAt;

  const Chart({
    required this.id,
    required this.name,
    required this.type,
    required this.source,
    this.region,
    this.songs = const [],
    this.updatedAt,
  });

  @override
  List<Object?> get props => [id, name, type, source, region, songs];
}

/// Chart types
enum ChartType {
  topSongs,
  trending,
  newReleases,
  viral,
}
