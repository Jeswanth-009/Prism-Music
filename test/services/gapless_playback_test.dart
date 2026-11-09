import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/audio_player_service.dart';
import 'package:prism_music/core/services/youtube_audio_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gapless Playback & Stream Prewarming', () {
    setUp(() {
      YouTubeAudioSource.clearGlobalCache();
    });

    tearDown(() {
      YouTubeAudioSource.clearGlobalCache();
    });

    test('verifies stream cache hit checking with consistent videoId and quality key', () {
      expect(YouTubeAudioSource.isStreamCached('song123', quality: 'high'), isFalse);
      expect(YouTubeAudioSource.isStreamCached('song123', quality: 'medium'), isFalse);

      // Invalidate on non-cached item safely no-ops
      YouTubeAudioSource.invalidate('song123');
      expect(YouTubeAudioSource.isStreamCached('song123'), isFalse);
    });

    test('AudioPlayerService initializes and reports queue mode correctly', () {
      final audioService = AudioPlayerService();
      expect(audioService.isQueueMode, isFalse);
      expect(audioService.queueSourcesLength, 0);

      // Cleaning up
      audioService.dispose();
    });
  });
}
