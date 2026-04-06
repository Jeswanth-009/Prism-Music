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

  Album copyWith({
    String? id,
    String? title,
    String? artist,
    List<Artist>? artists,
    Thumbnails? thumbnails,
    int? year,
    int? trackCount,
    AlbumType? type,
    List<Song>? songs,
    String? youtubePlaylistId,
    String? spotifyId,
    String? description,
  }) {
    return Album(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artists: artists ?? this.artists,
      thumbnails: thumbnails ?? this.thumbnails,
      year: year ?? this.year,
      trackCount: trackCount ?? this.trackCount,
      type: type ?? this.type,
      songs: songs ?? this.songs,
      youtubePlaylistId: youtubePlaylistId ?? this.youtubePlaylistId,
      spotifyId: spotifyId ?? this.spotifyId,
      description: description ?? this.description,
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
        youtubePlaylistId,
        spotifyId,
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
