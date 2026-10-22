import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/providers/audio_stream_resolver.dart';
import 'package:prism_music/domain/entities/song.dart';
import 'package:prism_music/domain/entities/stream_info.dart';

/// Mock resolver that simulates a primary provider (e.g. JioSaavn).
class MockPrimaryResolver implements AudioStreamResolver {
  final bool shouldFail;
  final String streamUrl;

  MockPrimaryResolver({
    this.shouldFail = false,
    this.streamUrl = 'https://cdn.jiosaavn.mock/stream_320.m4a',
  });

  @override
  String get resolverName => 'mock_primary';

  @override
  bool get isAvailable => !shouldFail;

  @override
  Future<StreamInfo?> resolveStream(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    if (shouldFail) return null;

    return StreamInfo(
      url: streamUrl,
      codec: 'aac',
      bitrate: 320,
      container: 'm4a',
      quality: preferredQuality,
      streamProvenance: resolverName,
      expiresAt: DateTime.now().add(const Duration(hours: 4)),
    );
  }
}

/// Mock resolver that simulates a secondary provider (e.g. YouTubeExplode fallback).
class MockFallbackResolver implements AudioStreamResolver {
  final String streamUrl;

  MockFallbackResolver({
    this.streamUrl = 'https://rr1---sn-mock.googlevideo.com/videoplayback',
  });

  @override
  String get resolverName => 'mock_fallback';

  @override
  bool get isAvailable => true;

  @override
  Future<StreamInfo?> resolveStream(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    return StreamInfo(
      url: streamUrl,
      codec: 'opus',
      bitrate: 160,
      container: 'webm',
      quality: preferredQuality,
      streamProvenance: resolverName,
      expiresAt: DateTime.now().add(const Duration(hours: 6)),
    );
  }
}

void main() {
  const testSong = Song(
    id: 'track_123',
    title: 'Isolated Track',
    artist: 'Independent Artist',
    duration: Duration(seconds: 210),
    thumbnails: Thumbnails(),
    source: MusicSource.jiosaavn,
    jioSaavnId: 'js_123',
    youtubeId: 'yt_123',
  );

  group('AudioStreamResolver isolated contract', () {
    test('primary resolver returns structured metadata and stream URL', () async {
      final primary = MockPrimaryResolver();
      expect(primary.isAvailable, isTrue);

      final result = await primary.resolveStream(testSong);
      expect(result, isNotNull);
      expect(result!.url, contains('https://cdn.jiosaavn.mock'));
      expect(result.streamProvenance, 'mock_primary');
      expect(result.bitrate, 320);
      expect(result.codec, 'aac');
      expect(result.container, 'm4a');
      expect(result.expiresAt, isNotNull);
      expect(result.isExpired, isFalse);
    });

    test('fallback resolver executes when primary is unavailable or fails', () async {
      final primary = MockPrimaryResolver(shouldFail: true);
      final fallback = MockFallbackResolver();

      StreamInfo? resolved;
      final chain = [primary, fallback];

      for (final r in chain) {
        if (!r.isAvailable) continue;
        resolved = await r.resolveStream(testSong);
        if (resolved != null) break;
      }

      expect(resolved, isNotNull);
      expect(resolved!.streamProvenance, 'mock_fallback');
      expect(resolved.url, contains('googlevideo.com'));
      expect(resolved.bitrate, 160);
    });
  });
}
