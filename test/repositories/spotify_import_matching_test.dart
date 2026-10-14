import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/ytmusic_api_service.dart';
import 'package:prism_music/core/utils/cancellation_token.dart';
import 'package:prism_music/data/datasources/local/local_datasource.dart';
import 'package:prism_music/data/datasources/remote/jiosaavn/jiosaavn_datasource.dart';
import 'package:prism_music/data/datasources/remote/lyrics/lyrics_datasource.dart';
import 'package:prism_music/data/datasources/remote/spotify/spotify_datasource.dart';
import 'package:prism_music/data/datasources/remote/youtube/youtube_music_datasource.dart';
import 'package:prism_music/data/repositories/music_repository_impl.dart';
import 'package:prism_music/domain/entities/entities.dart';

class MockSpotifyDataSource implements SpotifyDataSource {
  SpotifyPlaylistDetails? detailsResult;
  String? lastUrl;
  ImportCancellationToken? lastCancelToken;

  @override
  Future<SpotifyPlaylistDetails?> getPlaylistDetails(
    String playlistUrl, {
    ImportCancellationToken? cancelToken,
    void Function(int loaded, int total)? onProgress,
  }) async {
    lastUrl = playlistUrl;
    lastCancelToken = cancelToken;
    return detailsResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockYtMusicApiService extends YtMusicApiService {
  final Map<String, List<Map<String, dynamic>>> queryResponses = {};
  final List<String> queriedTerms = [];

  @override
  Future<List<Map<String, dynamic>>> searchSongs(String query) async {
    queriedTerms.add(query);
    return queryResponses[query] ?? const [];
  }
}

class MockYouTubeMusicDataSource implements YouTubeMusicDataSource {
  final Map<String, List<Song>> searchResponses = {};
  final List<String> queriedQueries = [];

  @override
  Future<List<Song>> searchSongs(String query, {int limit = 20}) async {
    queriedQueries.add(query);
    return searchResponses[query] ?? const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLyricsDataSource implements LyricsDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLocalDataSource implements LocalDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockJioSaavnDataSource implements JioSaavnDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Spotify Import & Matching Engine (M16)', () {
    late MockSpotifyDataSource mockSpotify;
    late MockYtMusicApiService mockYtMusicApi;
    late MockYouTubeMusicDataSource mockYtExplode;
    late MusicRepositoryImpl repository;

    setUp(() {
      mockSpotify = MockSpotifyDataSource();
      mockYtMusicApi = MockYtMusicApiService();
      mockYtExplode = MockYouTubeMusicDataSource();

      repository = MusicRepositoryImpl(
        spotifyDataSource: mockSpotify,
        ytMusicApiService: mockYtMusicApi,
        youtubeMusicDataSource: mockYtExplode,
        lyricsDataSource: MockLyricsDataSource(),
        localDataSource: MockLocalDataSource(),
        jioSaavnDataSource: MockJioSaavnDataSource(),
      );
    });

    test('prioritizes ISRC lookup on YouTube Music when ISRC is present', () async {
      final targetSong = Song(
        id: 'spotify_track_1',
        title: 'Levitating',
        artist: 'Dua Lipa',
        duration: const Duration(seconds: 203),
        thumbnails: const Thumbnails(),
        source: MusicSource.spotify,
        isrc: 'GBUM72000843',
      );

      mockSpotify.detailsResult = SpotifyPlaylistDetails(
        id: 'pl_isrc',
        name: 'Hits',
        tracks: [targetSong],
        totalTracks: 1,
      );

      // Return ISRC candidate on YT Music
      mockYtMusicApi.queryResponses['GBUM72000843'] = [
        {
          'videoId': 'yt_levitating_isrc',
          'title': 'Levitating',
          'artists': [{'name': 'Dua Lipa'}],
          'duration': '3:23',
          'duration_seconds': 203,
        }
      ];

      final resultEither = await repository.importSpotifyPlaylist('https://open.spotify.com/playlist/pl_isrc');
      expect(resultEither.isRight(), isTrue);

      final result = resultEither.getOrElse(() => throw Exception());
      expect(result.matchedCount, 1);
      expect(result.unmatchedCount, 0);
      expect(result.matchPercent, 100);

      final matched = result.matchedTracks.first;
      expect(matched.youtubeId, 'yt_levitating_isrc');
      expect(matched.streamProvenance, 'youtube_isrc_matched');
      expect(matched.matchConfidence, greaterThanOrEqualTo(0.8));
      expect(mockYtMusicApi.queriedTerms, contains('GBUM72000843'));
    });

    test('falls back to clean metadata search when ISRC is absent', () async {
      final targetSong = Song(
        id: 'spotify_track_2',
        title: 'Starboy (feat. Daft Punk)',
        artist: 'The Weeknd',
        duration: const Duration(seconds: 230),
        thumbnails: const Thumbnails(),
        source: MusicSource.spotify,
      );

      mockSpotify.detailsResult = SpotifyPlaylistDetails(
        id: 'pl_meta',
        name: 'Pop',
        tracks: [targetSong],
        totalTracks: 1,
      );

      mockYtMusicApi.queryResponses['The Weeknd Starboy (feat. Daft Punk)'] = [
        {
          'videoId': 'yt_starboy_meta',
          'title': 'Starboy (Official Music Video) ft. Daft Punk',
          'artists': [{'name': 'The Weeknd'}],
          'duration': '3:50',
          'duration_seconds': 230,
        }
      ];

      final resultEither = await repository.importSpotifyPlaylist('https://open.spotify.com/playlist/pl_meta');
      expect(resultEither.isRight(), isTrue);

      final result = resultEither.getOrElse(() => throw Exception());
      expect(result.matchedCount, 1);
      expect(result.unmatchedCount, 0);

      final matched = result.matchedTracks.first;
      expect(matched.youtubeId, 'yt_starboy_meta');
      expect(matched.streamProvenance, 'youtube_matched');
    });

    test('falls back to YouTube Explode when YouTube Music yields no candidate', () async {
      final targetSong = Song(
        id: 'spotify_track_3',
        title: 'Underground Gem',
        artist: 'Indie Artist',
        duration: const Duration(seconds: 190),
        thumbnails: const Thumbnails(),
        source: MusicSource.spotify,
      );

      mockSpotify.detailsResult = SpotifyPlaylistDetails(
        id: 'pl_indie',
        name: 'Indie',
        tracks: [targetSong],
        totalTracks: 1,
      );

      // YtMusicApi returns empty list
      mockYtMusicApi.queryResponses['Indie Artist Underground Gem'] = [];

      // YouTubeExplode returns candidate
      mockYtExplode.searchResponses['Indie Artist Underground Gem'] = [
        Song(
          id: 'yt_explode_gem',
          title: 'Underground Gem',
          artist: 'Indie Artist',
          duration: const Duration(seconds: 190),
          thumbnails: const Thumbnails(),
          source: MusicSource.youtube,
          youtubeId: 'yt_explode_gem',
        ),
      ];

      final resultEither = await repository.importSpotifyPlaylist('https://open.spotify.com/playlist/pl_indie');
      expect(resultEither.isRight(), isTrue);

      final result = resultEither.getOrElse(() => throw Exception());
      expect(result.matchedCount, 1);
      expect(result.unmatchedCount, 0);

      final matched = result.matchedTracks.first;
      expect(matched.youtubeId, 'yt_explode_gem');
      expect(matched.streamProvenance, 'youtube_explode_matched');
    });

    test('rejects low confidence candidates with version mismatch and records unmatched track', () async {
      final matchedTarget = Song(
        id: 'spotify_track_good',
        title: 'Perfect Match',
        artist: 'Band',
        duration: const Duration(seconds: 200),
        thumbnails: const Thumbnails(),
        source: MusicSource.spotify,
      );

      final mismatchedTarget = Song(
        id: 'spotify_track_studio',
        title: 'Studio Original',
        artist: 'Band',
        duration: const Duration(seconds: 240),
        thumbnails: const Thumbnails(),
        source: MusicSource.spotify,
      );

      mockSpotify.detailsResult = SpotifyPlaylistDetails(
        id: 'pl_unmatched',
        name: 'Unmatched Test',
        tracks: [matchedTarget, mismatchedTarget],
        totalTracks: 2,
      );

      // Track 1 matches cleanly
      mockYtMusicApi.queryResponses['Band Perfect Match'] = [
        {
          'videoId': 'yt_good',
          'title': 'Perfect Match',
          'artists': [{'name': 'Band'}],
          'duration': '3:20',
          'duration_seconds': 200,
        }
      ];

      // Track 2 is a Live Acoustic Remix with duration 100 seconds off
      mockYtMusicApi.queryResponses['Band Studio Original'] = [
        {
          'videoId': 'yt_live_remix',
          'title': 'Studio Original (Live Acoustic Remix 2020)',
          'artists': [{'name': 'Band'}],
          'duration': '5:40',
          'duration_seconds': 340,
        }
      ];

      final resultEither = await repository.importSpotifyPlaylist('https://open.spotify.com/playlist/pl_unmatched');
      expect(resultEither.isRight(), isTrue);

      final result = resultEither.getOrElse(() => throw Exception());
      expect(result.matchedCount, 1);
      expect(result.unmatchedCount, 1);
      expect(result.matchPercent, 50);
      expect(result.unmatchedTracks.first.title, 'Studio Original');
    });

    test('cancels matching loop immediately when ImportCancellationToken is cancelled', () async {
      final tracks = List.generate(
        10,
        (i) => Song(
          id: 'sp_$i',
          title: 'Song $i',
          artist: 'Artist $i',
          duration: const Duration(seconds: 180),
          thumbnails: const Thumbnails(),
          source: MusicSource.spotify,
        ),
      );

      mockSpotify.detailsResult = SpotifyPlaylistDetails(
        id: 'pl_cancel',
        name: 'Cancel Test',
        tracks: tracks,
        totalTracks: 10,
      );

      final cancelToken = ImportCancellationToken();

      // Set up candidate matching
      for (int i = 0; i < 10; i++) {
        mockYtMusicApi.queryResponses['Artist $i Song $i'] = [
          {
            'videoId': 'yt_$i',
            'title': 'Song $i',
            'artists': [{'name': 'Artist $i'}],
            'duration': '3:00',
            'duration_seconds': 180,
          }
        ];
      }

      int progressCalls = 0;
      final resultEither = await repository.importSpotifyPlaylist(
        'https://open.spotify.com/playlist/pl_cancel',
        cancelToken: cancelToken,
        onProgress: (progress, current, total) {
          progressCalls++;
          if (current >= 3) {
            cancelToken.cancel();
          }
        },
      );

      expect(resultEither.isRight(), isTrue);
      final result = resultEither.getOrElse(() => throw Exception());

      expect(result.wasCancelled, isTrue);
      expect(progressCalls, greaterThanOrEqualTo(3));
      // Stopped processing remaining tracks
      expect(result.matchedCount, lessThan(10));
      expect(cancelToken.isCancelled, isTrue);
    });
  });
}
