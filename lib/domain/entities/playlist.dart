import 'package:equatable/equatable.dart';
import 'song.dart';

/// Represents a playlist (user-created or fetched)
class Playlist extends Equatable {
  /// Unique identifier
  final String id;
  
  /// Playlist name
  final String name;
  
  /// Description
  final String? description;
  
  /// Playlist cover art
  final Thumbnails? thumbnails;
  
  /// Creator name
  final String? author;
  
  /// Number of tracks
  final int trackCount;
  
  /// Total duration
  final Duration? totalDuration;
  
  /// Whether this is a user-created playlist
  final bool isUserCreated;
  
  /// Whether this playlist is public
  final bool isPublic;
  
  /// Songs in the playlist (if loaded)
  final List<Song>? songs;
  
  /// YouTube playlist ID (if imported)
  final String? youtubePlaylistId;
  
  /// Spotify playlist ID (if imported)
  final String? spotifyPlaylistId;
  
  /// Creation timestamp
  final DateTime? createdAt;
  
  /// Last modified timestamp
  final DateTime? updatedAt;

  const Playlist({
    required this.id,
    required this.name,
    this.description,
    this.thumbnails,
    this.author,
    this.trackCount = 0,
    this.totalDuration,
    this.isUserCreated = false,
    this.isPublic = false,
    this.songs,
    this.youtubePlaylistId,
    this.spotifyPlaylistId,
    this.createdAt,
    this.updatedAt,
  });

  /// Get the best available thumbnail (or first song's thumbnail)
  String? get thumbnailUrl {
    if (thumbnails?.best != null) return thumbnails!.best;
    if (songs != null && songs!.isNotEmpty) {
      return songs!.first.thumbnailUrl;
    }
    return null;
  }
  
  /// Get formatted duration string
  String get totalDurationFormatted {
    if (totalDuration == null) return '';
    final hours = totalDuration!.inHours;
    final minutes = totalDuration!.inMinutes % 60;
    if (hours > 0) {
      return '$hours hr $minutes min';
    }
    return '$minutes min';
  }

  static const Object _sentinel = Object();

  Playlist copyWith({
    String? id,
    String? name,
    Object? description = _sentinel,
    Object? thumbnails = _sentinel,
    Object? author = _sentinel,
    int? trackCount,
    Object? totalDuration = _sentinel,
    bool? isUserCreated,
    bool? isPublic,
    Object? songs = _sentinel,
    Object? youtubePlaylistId = _sentinel,
    Object? spotifyPlaylistId = _sentinel,
    Object? createdAt = _sentinel,
    Object? updatedAt = _sentinel,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: identical(description, _sentinel)
          ? this.description
          : description as String?,
      thumbnails: identical(thumbnails, _sentinel)
          ? this.thumbnails
          : thumbnails as Thumbnails?,
      author: identical(author, _sentinel) ? this.author : author as String?,
      trackCount: trackCount ?? this.trackCount,
      totalDuration: identical(totalDuration, _sentinel)
          ? this.totalDuration
          : totalDuration as Duration?,
      isUserCreated: isUserCreated ?? this.isUserCreated,
      isPublic: isPublic ?? this.isPublic,
      songs: identical(songs, _sentinel) ? this.songs : songs as List<Song>?,
      youtubePlaylistId: identical(youtubePlaylistId, _sentinel)
          ? this.youtubePlaylistId
          : youtubePlaylistId as String?,
      spotifyPlaylistId: identical(spotifyPlaylistId, _sentinel)
          ? this.spotifyPlaylistId
          : spotifyPlaylistId as String?,
      createdAt: identical(createdAt, _sentinel)
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: identical(updatedAt, _sentinel)
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        thumbnails,
        author,
        trackCount,
        totalDuration,
        isUserCreated,
        isPublic,
        songs,
        youtubePlaylistId,
        spotifyPlaylistId,
        createdAt,
        updatedAt,
      ];
}
