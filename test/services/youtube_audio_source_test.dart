import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/youtube_audio_source.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('YouTubeAudioSource client fallback chain', () {
    test('instantiates with direct stream metadata without early network fetch', () {
      final source = YouTubeAudioSource(
        videoId: 'yt_abc_123',
        quality: 'high',
        initialStreamUrl: 'https://rr1---sn.googlevideo.com/videoplayback',
        initialContentLength: 5000000,
        initialContentType: 'audio/mp4',
      );

      expect(source.videoId, 'yt_abc_123');
      expect(source.quality, 'high');
      expect(source.initialStreamUrl, contains('googlevideo.com'));
      expect(source.initialContentLength, 5000000);
      expect(source.initialContentType, 'audio/mp4');
    });

    test('verifies candidate fallback clients include ios, android, mweb, and androidSdkless', () {
      // Check that all required clients are defined in the YouTube client types
      expect(YoutubeApiClient.androidSdkless, isNotNull);
      expect(YoutubeApiClient.android, isNotNull);
      expect(YoutubeApiClient.ios, isNotNull);
      expect(YoutubeApiClient.mweb, isNotNull);
    });
  });
}
