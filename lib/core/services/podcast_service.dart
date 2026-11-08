import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:xml/xml.dart' as xml;

import '../../domain/entities/podcast.dart';
import '../../domain/entities/song.dart';

/// Service managing podcast discovery, episode parsing, and subscriptions.
class PodcastService {
  static final PodcastService instance = PodcastService._();
  PodcastService._({Dio? dio}) : _dio = dio ?? Dio();
  factory PodcastService({Dio? dio}) => instance;

  final Dio _dio;
  static const String _subscriptionsBoxName = 'podcast_subscriptions_box';
  static const String _progressBoxName = 'podcast_progress_box';

  Box? _subsBox;
  Box? _progressBox;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _subsBox = await Hive.openBox(_subscriptionsBoxName);
      _progressBox = await Hive.openBox(_progressBoxName);
      _initialized = true;
    } catch (e) {
      debugPrint('PodcastService: Initialization warning: $e');
      _initialized = true;
    }
  }

  /// Search podcasts globally via iTunes Search API (no API key required)
  Future<List<Podcast>> searchPodcasts(String query, {int limit = 20}) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    try {
      final url = 'https://itunes.apple.com/search?media=podcast&term=${Uri.encodeComponent(clean)}&limit=$limit';
      final response = await _dio.get<dynamic>(url);

      if (response.statusCode == 200) {
        final data = response.data is String ? jsonDecode(response.data as String) : response.data;
        if (data is Map && data.containsKey('results')) {
          final results = data['results'] as List<dynamic>;
          return results.map((item) {
            final m = item as Map<dynamic, dynamic>;
            final genresList = (m['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
            return Podcast(
              id: m['collectionId']?.toString() ?? '',
              title: m['collectionName']?.toString() ?? 'Podcast',
              author: m['artistName']?.toString() ?? 'Unknown Author',
              feedUrl: m['feedUrl']?.toString() ?? '',
              artworkUrl: m['artworkUrl600']?.toString() ?? m['artworkUrl100']?.toString() ?? '',
              genres: genresList,
              episodeCount: (m['trackCount'] as num?)?.toInt() ?? 0,
            );
          }).where((p) => p.feedUrl.isNotEmpty).toList();
        }
      }
    } catch (e) {
      debugPrint('PodcastService: searchPodcasts error for "$query": $e');
    }

    return [];
  }

  /// Fetch popular podcasts by category
  Future<List<Podcast>> getFeaturedPodcasts({String query = 'technology'}) async {
    return searchPodcasts(query, limit: 12);
  }

  /// Fetch and parse episodes from a podcast's RSS feed
  Future<List<PodcastEpisode>> fetchEpisodes(Podcast podcast) async {
    if (podcast.feedUrl.isEmpty) return [];

    try {
      final response = await _dio.get<String>(
        podcast.feedUrl,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 && response.data != null) {
        return parseRssFeed(response.data!, podcast);
      }
    } catch (e) {
      debugPrint('PodcastService: fetchEpisodes error for ${podcast.title}: $e');
    }

    return [];
  }

  /// Parse RSS feed XML into episode entities
  List<PodcastEpisode> parseRssFeed(String xmlContent, Podcast podcast) {
    final episodes = <PodcastEpisode>[];

    try {
      final document = xml.XmlDocument.parse(xmlContent);
      final items = document.findAllElements('item');

      for (final item in items) {
        final title = item.findElements('title').firstOrNull?.innerText.trim() ?? '';
        final desc = item.findElements('description').firstOrNull?.innerText.trim() ??
            item.findElements('itunes:summary').firstOrNull?.innerText.trim() ?? '';
        final enclosure = item.findElements('enclosure').firstOrNull;
        final audioUrl = enclosure?.getAttribute('url')?.trim() ?? '';

        if (audioUrl.isEmpty) continue;

        // Parse pubDate
        DateTime? pubDate;
        final pubDateStr = item.findElements('pubDate').firstOrNull?.innerText.trim();
        if (pubDateStr != null) {
          try {
            pubDate = DateTime.tryParse(pubDateStr);
          } catch (_) {}
        }

        // Parse duration
        Duration duration = Duration.zero;
        final durationStr = item.findElements('itunes:duration').firstOrNull?.innerText.trim();
        if (durationStr != null) {
          duration = _parseDuration(durationStr);
        }

        // Artwork
        final itunesImage = item.findElements('itunes:image').firstOrNull?.getAttribute('href');
        final artworkUrl = itunesImage ?? podcast.artworkUrl;

        final episodeId = item.findElements('guid').firstOrNull?.innerText.trim() ??
            '${podcast.id}_${title.hashCode}';

        final progress = getEpisodeProgress(episodeId);

        episodes.add(
          PodcastEpisode(
            id: episodeId,
            podcastId: podcast.id,
            podcastTitle: podcast.title,
            title: title.isEmpty ? 'Episode' : title,
            description: desc,
            audioUrl: audioUrl,
            publishedAt: pubDate,
            duration: duration,
            artworkUrl: artworkUrl,
            playbackPosition: progress,
            isCompleted: duration > Duration.zero && progress >= duration - const Duration(seconds: 15),
          ),
        );
      }
    } catch (e) {
      debugPrint('PodcastService: XML parsing error: $e');
    }

    return episodes;
  }

  Duration _parseDuration(String raw) {
    if (raw.contains(':')) {
      final parts = raw.split(':').map((e) => int.tryParse(e) ?? 0).toList();
      if (parts.length == 3) {
        return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
      } else if (parts.length == 2) {
        return Duration(minutes: parts[0], seconds: parts[1]);
      }
    } else {
      final seconds = int.tryParse(raw) ?? 0;
      return Duration(seconds: seconds);
    }
    return Duration.zero;
  }

  /// Check if a podcast is subscribed
  bool isSubscribed(String podcastId) {
    return _subsBox?.containsKey(podcastId) ?? false;
  }

  /// Subscribe to a podcast
  Future<void> subscribe(Podcast podcast) async {
    await initialize();
    await _subsBox?.put(podcast.id, podcast.toMap());
  }

  /// Unsubscribe from a podcast
  Future<void> unsubscribe(String podcastId) async {
    await initialize();
    await _subsBox?.delete(podcastId);
  }

  /// Get all subscribed podcasts
  List<Podcast> getSubscribedPodcasts() {
    if (_subsBox == null || !_subsBox!.isOpen) return [];

    final list = <Podcast>[];
    for (final val in _subsBox!.values) {
      if (val is Map) {
        list.add(Podcast.fromMap(val));
      }
    }
    return list;
  }

  /// Save playback progress for an episode
  Future<void> saveEpisodeProgress(String episodeId, Duration position) async {
    await initialize();
    await _progressBox?.put(episodeId, position.inMilliseconds);
  }

  /// Retrieve playback progress for an episode
  Duration getEpisodeProgress(String episodeId) {
    final ms = _progressBox?.get(episodeId) as int?;
    return ms != null ? Duration(milliseconds: ms) : Duration.zero;
  }

  /// Adapt a PodcastEpisode to Prism's standard playable Song entity
  Song episodeToSong(PodcastEpisode episode) {
    return Song(
      id: episode.id,
      title: episode.title,
      artist: episode.podcastTitle,
      duration: episode.duration,
      thumbnails: Thumbnails.fromUrl(episode.artworkUrl ?? ''),
      source: MusicSource.unknown,
      streamUrl: episode.audioUrl,
      streamProvenance: 'podcast_feed',
    );
  }
}
