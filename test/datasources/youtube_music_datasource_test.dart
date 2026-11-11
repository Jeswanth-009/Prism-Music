import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prism_music/core/error/exceptions.dart';
import 'package:prism_music/core/services/ytmusic_api_service.dart';
import 'package:prism_music/data/datasources/local/local_datasource.dart';
import 'package:prism_music/data/datasources/remote/jiosaavn/jiosaavn_datasource.dart';
import 'package:prism_music/data/datasources/remote/lyrics/lyrics_datasource.dart';
import 'package:prism_music/data/datasources/remote/spotify/spotify_datasource.dart';
import 'package:prism_music/data/datasources/remote/youtube/invidious_datasource.dart';
import 'package:prism_music/data/datasources/remote/youtube/piped_datasource.dart';
import 'package:prism_music/data/datasources/remote/youtube/youtube_music_datasource.dart';
import 'package:prism_music/data/repositories/music_repository_impl.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

class _MockYoutubeExplode extends Mock implements yt.YoutubeExplode {}

class _MockVideoClient extends Mock implements yt.VideoClient {}

class _MockPlaylistClient extends Mock implements yt.PlaylistClient {}

class _MockSearchClient extends Mock implements yt.SearchClient {}

class _MockPipedDataSource extends Mock implements PipedDataSource {}

class _MockInvidiousDataSource extends Mock implements InvidiousDataSource {}

class _MockYouTubeMusicDataSource extends Mock
    implements YouTubeMusicDataSource {}

class _MockSpotifyDataSource extends Mock implements SpotifyDataSource {}

class _MockLyricsDataSource extends Mock implements LyricsDataSource {}

class _MockLocalDataSource extends Mock implements LocalDataSource {}

class _MockJioSaavnDataSource extends Mock implements JioSaavnDataSource {}

class _MockYtMusicApiService extends Mock implements YtMusicApiService {}

