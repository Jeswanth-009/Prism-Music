import 'package:equatable/equatable.dart';
import 'song.dart';

/// Represents a music artist
class Artist extends Equatable {
  /// Unique identifier
  final String id;
  
  /// Artist name
  final String name;
  
  /// Artist image/photo URLs
  final Thumbnails? thumbnails;
  
  /// Description/bio
  final String? description;
  
  /// Subscriber/follower count
  final int? subscriberCount;
  
  /// YouTube channel ID
  final String? youtubeChannelId;
  
  /// Spotify artist ID
  final String? spotifyId;
  
  /// Whether this is a verified artist
  final bool isVerified;

  const Artist({
    required this.id,
    required this.name,
    this.thumbnails,
    this.description,
    this.subscriberCount,
    this.youtubeChannelId,
    this.spotifyId,
    this.isVerified = false,
  });

  /// Get the best available thumbnail
  String? get thumbnailUrl => thumbnails?.best;

  Artist copyWith({
    String? id,
    String? name,
    Thumbnails? thumbnails,
    String? description,
    int? subscriberCount,
    String? youtubeChannelId,
    String? spotifyId,
    bool? isVerified,
  }) {
    return Artist(
      id: id ?? this.id,
      name: name ?? this.name,
      thumbnails: thumbnails ?? this.thumbnails,
      description: description ?? this.description,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      youtubeChannelId: youtubeChannelId ?? this.youtubeChannelId,
      spotifyId: spotifyId ?? this.spotifyId,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        thumbnails,
        description,
        subscriberCount,
        youtubeChannelId,
        spotifyId,
        isVerified,
      ];
}
