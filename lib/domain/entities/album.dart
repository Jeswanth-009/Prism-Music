import 'package:equatable/equatable.dart';
import 'song.dart';
import 'artist.dart';

/// Represents a music album
class Album extends Equatable {
  /// Unique identifier
  final String id;
  
  /// Album title
  final String title;
  
  /// Primary artist
  final String artist;
  
  /// All artists on the album
  final List<Artist> artists;
  
  /// Album artwork URLs
  final Thumbnails thumbnails;
  
  /// Release year
  final int? year;
  
  /// Number of tracks
  final int? trackCount;
  
  /// Album type (album, single, EP, compilation)
  final AlbumType type;
  
  /// List of songs (if loaded)
  final List<Song>? songs;
  
  /// YouTube playlist ID (if applicable)
  final String? youtubePlaylistId;
  
  /// Spotify album ID (if applicable)
  final String? spotifyId;
  
  /// Description
  final String? description;

  const Album({
    required this.id,
    required this.title,
    required this.artist,
    this.artists = const [],
    required this.thumbnails,
    this.year,
    this.trackCount,
    this.type = AlbumType.album,
    this.songs,
    this.youtubePlaylistId,
    this.spotifyId,
    this.description,
  });

  /// Get the best available thumbnail
  String get thumbnailUrl => thumbnails.best ?? '';

  static const Object _sentinel = Object();

  Album copyWith({
    String? id,
    String? title,
    String? artist,
    List<Artist>? artists,
    Thumbnails? thumbnails,
    Object? year = _sentinel,
    Object? trackCount = _sentinel,
    AlbumType? type,
    Object? songs = _sentinel,
    Object? youtubePlaylistId = _sentinel,
    Object? spotifyId = _sentinel,
    Object? description = _sentinel,
  }) {
    return Album(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artists: artists ?? this.artists,
      thumbnails: thumbnails ?? this.thumbnails,
      year: identical(year, _sentinel) ? this.year : year as int?,
      trackCount: identical(trackCount, _sentinel)
          ? this.trackCount
          : trackCount as int?,
      type: type ?? this.type,
      songs: identical(songs, _sentinel) ? this.songs : songs as List<Song>?,
      youtubePlaylistId: identical(youtubePlaylistId, _sentinel)
          ? this.youtubePlaylistId
          : youtubePlaylistId as String?,
      spotifyId: identical(spotifyId, _sentinel)
          ? this.spotifyId
          : spotifyId as String?,
      description: identical(description, _sentinel)
          ? this.description
          : description as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        artist,
        artists,
        thumbnails,
        year,
        trackCount,
        type,
        songs,
        youtubePlaylistId,
        spotifyId,
        description,
      ];
}

/// Album type classification
enum AlbumType {
  album,
  single,
  ep,
  compilation,
  unknown,
}
