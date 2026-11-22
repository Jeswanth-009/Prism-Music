import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:prism_music/core/providers/audio_stream_resolver.dart';
import 'package:prism_music/core/providers/innertube/innertube_client.dart';
import 'package:prism_music/core/providers/innertube/innertube_stream_resolver.dart';
import 'package:prism_music/domain/entities/song.dart';
import 'package:prism_music/domain/entities/stream_info.dart';

class _FakeInnerTubeClient extends InnerTubeClient {
  final bool shouldFail;
  final List<InnerTubeAudioFormat> formats;

  _FakeInnerTubeClient({
    this.shouldFail = false,
    this.formats = const [],
  });

  @override
  Future<List<InnerTubeAudioFormat>> fetchAudioFormats(
    String videoId, {
    InnerTubeClientContext context = InnerTubeClientContext.tvSamsung,
  }) async {
    if (shouldFail) throw Exception('Simulated InnerTube failure');
    return formats;
  }
}

class _FakeFallbackResolver implements AudioStreamResolver {
  final StreamInfo? streamInfo;

  _FakeFallbackResolver({this.streamInfo});

  @override
  String get resolverName => 'fake_fallback';

  @override
  bool get isAvailable => true;

  @override
  Future<StreamInfo?> resolveStream(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    return streamInfo;
  }
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('innertube_test_hive_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  const testSong = Song(
    id: 'test_song_1',
    title: 'Test Song',
    artist: 'Test Artist',
    duration: Duration(minutes: 3),
    thumbnails: Thumbnails(),
  );

  group('InnerTubeStreamResolver', () {
    test('resolves stream successfully when InnerTube returns formats', () async {
      final fakeFormats = [
        const InnerTubeAudioFormat(
          itag: 140,
          url: 'https://googlevideo.com/videoplayback?id=123',
          mimeType: 'audio/mp4; codecs="mp4a.40.2"',
          bitrate: 320000,
          contentLength: 4500000,
          clientContextName: 'TV_SAMSUNG',
        ),
      ];

      final resolver = InnerTubeStreamResolver(
        client: _FakeInnerTubeClient(formats: fakeFormats),
      );

      final result = await resolver.resolveStream(testSong);

      expect(result, isNotNull);
      expect(result!.url, equals('https://googlevideo.com/videoplayback?id=123'));
      expect(result.bitrate, equals(320));
      expect(result.quality, equals(AudioQuality.ultra));
      expect(result.streamProvenance, contains('tvSamsung'));
    });

    test('falls back to secondary resolver when InnerTube fails', () async {
      const fallbackStream = StreamInfo(
        url: 'https://fallback.example.com/audio.mp4',
        codec: 'mp4a',
        bitrate: 160,
        container: 'mp4',
        quality: AudioQuality.high,
        streamProvenance: 'fake_fallback',
      );

      final resolver = InnerTubeStreamResolver(
        client: _FakeInnerTubeClient(shouldFail: true),
        fallbackResolver: _FakeFallbackResolver(streamInfo: fallbackStream),
      );

      final result = await resolver.resolveStream(testSong);

      expect(result, isNotNull);
      expect(result!.url, equals('https://fallback.example.com/audio.mp4'));
      expect(result.streamProvenance, equals('fake_fallback'));
    });

    test('returns null when all resolvers fail', () async {
      final resolver = InnerTubeStreamResolver(
        client: _FakeInnerTubeClient(shouldFail: true),
        fallbackResolver: _FakeFallbackResolver(streamInfo: null),
      );

      final result = await resolver.resolveStream(testSong);
      expect(result, isNull);
    });
  });
}
