import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prism_music/core/services/music_video_service.dart';
import 'package:prism_music/data/datasources/remote/youtube/piped_datasource.dart';
import 'package:prism_music/domain/entities/song.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

class _MockYoutubeExplode extends Mock implements yt.YoutubeExplode {}

class _MockVideoClient extends Mock implements yt.VideoClient {}

class _MockStreamClient extends Mock implements yt.StreamClient {}

class _MockPipedDataSource extends Mock implements PipedDataSource {}

void main() {
  group('MusicVideoService', () {
    late MusicVideoService service;

    setUp(() {
      service = MusicVideoService();
    });

    tearDown(() {
      service.dispose();
    });

    test('isVideoAvailable identifies YouTube songs correctly', () {
      final ytSong = Song(
        id: 'dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        artist: 'Rick Astley',
        duration: const Duration(seconds: 212),
        thumbnails: Thumbnails.fromUrl('https://example.com/thumb.jpg'),
        source: MusicSource.youtube,
        youtubeId: 'dQw4w9WgXcQ',
      );

      const nonYtSong = Song(
        id: 'local_1',
        title: 'Local Song',
        artist: 'Local Artist',
        duration: Duration(seconds: 180),
        thumbnails: Thumbnails(),
        source: MusicSource.local,
      );

      final ytMatchedSong = Song(
        id: 'sp_1',
        title: 'Spotify Track',
        artist: 'Spotify Artist',
        duration: const Duration(seconds: 200),
        thumbnails: Thumbnails.fromUrl('https://example.com/thumb2.jpg'),
        source: MusicSource.spotify,
        youtubeId: 'dQw4w9WgXcQ',
      );

      expect(service.isVideoAvailable(ytSong), isTrue);
      expect(service.isVideoAvailable(nonYtSong), isFalse);
      expect(service.isVideoAvailable(ytMatchedSong), isTrue);
      expect(service.isVideoAvailable(null), isFalse);
    });

    test('clearCache empties cache safely', () {
      expect(() => service.clearCache(), returnsNormally);
    });

    test('getVideoStream falls back to Piped videoStreams when YoutubeExplode fails',
        () async {
      final mockYoutube = _MockYoutubeExplode();
      final mockVideos = _MockVideoClient();
      final mockStreams = _MockStreamClient();
      final mockPiped = _MockPipedDataSource();

      when(() => mockYoutube.videos).thenReturn(mockVideos);
      when(() => mockVideos.streamsClient).thenReturn(mockStreams);
      when(
        () => mockStreams.getManifest(
          'vid_mv_1',
          ytClients: any(named: 'ytClients'),
          requireWatchPage: any(named: 'requireWatchPage'),
        ),
      ).thenThrow(Exception('YoutubeExplode 403'));

      when(() => mockPiped.getVideoDetails('vid_mv_1')).thenAnswer(
        (_) async => {
          'videoStreams': [
            {
              'url': 'https://piped.example/video_360.mp4',
              'quality': '360p',
              'videoOnly': false,
              'codec': 'avc1',
              'format': 'MPEG_4',
              'bitrate': 700000,
            },
            {
              'url': 'https://piped.example/video_720.mp4',
              'quality': '720p',
              'videoOnly': false,
              'codec': 'avc1',
              'format': 'mp4',
              'bitrate': 1500000,
            },
          ],
        },
      );

      final fallbackService = MusicVideoService(
        youtube: mockYoutube,
        piped: mockPiped,
      );

      final result = await fallbackService.getVideoStream(
        'vid_mv_1',
        preferredQuality: '720p',
      );

      expect(result, isNotNull);
      expect(result!.url, 'https://piped.example/video_720.mp4');
      expect(result.streamProvenance, 'piped_video');
      expect(result.isAudioOnly, isFalse);
      verify(() => mockPiped.getVideoDetails('vid_mv_1')).called(1);

      // Cached hit does not hit Piped again
      final cached = await fallbackService.getVideoStream('vid_mv_1');
      expect(cached?.url, 'https://piped.example/video_720.mp4');
      verifyNever(() => mockPiped.getVideoDetails(any()));
      fallbackService.dispose();
    });
  });
}
