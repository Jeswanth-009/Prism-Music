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

  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    Thumbnails? thumbnails,
    String? author,
    int? trackCount,
    Duration? totalDuration,
    bool? isUserCreated,
    bool? isPublic,
    List<Song>? songs,
    String? youtubePlaylistId,
    String? spotifyPlaylistId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      thumbnails: thumbnails ?? this.thumbnails,
      author: author ?? this.author,
      trackCount: trackCount ?? this.trackCount,
      totalDuration: totalDuration ?? this.totalDuration,
      isUserCreated: isUserCreated ?? this.isUserCreated,
      isPublic: isPublic ?? this.isPublic,
      songs: songs ?? this.songs,
      youtubePlaylistId: youtubePlaylistId ?? this.youtubePlaylistId,
      spotifyPlaylistId: spotifyPlaylistId ?? this.spotifyPlaylistId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        author,
        trackCount,
        isUserCreated,
        isPublic,
        youtubePlaylistId,
        spotifyPlaylistId,
      ];
}
