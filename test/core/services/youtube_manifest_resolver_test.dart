import 'dart:collection';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prism_music/core/services/youtube_manifest_resolver.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

class MockYoutubeExplode extends Mock implements yt.YoutubeExplode {}
class MockVideoClient extends Mock implements yt.VideoClient {}
class MockStreamClient extends Mock implements yt.StreamClient {}
class MockStreamManifest extends Mock implements yt.StreamManifest {}
class MockAudioOnlyStreamInfo extends Mock implements yt.AudioOnlyStreamInfo {}

void main() {
  late MockYoutubeExplode mockYt;
  late MockVideoClient mockVideoClient;
  late MockStreamClient mockStreamClient;
  late MockStreamManifest mockManifestWithAudio;
  late MockStreamManifest mockManifestEmptyAudio;

  setUpAll(() {
    registerFallbackValue(yt.YoutubeApiClient.android);
  });

  setUp(() {
    mockYt = MockYoutubeExplode();
    mockVideoClient = MockVideoClient();
    mockStreamClient = MockStreamClient();
    mockManifestWithAudio = MockStreamManifest();
    mockManifestEmptyAudio = MockStreamManifest();

    final audioInfo = MockAudioOnlyStreamInfo();
    when(() => mockManifestWithAudio.audioOnly)
        .thenReturn(UnmodifiableListView([audioInfo]));
    when(() => mockManifestEmptyAudio.audioOnly)
        .thenReturn(UnmodifiableListView(<yt.AudioOnlyStreamInfo>[]));

    when(() => mockYt.videos).thenReturn(mockVideoClient);
    when(() => mockVideoClient.streamsClient).thenReturn(mockStreamClient);
  });

  group('YouTubeManifestResolver', () {
    test('returns first manifest with audio streams', () async {
      when(() => mockStreamClient.getManifest(
            'test_vid',
            ytClients: any(named: 'ytClients'),
            requireWatchPage: false,
          )).thenAnswer((_) async => mockManifestWithAudio);

      final result = await YouTubeManifestResolver.fetchAudioManifest(
        mockYt,
        'test_vid',
      );

      expect(result, equals(mockManifestWithAudio));
      verify(() => mockStreamClient.getManifest(
            'test_vid',
            ytClients: [yt.YoutubeApiClient.androidSdkless],
            requireWatchPage: false,
          )).called(1);
    });

    test('falls back to second client when first fails', () async {
      final failures = <String>[];
      var calls = 0;

      when(() => mockStreamClient.getManifest(
            'test_vid',
            ytClients: any(named: 'ytClients'),
            requireWatchPage: false,
          )).thenAnswer((invocation) async {
        calls++;
        if (calls == 1) {
          throw Exception('androidSdkless 403');
        }
        return mockManifestWithAudio;
      });

      final result = await YouTubeManifestResolver.fetchAudioManifest(
        mockYt,
        'test_vid',
        onClientFailure: (name, err) => failures.add(name),
      );

      expect(result, equals(mockManifestWithAudio));
      expect(failures, contains('androidSdkless'));
      expect(calls, equals(2));
    });

    test('throws when all candidate clients fail', () async {
      when(() => mockStreamClient.getManifest(
            'test_vid',
            ytClients: any(named: 'ytClients'),
            requireWatchPage: false,
          )).thenThrow(Exception('All blocked'));

      expect(
        () => YouTubeManifestResolver.fetchAudioManifest(
          mockYt,
          'test_vid',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
