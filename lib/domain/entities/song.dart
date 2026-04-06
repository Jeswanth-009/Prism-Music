import 'package:equatable/equatable.dart';

/// Represents the source of a music track
enum MusicSource {
  youtube,
  youtubeMusic,
  spotify,
  jiosaavn,
  local,
  unknown,
}

/// Audio quality levels
enum AudioQuality {
  low(64),      // 64 kbps
  medium(128),  // 128 kbps
  high(256),    // 256 kbps
  lossless(320); // 320 kbps (Opus)

  final int bitrate;
  const AudioQuality(this.bitrate);
}

/// Represents a music track/song
class Song extends Equatable {
  /// Unique identifier for the song (YouTube video ID or internal ID)
  final String id;
  
  /// Song title
  final String title;
  
  /// Primary artist name
  final String artist;
  
  /// List of all artists (for collaborations)
  final List<String> artists;
  
  /// Album name
  final String? album;
  
  /// Album ID for fetching more tracks
  final String? albumId;
  
  /// Duration in milliseconds
  final Duration duration;
  
  /// Thumbnail/cover art URLs (different resolutions)
  final Thumbnails thumbnails;
  
  /// Source of the track
  final MusicSource source;
  
  /// YouTube video ID (if applicable)
  final String? youtubeId;
  
  /// Spotify track ID (if applicable, for metadata)
  final String? spotifyId;

  /// JioSaavn track ID (if applicable)
  final String? jioSaavnId;

  /// Whether this song is explicitly marked
  final bool isExplicit;
  
  /// Release year
  final int? year;
  
  /// Genre
  final String? genre;
  
  /// Play count (if available)
  final int? playCount;
  
  /// Whether this song is liked by the user
  final bool isLiked;
  
  /// Cached stream URL (expires)
  final String? streamUrl;
  
  /// Audio quality of cached stream
  final AudioQuality? cachedQuality;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    this.artists = const [],
    this.album,
    this.albumId,
    required this.duration,
    required this.thumbnails,
    this.source = MusicSource.unknown,
    this.youtubeId,
    this.spotifyId,
    this.jioSaavnId,
    this.isExplicit = false,
    this.year,
    this.genre,
    this.playCount,
    this.isLiked = false,
    this.streamUrl,
    this.cachedQuality,
  });

  /// Get the primary playable ID (prefers YouTube for streaming)
  String get playableId => youtubeId ?? jioSaavnId ?? id;
  
  /// Get the best available thumbnail
  String get thumbnailUrl => thumbnails.high ?? thumbnails.medium ?? thumbnails.low ?? '';
  
  /// Get formatted duration string (MM:SS)
  String get durationFormatted {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Create a copy with modified fields
  Song copyWith({
    String? id,
    String? title,
    String? artist,
    List<String>? artists,
    String? album,
    String? albumId,
    Duration? duration,
    Thumbnails? thumbnails,
    MusicSource? source,
    String? youtubeId,
    String? spotifyId,
    String? jioSaavnId,
    bool? isExplicit,
    int? year,
    String? genre,
    int? playCount,
    bool? isLiked,
    String? streamUrl,
    AudioQuality? cachedQuality,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artists: artists ?? this.artists,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      duration: duration ?? this.duration,
      thumbnails: thumbnails ?? this.thumbnails,
      source: source ?? this.source,
      youtubeId: youtubeId ?? this.youtubeId,
      spotifyId: spotifyId ?? this.spotifyId,
      jioSaavnId: jioSaavnId ?? this.jioSaavnId,
      isExplicit: isExplicit ?? this.isExplicit,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      playCount: playCount ?? this.playCount,
      isLiked: isLiked ?? this.isLiked,
      streamUrl: streamUrl ?? this.streamUrl,
      cachedQuality: cachedQuality ?? this.cachedQuality,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        artist,
        artists,
        album,
        albumId,
        duration,
        thumbnails,
        source,
        youtubeId,
        spotifyId,
        jioSaavnId,
        isExplicit,
        year,
        genre,
        playCount,
        isLiked,
      ];
}

/// Thumbnail URLs at different resolutions
class Thumbnails extends Equatable {
  final String? low;      // ~120px
  final String? medium;   // ~320px
  final String? high;     // ~480px
  final String? max;      // Max resolution

  const Thumbnails({
    this.low,
    this.medium,
    this.high,
    this.max,
  });

  /// Get the best available thumbnail
  String? get best => max ?? high ?? medium ?? low;
  
  /// Get the smallest available thumbnail
  String? get smallest => low ?? medium ?? high ?? max;

  factory Thumbnails.fromUrl(String url) {
    return Thumbnails(
      low: url,
      medium: url,
      high: url,
      max: url,
    );
  }

  /// Empty thumbnails placeholder
  factory Thumbnails.empty() {
    return const Thumbnails();
  }

  @override
  List<Object?> get props => [low, medium, high, max];
}
