import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/audio_player_service.dart';

void main() {
  group('AudioPlayerService Track Classifier Tests', () {
    test('isLocalPath detects file:// URIs and non-HTTP paths', () {
      expect(AudioPlayerService.isLocalPath('file:///storage/emulated/0/track.mp3'), isTrue);
      expect(AudioPlayerService.isLocalPath('https://aac.saavncdn.com/test.mp4'), isFalse);
      expect(AudioPlayerService.isLocalPath('http://youtube.com/watch?v=123'), isFalse);
      expect(AudioPlayerService.isLocalPath(null), isFalse);
      expect(AudioPlayerService.isLocalPath(''), isFalse);
    });

    test('isYouTubeTrack detects YouTube and GoogleVideo streams correctly', () {
      expect(
        AudioPlayerService.isYouTubeTrack(
          url: 'https://rr5---sn-4g5ednks.googlevideo.com/videoplayback?...',
          videoId: 'abc12345678',
        ),
        isTrue,
      );

      expect(
        AudioPlayerService.isYouTubeTrack(
          url: 'https://www.youtube.com/watch?v=abc12345678',
        ),
        isTrue,
      );

      expect(
        AudioPlayerService.isYouTubeTrack(
          url: null,
          videoId: 'abc12345678',
        ),
        isTrue,
      );
    });

    test('isYouTubeTrack does not route JioSaavn direct CDN streams as YouTube', () {
      // Even if an external caller passed a non-empty videoId (e.g. JioSaavn song ID),
      // a JioSaavn CDN URL must NOT be routed as YouTubeAudioSource.
      expect(
        AudioPlayerService.isYouTubeTrack(
          url: 'https://aac.saavncdn.com/123/456_320.mp4',
          videoId: 'jiosaavn_track_456',
        ),
        isFalse,
      );
    });

    test('isYouTubeTrack never routes local downloaded tracks to YouTube path', () {
      expect(
        AudioPlayerService.isYouTubeTrack(
          url: 'file:///data/user/0/com.prism/files/downloads/song.m4a',
          videoId: 'offline_vid_123',
        ),
        isFalse,
      );
    });

    test('uriForUrl converts local paths and web URIs correctly', () {
      final fileUri = AudioPlayerService.uriForUrl('file:///storage/track.mp3');
      expect(fileUri.scheme, equals('file'));

      final webUri = AudioPlayerService.uriForUrl('https://example.com/audio.mp3');
      expect(webUri.scheme, equals('https'));
    });
  });
}
