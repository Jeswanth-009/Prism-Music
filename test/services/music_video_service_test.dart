import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/music_video_service.dart';
import 'package:prism_music/domain/entities/song.dart';

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
  });
}
