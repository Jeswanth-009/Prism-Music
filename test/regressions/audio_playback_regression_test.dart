import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:just_audio/just_audio.dart';
import 'package:prism_music/core/services/audio_player_service.dart';
import 'package:prism_music/core/services/media_resolver_service.dart';
import 'package:prism_music/core/services/playback_reliability_service.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/core/services/stream_cache_service.dart';
import 'package:prism_music/core/services/stream_loader_service.dart';
import 'package:prism_music/core/services/youtube_audio_source.dart';
import 'package:prism_music/core/providers/audio_stream_resolver.dart';
import 'package:prism_music/data/datasources/remote/youtube/youtube_music_datasource.dart';
import 'package:prism_music/domain/entities/song.dart';
import 'package:prism_music/domain/entities/stream_info.dart';
import 'package:prism_music/presentation/blocs/player/player_bloc.dart';
import 'package:prism_music/presentation/blocs/player/player_event.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';

import '../helpers/fakes.dart';

class _MockJustAudioPlatform extends JustAudioPlatform {
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    return _MockAudioPlayerPlatform(request.id);
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) async {
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(DisposeAllPlayersRequest request) async {
    return DisposeAllPlayersResponse();
  }
}

class _MockAudioPlayerPlatform extends AudioPlayerPlatform {
  final _eventController = StreamController<PlaybackEventMessage>.broadcast();

  _MockAudioPlayerPlatform(super.id);

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _eventController.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    _eventController.add(
      PlaybackEventMessage(
        processingState: ProcessingStateMessage.ready,
        updatePosition: Duration.zero,
        updateTime: DateTime.now(),
        bufferedPosition: const Duration(seconds: 180),
        duration: const Duration(seconds: 180),
        currentIndex: 0,
        androidAudioSessionId: 1,
        icyMetadata: null,
      ),
    );
    return LoadResponse(duration: const Duration(seconds: 180));
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async => PlayResponse();

  @override
  Future<PauseResponse> pause(PauseRequest request) async => PauseResponse();

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async => SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async => SetSpeedResponse();

  @override
  Future<SeekResponse> seek(SeekRequest request) async => SeekResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async => SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(SetShuffleModeRequest request) async => SetShuffleModeResponse();

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async => SetPitchResponse();

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(SetSkipSilenceRequest request) async => SetSkipSilenceResponse();

  @override
  Future<ConcatenatingInsertAllResponse> concatenatingInsertAll(
    ConcatenatingInsertAllRequest request,
  ) async => ConcatenatingInsertAllResponse();

  @override
  Future<ConcatenatingRemoveRangeResponse> concatenatingRemoveRange(
    ConcatenatingRemoveRangeRequest request,
  ) async => ConcatenatingRemoveRangeResponse();

