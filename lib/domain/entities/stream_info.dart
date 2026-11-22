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

  /// Provenance of the stream (e.g. 'youtube_explode', 'jiosaavn_matched', 'piped_proxy', 'invidious')
  final String? streamProvenance;

  /// Match confidence (0.0 to 1.0) when resolved via cross-provider search
  final double? matchConfidence;

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
    this.streamProvenance,
    this.matchConfidence,
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
        streamProvenance,
        matchConfidence,
      ];
}

/// Represents the synchronization accuracy of a lyrics payload.
enum LyricsSyncType {
  plain,
  lineSynced,
  wordSynced, // Karaoke · lights up word by word
}

/// Represents a single word or syllable in a synced lyric line with exact millisecond timings.
class LyricWord extends Equatable {
  final int startTimeMs;
  final int endTimeMs;
  final String text;
  final bool isBackground;

  const LyricWord({
    required this.startTimeMs,
    required this.endTimeMs,
    required this.text,
    this.isBackground = false,
  });

  Duration get startTime => Duration(milliseconds: startTimeMs);
  Duration get endTime => Duration(milliseconds: endTimeMs);

  @override
  List<Object?> get props => [startTimeMs, endTimeMs, text, isBackground];
}

/// Represents lyrics for a song
class Lyrics extends Equatable {
  /// Song ID this lyrics belong to
  final String songId;
  
  /// Plain text lyrics
  final String? plainLyrics;
  
  /// Synced lyrics with timestamps
  final List<LyricLine>? syncedLyrics;
  
  /// Source of lyrics (Better Lyrics, QQ Music, LRCLIB, etc.)
  final String source;

  /// Synchronization tier (plain, lineSynced, wordSynced)
  final LyricsSyncType syncType;

  /// Identifier of the specific provider that served this payload
  final String? providerId;
  
  /// Whether lyrics are synced to lines
  bool get isSynced => syncedLyrics != null && syncedLyrics!.isNotEmpty;

  /// Whether lyrics have syllable/word-by-word karaoke timing
  bool get isKaraoke =>
      syncType == LyricsSyncType.wordSynced ||
      (syncedLyrics?.any((l) => l.isWordSynced) ?? false);

  /// Alias for word-synchronized karaoke capability
  bool get isWordSynced => isKaraoke;

  const Lyrics({
    required this.songId,
    this.plainLyrics,
    this.syncedLyrics,
    required this.source,
    this.syncType = LyricsSyncType.lineSynced,
    this.providerId,
  });

  @override
  List<Object?> get props => [
        songId,
        plainLyrics,
        syncedLyrics,
        source,
        syncType,
        providerId,
      ];
}

/// Represents a single line of synced lyrics
class LyricLine extends Equatable {
  /// Start time in milliseconds
  final int startTimeMs;
  
  /// End time in milliseconds (optional)
  final int? endTimeMs;
  
  /// Lyric text
  final String text;

  /// Word-level or syllable-level timing (for word-by-word karaoke)
  final List<LyricWord>? words;

  const LyricLine({
    required this.startTimeMs,
    this.endTimeMs,
    required this.text,
    this.words,
  });

  /// Get start time as Duration
  Duration get startTime => Duration(milliseconds: startTimeMs);
  
  /// Get end time as Duration
  Duration? get endTime =>
      endTimeMs != null ? Duration(milliseconds: endTimeMs!) : null;

  /// Whether this line contains word-level karaoke timing
  bool get isWordSynced => words != null && words!.isNotEmpty;

  @override
  List<Object?> get props => [startTimeMs, endTimeMs, text, words];
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
