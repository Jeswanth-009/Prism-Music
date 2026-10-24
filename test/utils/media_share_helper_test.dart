import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/utils/media_share_helper.dart';
import 'package:prism_music/domain/entities/playlist.dart';
import 'package:prism_music/domain/entities/song.dart';

void main() {
  group('MediaShareHelper - Video & Playlist ID Validation', () {
    test('isValidYouTubeVideoId accepts standard 11-char and alphanumeric IDs', () {
      expect(MediaShareHelper.isValidYouTubeVideoId('dQw4w9WgXcQ'), isTrue);
      expect(MediaShareHelper.isValidYouTubeVideoId('yt_123456'), isTrue);
      expect(MediaShareHelper.isValidYouTubeVideoId('abc_123-XYZ'), isTrue);
    });

    test('isValidYouTubeVideoId rejects invalid, prefixed, or malformed IDs', () {
      expect(MediaShareHelper.isValidYouTubeVideoId(null), isFalse);
      expect(MediaShareHelper.isValidYouTubeVideoId(''), isFalse);
      expect(MediaShareHelper.isValidYouTubeVideoId('saavn_998877'), isFalse);
      expect(MediaShareHelper.isValidYouTubeVideoId('spotify:track:123'), isFalse);
      expect(MediaShareHelper.isValidYouTubeVideoId('spotify_456'), isFalse);
      expect(MediaShareHelper.isValidYouTubeVideoId('local_song_1'), isFalse);
      expect(MediaShareHelper.isValidYouTubeVideoId('https://evil.com/video'), isFalse);
      expect(MediaShareHelper.isValidYouTubeVideoId('bad id with spaces'), isFalse);
      expect(MediaShareHelper.isValidYouTubeVideoId('a/b/c'), isFalse);
    });

    test('isValidYouTubePlaylistId accepts valid playlist IDs and rejects bad ones', () {
      expect(MediaShareHelper.isValidYouTubePlaylistId('PL4fGSI1pDJn6puJdseH2Rt9sMvt9E2M4i'), isTrue);
      expect(MediaShareHelper.isValidYouTubePlaylistId('RDCLAK5uy_kmPRjHDECIcuVwnKsx2Ng7fyNgFKWNJFs'), isTrue);
      expect(MediaShareHelper.isValidYouTubePlaylistId(null), isFalse);
      expect(MediaShareHelper.isValidYouTubePlaylistId(''), isFalse);
      expect(MediaShareHelper.isValidYouTubePlaylistId('short'), isFalse);
      expect(MediaShareHelper.isValidYouTubePlaylistId('https://youtube.com/list'), isFalse);
    });
  });

  group('MediaShareHelper - URL Resolution & Song Card Formatting', () {
    const youtubeSong = Song(
      id: 'dQw4w9WgXcQ',
      title: 'Never Gonna Give You Up',
      artist: 'Rick Astley',
      album: 'Whenever You Need Somebody',
      duration: Duration(minutes: 3, seconds: 32),
      youtubeId: 'dQw4w9WgXcQ',
      thumbnails: Thumbnails(),
    );

    const nonYoutubeSong = Song(
      id: 'saavn_554433',
      title: 'Kesariya',
      artist: 'Arijit Singh',
      album: 'Brahmastra',
      duration: Duration(minutes: 4, seconds: 28),
      thumbnails: Thumbnails(),
    );

    test('buildReliableSongUrl returns valid YouTube URL when youtubeId is reliable', () {
      final url = MediaShareHelper.buildReliableSongUrl(youtubeSong);
      expect(url, equals('https://music.youtube.com/watch?v=dQw4w9WgXcQ'));
    });

    test('buildReliableSongUrl returns null for non-YouTube tracks to prevent 404 links', () {
      final url = MediaShareHelper.buildReliableSongUrl(nonYoutubeSong);
      expect(url, isNull);
    });

    test('formatShareableSongText includes direct link for verified tracks', () {
      final text = MediaShareHelper.formatShareableSongText(youtubeSong);
      expect(text, contains('🎵 Never Gonna Give You Up'));
      expect(text, contains('Artist: Rick Astley'));
      expect(text, contains('Listen: https://music.youtube.com/watch?v=dQw4w9WgXcQ'));
      expect(text, contains('Shared from Prism Music'));
    });

    test('formatShareableSongText formats clean metadata card without broken URL when link is unverified', () {
      final text = MediaShareHelper.formatShareableSongText(nonYoutubeSong);
      expect(text, contains('🎵 Kesariya'));
      expect(text, contains('Artist: Arijit Singh'));
      expect(text, contains('Album: Brahmastra'));
      expect(text, contains('Duration: 4:28'));
      expect(text, isNot(contains('https://music.youtube.com')));
      expect(text, contains('Shared from Prism Music'));
    });
  });

  group('MediaShareHelper - Playlist Card Formatting', () {
    const song1 = Song(
      id: 's1',
      title: 'Song One',
      artist: 'Artist Alpha',
      duration: Duration(minutes: 3),
      thumbnails: Thumbnails(),
    );
    const song2 = Song(
      id: 's2',
      title: 'Song Two',
      artist: 'Artist Beta',
      duration: Duration(minutes: 4),
      thumbnails: Thumbnails(),
    );

    const testPlaylist = Playlist(
      id: 'pl_100',
      name: 'Sunset Vibes',
      description: 'Chill twilight tunes',
      isUserCreated: true,
      youtubePlaylistId: 'PL4fGSI1pDJn6puJdseH2Rt9sMvt9E2M4i',
      songs: [song1, song2],
    );

    test('formatShareablePlaylistCard includes summary stats, artists, and link', () {
      final card = MediaShareHelper.formatShareablePlaylistCard(testPlaylist);
      expect(card, contains('🎶 Sunset Vibes'));
      expect(card, contains('Chill twilight tunes'));
      expect(card, contains('📋 2 tracks • 7m'));
      expect(card, contains('🌟 Featuring: Artist Alpha, Artist Beta'));
      expect(card, contains('🔗 https://music.youtube.com/playlist?list=PL4fGSI1pDJn6puJdseH2Rt9sMvt9E2M4i'));
      expect(card, contains('Shared from Prism Music'));
    });
  });
}
