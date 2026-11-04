import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/ytmusic_api_service.dart';
import 'package:prism_music/core/utils/cancellation_token.dart';
import 'package:prism_music/data/datasources/local/local_datasource.dart';
import 'package:prism_music/data/datasources/remote/apple_music/apple_music_datasource.dart';
import 'package:prism_music/data/datasources/remote/jiosaavn/jiosaavn_datasource.dart';
import 'package:prism_music/data/datasources/remote/lyrics/lyrics_datasource.dart';
import 'package:prism_music/data/datasources/remote/spotify/spotify_datasource.dart';
import 'package:prism_music/data/datasources/remote/youtube/youtube_music_datasource.dart';
import 'package:prism_music/data/repositories/music_repository_impl.dart';
import 'package:prism_music/domain/entities/entities.dart';

class MockAppleMusicDataSource implements AppleMusicDataSource {
  AppleMusicPlaylistDetails? detailsResult;
  String? lastUrl;
  ImportCancellationToken? lastCancelToken;

  @override
  Future<AppleMusicPlaylistDetails?> getPlaylistDetails(
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

class MockSpotifyDataSource implements SpotifyDataSource {
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

  group('Apple Music Import & ISRC Matching', () {
    late MockAppleMusicDataSource mockAppleMusic;
    late MockYtMusicApiService mockYtMusicApi;
    late MusicRepositoryImpl repository;

    setUp(() {
      mockAppleMusic = MockAppleMusicDataSource();
      mockYtMusicApi = MockYtMusicApiService();

      repository = MusicRepositoryImpl(
        appleMusicDataSource: mockAppleMusic,
        spotifyDataSource: MockSpotifyDataSource(),
        ytMusicApiService: mockYtMusicApi,
        youtubeMusicDataSource: MockYouTubeMusicDataSource(),
        lyricsDataSource: MockLyricsDataSource(),
        localDataSource: MockLocalDataSource(),
        jioSaavnDataSource: MockJioSaavnDataSource(),
      );
    });

    test('prioritizes ISRC lookup on YouTube Music for Apple Music tracks', () async {
      final targetTrack = Song(
        id: 'am_123',
        title: 'Espresso',
        artist: 'Sabrina Carpenter',
        album: "Short n' Sweet",
        duration: const Duration(seconds: 175),
        thumbnails: const Thumbnails(),
        isrc: 'USUM72403305',
      );

      mockAppleMusic.detailsResult = AppleMusicPlaylistDetails(
        id: 'pl.f4d1060b525243e6a05420188a71bf1b',
        name: "Today's Hits",
        curator: 'Apple Music',
        tracks: [targetTrack],
      );

      // YouTube Music mock candidate responding to ISRC query
      mockYtMusicApi.queryResponses['USUM72403305'] = [
        {
          'videoId': 'yt_espresso_123',
          'title': 'Espresso',
          'artists': [{'name': 'Sabrina Carpenter'}],
          'album': {'name': "Short n' Sweet"},
          'duration_seconds': 175,
          'thumbnails': [{'url': 'https://yt.example.com/art.jpg', 'width': 300, 'height': 300}],
        }
      ];

      final resultEither = await repository.importAppleMusicPlaylist(
        'https://music.apple.com/us/playlist/todays-hits/pl.f4d1060b525243e6a05420188a71bf1b',
      );

      expect(resultEither.isRight(), isTrue);
      final result = resultEither.getOrElse(() => throw Exception());

      expect(result.playlist.appleMusicPlaylistId, 'pl.f4d1060b525243e6a05420188a71bf1b');
      expect(result.matchedTracks.length, 1);
      expect(result.matchedTracks.first.playableId, 'yt_espresso_123');
      expect(mockYtMusicApi.queriedTerms.contains('USUM72403305'), isTrue);
    });
  });
}