void main() {
  late _MockYoutubeExplode mockYoutube;
  late _MockVideoClient mockVideos;
  late _MockPlaylistClient mockPlaylists;
  late _MockSearchClient mockSearch;
  late _MockPipedDataSource mockPiped;
  late _MockInvidiousDataSource mockInvidious;
  late YouTubeMusicDataSourceImpl dataSource;

  setUp(() {
    mockYoutube = _MockYoutubeExplode();
    mockVideos = _MockVideoClient();
    mockPlaylists = _MockPlaylistClient();
    mockSearch = _MockSearchClient();
    mockPiped = _MockPipedDataSource();
    mockInvidious = _MockInvidiousDataSource();

    when(() => mockYoutube.videos).thenReturn(mockVideos);
    when(() => mockYoutube.playlists).thenReturn(mockPlaylists);
    when(() => mockYoutube.search).thenReturn(mockSearch);

    dataSource = YouTubeMusicDataSourceImpl(
      youtube: mockYoutube,
      invidious: mockInvidious,
      piped: mockPiped,
    );
  });

  group('YouTubeMusicDataSourceImpl fallbacks', () {
    test('searchSongs falls back to Piped when YoutubeExplode throws', () async {
      when(() => mockSearch.search(any()))
          .thenThrow(Exception('YouTube cipher API changed'));
      when(() => mockPiped.search('daft punk', filter: 'music_songs')).thenAnswer(
        (_) async => [
          {
            'url': '/watch?v=yt_dp_1',
            'title': 'Daft Punk - Instant Crush (Official Video)',
            'uploaderName': 'DaftPunkVEVO',
            'duration': 337,
            'thumbnail': 'https://i.ytimg.com/vi/yt_dp_1/hqdefault.jpg',
          },
          {
            // Short < 45s snippet should be filtered by _dedupMusicSongs
            'url': '/watch?v=yt_dp_short',
            'title': 'Daft Punk - Teaser',
            'uploaderName': 'DaftPunkVEVO',
            'duration': 15,
          },
        ],
      );

      final songs = await dataSource.searchSongs('daft punk');

      expect(songs.length, 1);
      expect(songs.first.id, 'yt_dp_1');
      expect(songs.first.title, 'Instant Crush');
      expect(songs.first.artist, 'Daft Punk');
      expect(songs.first.duration, const Duration(seconds: 337));
      expect(songs.first.source, MusicSource.youtube);
      verify(() => mockPiped.search('daft punk', filter: 'music_songs')).called(1);
    });

    test('getSongDetails falls back to Piped when YoutubeExplode throws', () async {
      when(() => mockVideos.get('vid_123'))
          .thenThrow(Exception('Video page extraction failed'));
      when(() => mockPiped.getVideoDetails('vid_123')).thenAnswer(
        (_) async => {
          'title': 'The Weeknd - Blinding Lights (Official Audio)',
          'uploader': 'The Weeknd - Topic',
          'duration': 200,
          'thumbnailUrl': 'https://i.ytimg.com/vi/vid_123/hqdefault.jpg',
        },
      );

      final song = await dataSource.getSongDetails('vid_123');

      expect(song.id, 'vid_123');
      expect(song.title, 'Blinding Lights');
      expect(song.artist, 'The Weeknd');
      expect(song.duration, const Duration(seconds: 200));
      verify(() => mockPiped.getVideoDetails('vid_123')).called(1);
    });

    test('getRelatedSongs falls back to Invidious mix when YoutubeExplode fails',
        () async {
      when(() => mockPlaylists.getVideos('RDMMseed_1'))
          .thenAnswer((_) => Stream<yt.Video>.error(Exception('Mix 403')));
      when(() => mockVideos.get('seed_1'))
          .thenThrow(Exception('Video details 403'));
      when(() => mockInvidious.getPlaylistDetails('RDMMseed_1')).thenAnswer(
        (_) async => InvidiousPlaylistData(
          title: 'Mix',
          songs: [
            Song(
              id: 'seed_1',
              title: 'Seed Track',
              artist: 'Artist A',
              duration: const Duration(seconds: 210),
              thumbnails: Thumbnails.empty(),
              source: MusicSource.youtube,
              youtubeId: 'seed_1',
            ),
            Song(
              id: 'rel_1',
              title: 'Related Hit',
              artist: 'Artist B',
              duration: const Duration(seconds: 240),
              thumbnails: Thumbnails.empty(),
              source: MusicSource.youtube,
              youtubeId: 'rel_1',
            ),
          ],
        ),
      );

      final related = await dataSource.getRelatedSongs('seed_1');

      expect(related.length, 1);
      expect(related.first.id, 'rel_1');
      verify(() => mockInvidious.getPlaylistDetails('RDMMseed_1')).called(1);
      verifyNever(() => mockPiped.getVideoDetails(any()));
    });

    test('getRelatedSongs falls back to Piped relatedStreams when Invidious returns null',
        () async {
      when(() => mockPlaylists.getVideos('RDMMseed_2'))
          .thenAnswer((_) => Stream<yt.Video>.error(Exception('Mix 403')));
      when(() => mockVideos.get('seed_2'))
          .thenThrow(Exception('Video details 403'));
      when(() => mockInvidious.getPlaylistDetails('RDMMseed_2'))
          .thenAnswer((_) async => null);
      when(() => mockPiped.getVideoDetails('seed_2')).thenAnswer(
        (_) async => {
          'relatedStreams': [
            {
              'url': '/watch?v=piped_rel_1',
              'title': 'Midnight City (Official Music Video)',
              'uploaderName': 'M83',
              'duration': 243,
              'thumbnail': 'https://i.ytimg.com/vi/piped_rel_1/hqdefault.jpg',
            },
          ],
        },
      );

      final related = await dataSource.getRelatedSongs('seed_2');

      expect(related.length, 1);
      expect(related.first.id, 'piped_rel_1');
      expect(related.first.title, 'Midnight City');
      verify(() => mockPiped.getVideoDetails('seed_2')).called(1);
    });
  });

  group('MusicRepositoryImpl YouTube/YTMusic fallbacks', () {
    late _MockYouTubeMusicDataSource mockYtRepoDs;
    late _MockSpotifyDataSource mockSpotify;
    late _MockLyricsDataSource mockLyrics;
    late _MockLocalDataSource mockLocal;
    late _MockJioSaavnDataSource mockJio;
    late _MockYtMusicApiService mockYtApi;
    late _MockPipedDataSource repoPiped;
    late _MockInvidiousDataSource repoInvidious;
    late MusicRepositoryImpl repository;

    setUp(() {
      mockYtRepoDs = _MockYouTubeMusicDataSource();
      mockSpotify = _MockSpotifyDataSource();
      mockLyrics = _MockLyricsDataSource();
      mockLocal = _MockLocalDataSource();
      mockJio = _MockJioSaavnDataSource();
      mockYtApi = _MockYtMusicApiService();
      repoPiped = _MockPipedDataSource();
      repoInvidious = _MockInvidiousDataSource();

      repository = MusicRepositoryImpl(
        youtubeMusicDataSource: mockYtRepoDs,
        spotifyDataSource: mockSpotify,
        lyricsDataSource: mockLyrics,
        localDataSource: mockLocal,
        jioSaavnDataSource: mockJio,
        ytMusicApiService: mockYtApi,
        pipedDataSource: repoPiped,
        invidiousDataSource: repoInvidious,
      );
    });

    test('getStreamUrl falls back from YoutubeExplode -> Piped -> Invidious',
        () async {
      when(
        () => mockYtRepoDs.getStreamUrl(
          'vid_stream_1',
          preferredQuality: AudioQuality.high,
          forceRefresh: false,
        ),
      ).thenThrow(const StreamNotFoundException(
        videoId: 'vid_stream_1',
        message: 'cipher broken',
      ));
      when(() => repoPiped.getStreamUrl('vid_stream_1'))
          .thenAnswer((_) async => null);
      const expectedStream = StreamInfo(
        url: 'https://inv.example/latest_version?id=vid_stream_1&itag=140',
        codec: 'aac',
        bitrate: 128,
        container: 'm4a',
        quality: AudioQuality.medium,
        isAudioOnly: true,
        streamProvenance: 'invidious_instance',
      );
      when(() => repoInvidious.getStreamUrl('vid_stream_1'))
          .thenAnswer((_) async => expectedStream);

      final result = await repository.getStreamUrl('vid_stream_1');

      expect(result.isRight(), isTrue);
      expect(
        result.getOrElse((_) => throw StateError('expected stream')).url,
        expectedStream.url,
      );
      verify(() => repoPiped.getStreamUrl('vid_stream_1')).called(1);
      verify(() => repoInvidious.getStreamUrl('vid_stream_1')).called(1);
    });

    test('getTrending falls back to YouTubeMusicDataSource when YtMusicApi throws',
        () async {
      when(() => mockYtApi.searchSongs(any()))
          .thenThrow(Exception('dart_ytmusic_api parser broken'));
      when(() => mockYtRepoDs.searchSongs(any(), limit: 10)).thenAnswer(
        (_) async => [
          Song(
            id: 'trend_1',
            title: 'Trending Fallback Track',
            artist: 'Popular Artist',
            duration: const Duration(seconds: 195),
            thumbnails: Thumbnails.empty(),
            source: MusicSource.youtube,
            youtubeId: 'trend_1',
          ),
        ],
      );

      final result = await repository.getTrending(region: 'US', limit: 10);

      expect(result.isRight(), isTrue);
      final songs = result.getOrElse((_) => throw StateError('expected list'));
      expect(songs.length, 1);
      expect(songs.first.id, 'trend_1');
    });
  });
}
