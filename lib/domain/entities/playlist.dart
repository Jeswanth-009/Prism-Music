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
  
  /// Apple Music playlist ID (if imported)
  final String? appleMusicPlaylistId;
  
  /// Creation timestamp
  final DateTime? createdAt;
  
  /// Last modified timestamp
  final DateTime? updatedAt;

  /// Whether this playlist is pinned to Home feed
  final bool isPinned;

  /// Custom cover art URL or local image path
  final String? customCoverUrl;

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
    this.appleMusicPlaylistId,
    this.createdAt,
    this.updatedAt,
    this.isPinned = false,
    this.customCoverUrl,
  });

  /// Get the best available thumbnail (or custom cover, or first song's thumbnail)
  String? get thumbnailUrl {
    if (customCoverUrl != null && customCoverUrl!.isNotEmpty) {
      return customCoverUrl;
    }
    if (thumbnails?.best != null) return thumbnails!.best;
    if (songs != null && songs!.isNotEmpty) {
      return songs!.first.thumbnailUrl;
    }
    return null;
  }

  /// Extracts up to four distinct track thumbnails for 2x2 collage artwork.
  List<String> get collageThumbnails {
    if (songs == null || songs!.isEmpty) return const [];
    final urls = <String>[];
    for (final s in songs!) {
      if (s.thumbnailUrl.isNotEmpty && !urls.contains(s.thumbnailUrl)) {
        urls.add(s.thumbnailUrl);
        if (urls.length == 4) break;
      }
    }
    return urls;
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
    Object? appleMusicPlaylistId = _sentinel,
    Object? createdAt = _sentinel,
    Object? updatedAt = _sentinel,
    bool? isPinned,
    Object? customCoverUrl = _sentinel,
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
      appleMusicPlaylistId: identical(appleMusicPlaylistId, _sentinel)
          ? this.appleMusicPlaylistId
          : appleMusicPlaylistId as String?,
      createdAt: identical(createdAt, _sentinel)
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: identical(updatedAt, _sentinel)
          ? this.updatedAt
          : updatedAt as DateTime?,
      isPinned: isPinned ?? this.isPinned,
      customCoverUrl: identical(customCoverUrl, _sentinel)
          ? this.customCoverUrl
          : customCoverUrl as String?,
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
        appleMusicPlaylistId,
        createdAt,
        updatedAt,
        isPinned,
        customCoverUrl,
      ];
}
