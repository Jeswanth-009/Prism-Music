import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/podcast_service.dart';
import 'package:prism_music/domain/entities/podcast.dart';

void main() {
  group('PodcastService', () {
    late PodcastService service;

    setUp(() {
      service = PodcastService();
    });

    test('Podcast model serialization toMap and fromMap', () {
      const podcast = Podcast(
        id: '12345',
        title: 'Tech Daily',
        author: 'Jane Doe',
        feedUrl: 'https://example.com/feed.xml',
        artworkUrl: 'https://example.com/art.jpg',
        description: 'Daily tech analysis',
        genres: ['Technology', 'News'],
        episodeCount: 42,
      );

      final map = podcast.toMap();
      final restored = Podcast.fromMap(map);

      expect(restored.id, equals(podcast.id));
      expect(restored.title, equals(podcast.title));
      expect(restored.author, equals(podcast.author));
      expect(restored.feedUrl, equals(podcast.feedUrl));
      expect(restored.artworkUrl, equals(podcast.artworkUrl));
      expect(restored.genres, equals(podcast.genres));
      expect(restored.episodeCount, equals(42));
    });

    test('parseRssFeed extracts episodes, enclosures, and metadata properly', () {
      const sampleRss = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>Test Show</title>
    <item>
      <title>Episode 1: The Beginning</title>
      <description>Introduction to the series.</description>
      <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg" length="12345678"/>
      <guid>ep_guid_001</guid>
      <pubDate>Fri, 01 Nov 2026 12:00:00 GMT</pubDate>
      <itunes:duration>45:30</itunes:duration>
      <itunes:image href="https://example.com/ep1.jpg"/>
    </item>
    <item>
      <title>Episode 2: Deep Dive</title>
      <description>Advanced discussion.</description>
      <enclosure url="https://example.com/ep2.mp3" type="audio/mpeg" length="23456789"/>
      <guid>ep_guid_002</guid>
      <itunes:duration>01:15:20</itunes:duration>
    </item>
  </channel>
</rss>''';

      const podcast = Podcast(
        id: 'pod_1',
        title: 'Test Show',
        author: 'Host',
        feedUrl: 'https://example.com/feed.xml',
        artworkUrl: 'https://example.com/show.jpg',
      );

      final episodes = service.parseRssFeed(sampleRss, podcast);

      expect(episodes.length, equals(2));

      final ep1 = episodes[0];
      expect(ep1.id, equals('ep_guid_001'));
      expect(ep1.title, equals('Episode 1: The Beginning'));
      expect(ep1.audioUrl, equals('https://example.com/ep1.mp3'));
      expect(ep1.duration, equals(const Duration(minutes: 45, seconds: 30)));
      expect(ep1.artworkUrl, equals('https://example.com/ep1.jpg'));

      final ep2 = episodes[1];
      expect(ep2.id, equals('ep_guid_002'));
      expect(ep2.duration, equals(const Duration(hours: 1, minutes: 15, seconds: 20)));
      expect(ep2.artworkUrl, equals('https://example.com/show.jpg')); // fallback to podcast
    });

    test('episodeToSong converts episode into playable Song entity', () {
      const episode = PodcastEpisode(
        id: 'ep_123',
        podcastId: 'pod_1',
        podcastTitle: 'Waveform Podcast',
        title: 'Smartphone of the Year',
        description: 'Annual awards show',
        audioUrl: 'https://cdn.example.com/audio.mp3',
        duration: Duration(minutes: 62),
        artworkUrl: 'https://cdn.example.com/art.jpg',
      );

      final song = service.episodeToSong(episode);

      expect(song.id, equals('ep_123'));
      expect(song.title, equals('Smartphone of the Year'));
      expect(song.artist, equals('Waveform Podcast'));
      expect(song.streamUrl, equals('https://cdn.example.com/audio.mp3'));
      expect(song.duration, equals(const Duration(minutes: 62)));
      expect(song.streamProvenance, equals('podcast_feed'));
    });
  });
}