  @override
  Future<ConcatenatingMoveResponse> concatenatingMove(
    ConcatenatingMoveRequest request,
  ) async => ConcatenatingMoveResponse();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    JustAudioPlatform.instance = _MockJustAudioPlatform();
  });

  group('Regression Test (3): loadQueue with local paths vs YouTube', () {
    test('loadQueue with local paths builds UriAudioSource, not YouTubeAudioSource', () async {
      final playerService = AudioPlayerService();

      final queuePayload = <Map<String, dynamic>>[
        {
          'videoId': 'local_track_1',
          'url': '/storage/emulated/0/Music/Prism/track1.m4a',
          'title': 'Local Download 1',
          'artist': 'Offline Artist 1',
        },
        {
          'videoId': 'local_track_2',
          'url': 'file:///sdcard/Music/track2.mp3',
          'title': 'Local Download 2',
          'artist': 'Offline Artist 2',
        },
        {
          'videoId': 'local_track_3',
          'url': r'C:\Users\Music\track3.flac',
          'title': 'Windows Local Download 3',
          'artist': 'Offline Artist 3',
        },
        {
          'videoId': 'dQw4w9WgXcQ',
          'url': null,
          'title': 'Cloud Track 4',
          'artist': 'Online Artist 4',
        },
      ];

      final duration = await playerService.loadQueue(queuePayload, initialIndex: 0);
      expect(duration, isNotNull);
      expect(playerService.queueSourcesLength, 4);

      final sources = playerService.queueSources;

      // 1. Unix absolute path -> UriAudioSource (not YouTubeAudioSource)
      expect(sources[0], isA<UriAudioSource>());
      expect(sources[0], isNot(isA<YouTubeAudioSource>()));

      // 2. file:// URI -> UriAudioSource (not YouTubeAudioSource)
      expect(sources[1], isA<UriAudioSource>());
      expect(sources[1], isNot(isA<YouTubeAudioSource>()));

      // 3. Windows local drive path -> UriAudioSource (not YouTubeAudioSource)
      expect(sources[2], isA<UriAudioSource>());
      expect(sources[2], isNot(isA<YouTubeAudioSource>()));

      // 4. Remote YouTube track -> YouTubeAudioSource
      expect(sources[3], isA<YouTubeAudioSource>());
    });

    test('loadQueue preserves unresolved non-YouTube tracks via DeferredStreamAudioSource and setUrl supports late appends', () async {
      final playerService = AudioPlayerService();
      playerService.configureQueueResolvers(
        deferredResolver: (id, title, artist, quality) async =>
            ResolvedMediaSource(
          uri: 'https://cdn.example/$id.m4a',
          isOffline: false,
          videoId: id,
        ),
      );

      final queuePayload = <Map<String, dynamic>>[
        {
          'videoId': 'jiosaavn_track_1',
          'url': '',
          'title': 'Saavn Track 1',
          'artist': 'Artist',
          'durationMs': 185000,
        },
        {
          'videoId': 'dQw4w9WgXcQ',
          'url': null,
          'title': 'YouTube Track 2',
          'artist': 'Artist 2',
        },
      ];

      final duration = await playerService.loadQueue(queuePayload, initialIndex: 0);
      expect(duration, isNotNull);
      expect(playerService.queueSourcesLength, 2);
      expect(playerService.queueSources[0], isA<DeferredStreamAudioSource>());
      expect(playerService.queueSources[1], isA<YouTubeAudioSource>());

      // Single-song setUrl also enters queue mode so late recommendations append seamlessly.
      await playerService.setUrl(
        'https://cdn.example/single.m4a',
        videoId: 'single_1',
        mediaDuration: const Duration(seconds: 200),
      );
      expect(playerService.isQueueMode, isTrue);
      await playerService.appendToQueue([
        {
          'videoId': 'rec_next_1',
          'url': '',
          'title': 'Late Recommendation',
          'artist': 'Artist',
        },
      ]);
      expect(playerService.queueSourcesLength, 2);
    });
  });

  group('Regression Test (2): _onAddRecommendations native queue sync', () {
    late PlayerBloc playerBloc;
    late FakeAudioPlayerService fakeAudio;

    setUp(() async {
      initTestHive('rec_sync');
      await SettingsService.instance.initialize();
      fakeAudio = FakeAudioPlayerService()..queueModeFlag = true;
      playerBloc = buildTestPlayerBloc(audioPlayerService: fakeAudio);
    });

    tearDown(() async {
      await playerBloc.close();
    });

    test('AddRecommendationsEvent keeps native queue in sync with BLoC queue', () async {
      final initial1 = song('init_1', 'Initial Track 1');
      final initial2 = song('init_2', 'Initial Track 2');

      playerBloc.add(PlaySongEvent(
        song: initial1,
        queue: [initial1, initial2],
        queueIndex: 0,
      ));
      await waitFor(() => playerBloc.state.queue.length == 2);

      expect(playerBloc.state.queue.length, 2);

      // Now add 3 recommendations
      final rec1 = song('rec_1', 'Recommended Track 1');
      final rec2 = song('rec_2', 'Recommended Track 2');
      final rec3 = song('rec_3', 'Recommended Track 3');

      playerBloc.add(AddRecommendationsEvent([rec1, rec2, rec3]));
      await waitFor(() => playerBloc.state.queue.length == 5);

      // Verify BLoC queue contains all 5 tracks
      expect(playerBloc.state.queue.map((s) => s.id), [
        'init_1',
        'init_2',
        'rec_1',
        'rec_2',
        'rec_3',
      ]);

      // Verify native queue received appendToQueue payload with all 3 items
      expect(fakeAudio.appendedQueuePayloads.length, 3);
      expect(fakeAudio.appendedQueuePayloads[0]['title'], 'Recommended Track 1');
      expect(fakeAudio.appendedQueuePayloads[1]['title'], 'Recommended Track 2');
      expect(fakeAudio.appendedQueuePayloads[2]['title'], 'Recommended Track 3');
      expect(fakeAudio.appendedQueuePayloads[0]['videoId'], 'rec_1');
    });
  });

  group('Regression Test (1): Offline queue plays end-to-end', () {
    late PlayerBloc playerBloc;
    late FakeAudioPlayerService fakeAudio;
    late FakeDownloadService fakeDownloads;

    setUp(() async {
      initTestHive('offline_e2e');
      await SettingsService.instance.initialize();
      fakeAudio = FakeAudioPlayerService();
      fakeDownloads = FakeDownloadService(
        downloadedIds: {'down_1', 'down_2', 'down_3'},
        downloadedSongs: [
          song('down_1', 'Downloaded 1'),
          song('down_2', 'Downloaded 2'),
          song('down_3', 'Downloaded 3'),
        ],
      );
      playerBloc = buildTestPlayerBloc(
        audioPlayerService: fakeAudio,
        downloadService: fakeDownloads,
      );
    });

    tearDown(() async {
      await playerBloc.close();
    });

    test('offline queue of downloaded songs plays end-to-end using local paths', () async {
      final s1 = song('down_1', 'Downloaded 1');
      final s2 = song('down_2', 'Downloaded 2');
      final s3 = song('down_3', 'Downloaded 3');

      playerBloc.add(PlaySongEvent(
        song: s1,
        queue: [s1, s2, s3],
        queueIndex: 0,
      ));
      await waitFor(() => playerBloc.state.currentSong?.id == 'down_1' && playerBloc.state.isPlaying);

      expect(playerBloc.state.currentSong?.id, 'down_1');
      expect(playerBloc.state.isPlaying, isTrue);

      // Verify loaded queue uses local paths for all songs
      expect(fakeAudio.loadedQueueSongs.length, 3);
      expect(fakeAudio.loadedQueueSongs[0]['url'], '/tmp/downloads/down_1.m4a');
      expect(fakeAudio.loadedQueueSongs[1]['url'], '/tmp/downloads/down_2.m4a');
      expect(fakeAudio.loadedQueueSongs[2]['url'], '/tmp/downloads/down_3.m4a');

      // Skip next to down_2
      playerBloc.add(const NextEvent());
      await waitFor(() => playerBloc.state.currentSong?.id == 'down_2');

      expect(playerBloc.state.currentSong?.id, 'down_2');
      expect(playerBloc.state.isPlaying, isTrue);
    });
  });

  group('Regression Test (4): Next-track auto-advance latency', () {
    late PlayerBloc playerBloc;
    late FakeAudioPlayerService fakeAudio;

    setUp(() async {
      initTestHive('advance_latency');
      await SettingsService.instance.initialize();
      fakeAudio = FakeAudioPlayerService();
      playerBloc = buildTestPlayerBloc(audioPlayerService: fakeAudio);
    });

    tearDown(() async {
      await playerBloc.close();
    });

    test('next-track auto-advance syncs state within tight latency bound', () async {
      final s1 = song('track_1', 'Track 1');
      final s2 = song('track_2', 'Track 2');

      playerBloc.add(PlaySongEvent(
        song: s1,
        queue: [s1, s2],
        queueIndex: 0,
      ));
      await waitFor(() => playerBloc.state.currentSong?.id == 'track_1');

      // Simulate native audio player auto-advancing to index 1
      final stopwatch = Stopwatch()..start();
      fakeAudio.seekToNext();

      await waitFor(() => playerBloc.state.currentSong?.id == 'track_2');
      stopwatch.stop();

      expect(playerBloc.state.queueIndex, 1);
      expect(playerBloc.state.currentSong?.id, 'track_2');
      // Auto-advance state sync should occur well under 300ms
      expect(stopwatch.elapsedMilliseconds, lessThan(300));
    });
  });

  group('Regression Test (5): PlayerBloc failover on primary stream playback error', () {
    late PlayerBloc playerBloc;
    late _FailingFirstAudioPlayerService failingAudio;
    late StreamLoaderService streamLoader;
    late MediaResolverService mediaResolver;

    setUp(() async {
      initTestHive('failover_test');
      await SettingsService.instance.initialize();
      failingAudio = _FailingFirstAudioPlayerService();
      final cache = StreamCacheService();
      final reliability = PlaybackReliabilityService();
      streamLoader = StreamLoaderService(
        _NoopYouTubeDataSource(),
        cache,
        reliability: reliability,
        resolvers: [
          _StaticResolver(
            'jiosaavn',
            const StreamInfo(
              url: 'https://jio.broken/track.mp4',
              codec: 'mp4a',
              bitrate: 320,
              container: 'mp4',
              quality: AudioQuality.high,
              streamProvenance: 'jiosaavn_matched',
              matchConfidence: 0.90,
            ),
          ),
          _StaticResolver(
            'innertube_ladder',
            const StreamInfo(
              url: 'https://innertube.healthy/track.mp4',
              codec: 'mp4a',
              bitrate: 128,
              container: 'mp4',
              quality: AudioQuality.high,
              streamProvenance: 'innertube_android',
              matchConfidence: 1.0,
            ),
          ),
        ],
      );
      mediaResolver = MediaResolverService(
        streamLoader: streamLoader,
        downloadService: FakeDownloadService(),
      );
      playerBloc = PlayerBloc(
        musicRepository: FakeMusicRepository(),
        libraryRepository: FakeLibraryRepository(),
        audioPlayerService: failingAudio,
        audioFocus: FakeAudioFocusOrchestrator(),
        mediaResolver: mediaResolver,
        reliability: reliability,
        streamLoader: streamLoader,
        downloadService: FakeDownloadService(),
      );
    });

    tearDown(() async {
      await playerBloc.close();
    });

    test('switches from failing JioSaavn playback to InnerTube instead of tripping circuit breaker', () async {
      final track = const Song(
        id: '1F3hm6MfR1k',
        youtubeId: '1F3hm6MfR1k',
        title: 'Hukum',
        artist: 'Anirudh Ravichander',
        duration: Duration(seconds: 207),
        thumbnails: Thumbnails(),
        source: MusicSource.youtube,
      );

      playerBloc.add(PlaySongEvent(song: track, queue: [track], queueIndex: 0));
      await waitFor(
        () =>
            playerBloc.state.currentStreamInfo?.streamProvenance == 'innertube_android' &&
            playerBloc.state.isPlaying,
      );

      expect(playerBloc.state.currentStreamInfo?.streamProvenance, 'innertube_android');
      expect(playerBloc.state.status, PlayerStatus.playing);
      expect(failingAudio.urlsTried.first, contains('jio.broken'));
      expect(failingAudio.urlsTried.last, contains('innertube.healthy'));
    });
  });
}

class _NoopYouTubeDataSource implements YouTubeMusicDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StaticResolver implements AudioStreamResolver {
  @override
  final String resolverName;
  final StreamInfo info;

  _StaticResolver(this.resolverName, this.info);

  @override
  bool get isAvailable => true;

  @override
  Future<StreamInfo?> resolveStream(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async =>
      info;
}

class _FailingFirstAudioPlayerService extends FakeAudioPlayerService {
  final List<String> urlsTried = [];

  @override
  Future<Duration?> setUrl(
    String url, {
    Map<String, String>? headers,
    String? videoId,
    String quality = 'high',
    String? title,
    String? artist,
    String? album,
    String? artworkUrl,
    Duration? mediaDuration,
    bool allowYouTubeFallbackOnDirectFailure = false,
  }) async {
    urlsTried.add(url);
    return mediaDuration ?? const Duration(seconds: 200);
  }

  @override
  Future<void> play() async {
    playCalls++;
    if (urlsTried.last.contains('jio.broken')) {
      emitErrorForTest('ExoPlaybackException: Source error');
      return;
    }
    isPlayingFlag = true;
  }
}
