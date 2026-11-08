import 'package:equatable/equatable.dart';

/// Represents a podcast series.
class Podcast extends Equatable {
  final String id;
  final String title;
  final String author;
  final String feedUrl;
  final String artworkUrl;
  final String description;
  final List<String> genres;
  final int episodeCount;

  const Podcast({
    required this.id,
    required this.title,
    required this.author,
    required this.feedUrl,
    required this.artworkUrl,
    this.description = '',
    this.genres = const [],
    this.episodeCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'feedUrl': feedUrl,
      'artworkUrl': artworkUrl,
      'description': description,
      'genres': genres,
      'episodeCount': episodeCount,
    };
  }

  factory Podcast.fromMap(Map<dynamic, dynamic> map) {
    return Podcast(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Podcast',
      author: map['author']?.toString() ?? 'Unknown Author',
      feedUrl: map['feedUrl']?.toString() ?? '',
      artworkUrl: map['artworkUrl']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      genres: (map['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      episodeCount: (map['episodeCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        author,
        feedUrl,
        artworkUrl,
        description,
        genres,
        episodeCount,
      ];
}

/// Represents an individual podcast episode.
class PodcastEpisode extends Equatable {
  final String id;
  final String podcastId;
  final String podcastTitle;
  final String title;
  final String description;
  final String audioUrl;
  final DateTime? publishedAt;
  final Duration duration;
  final String? artworkUrl;
  final Duration playbackPosition;
  final bool isCompleted;

  const PodcastEpisode({
    required this.id,
    required this.podcastId,
    required this.podcastTitle,
    required this.title,
    required this.description,
    required this.audioUrl,
    this.publishedAt,
    this.duration = Duration.zero,
    this.artworkUrl,
    this.playbackPosition = Duration.zero,
    this.isCompleted = false,
  });

  PodcastEpisode copyWith({
    String? id,
    String? podcastId,
    String? podcastTitle,
    String? title,
    String? description,
    String? audioUrl,
    DateTime? publishedAt,
    Duration? duration,
    String? artworkUrl,
    Duration? playbackPosition,
    bool? isCompleted,
  }) {
    return PodcastEpisode(
      id: id ?? this.id,
      podcastId: podcastId ?? this.podcastId,
      podcastTitle: podcastTitle ?? this.podcastTitle,
      title: title ?? this.title,
      description: description ?? this.description,
      audioUrl: audioUrl ?? this.audioUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      duration: duration ?? this.duration,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'podcastId': podcastId,
      'podcastTitle': podcastTitle,
      'title': title,
      'description': description,
      'audioUrl': audioUrl,
      'publishedAt': publishedAt?.toIso8601String(),
      'durationMs': duration.inMilliseconds,
      'artworkUrl': artworkUrl,
      'playbackPositionMs': playbackPosition.inMilliseconds,
      'isCompleted': isCompleted,
    };
  }

  factory PodcastEpisode.fromMap(Map<dynamic, dynamic> map) {
    return PodcastEpisode(
      id: map['id']?.toString() ?? '',
      podcastId: map['podcastId']?.toString() ?? '',
      podcastTitle: map['podcastTitle']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      audioUrl: map['audioUrl']?.toString() ?? '',
      publishedAt: map['publishedAt'] != null
          ? DateTime.tryParse(map['publishedAt'] as String)
          : null,
      duration: Duration(milliseconds: (map['durationMs'] as num?)?.toInt() ?? 0),
      artworkUrl: map['artworkUrl']?.toString(),
      playbackPosition: Duration(
        milliseconds: (map['playbackPositionMs'] as num?)?.toInt() ?? 0,
      ),
      isCompleted: map['isCompleted'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        id,
        podcastId,
        podcastTitle,
        title,
        description,
        audioUrl,
        publishedAt,
        duration,
        artworkUrl,
        playbackPosition,
        isCompleted,
      ];
}
