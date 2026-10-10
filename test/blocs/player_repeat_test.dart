import 'dart:async';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:prism_music/core/error/failures.dart';
import 'package:prism_music/core/services/audio_focus_orchestrator_service.dart';
import 'package:prism_music/core/services/audio_player_service.dart';
import 'package:prism_music/core/services/download_service.dart';
import 'package:prism_music/core/services/media_resolver_service.dart';
import 'package:prism_music/core/services/playback_reliability_service.dart';
import 'package:prism_music/core/services/stream_loader_service.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/domain/repositories/repositories.dart';
import 'package:prism_music/presentation/blocs/player/player_bloc.dart';
import 'package:prism_music/presentation/blocs/player/player_event.dart';

import '../helpers/fakes.dart';

class _FakeAudioPlayerService implements AudioPlayerService {
  final _posCtrl = StreamController<Duration>.broadcast();
  final _bufCtrl = StreamController<Duration>.broadcast();
  final _durCtrl = StreamController<Duration?>.broadcast();
  final _playCtrl = StreamController<bool>.broadcast();
  final _bufferingCtrl = StreamController<bool>.broadcast();
  final _compCtrl = StreamController<bool>.broadcast();
  final _errCtrl = StreamController<String>.broadcast();
  final _idxCtrl = StreamController<int?>.broadcast();

  int playCallCount = 0;

  @override
  Stream<Duration> get positionStream => _posCtrl.stream;
  @override
  Stream<Duration> get bufferedPositionStream => _bufCtrl.stream;
  @override
  Stream<Duration?> get durationStream => _durCtrl.stream;
  @override
  Stream<bool> get playingStream => _playCtrl.stream;
  @override
  Stream<bool> get bufferingStream => _bufferingCtrl.stream;
  @override
  Stream<bool> get completedStream => _compCtrl.stream;
  @override
  Stream<String> get errorStream => _errCtrl.stream;
  @override
  Stream<int?> get currentIndexStream => _idxCtrl.stream;

  @override
  bool get playing => false;
  @override
  bool get isQueueMode => false;

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
    return const Duration(seconds: 180);
  }

  @override
  Future<void> play() async {
    playCallCount++;
    _playCtrl.add(true);
  }

  @override
  Future<void> pause() async {
    _playCtrl.add(false);
  }

  @override
  Future<void> stop() async {
    _playCtrl.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    _posCtrl.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> dispose() async {
    await _posCtrl.close();
    await _bufCtrl.close();
    await _durCtrl.close();
    await _playCtrl.close();
    await _bufferingCtrl.close();
    await _compCtrl.close();
    await _errCtrl.close();
    await _idxCtrl.close();
  }

  void completeTrack() {
    _compCtrl.add(true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMediaResolverService implements MediaResolverService {
  @override
  Future<ResolvedMediaSource> resolveForPlayback(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    return ResolvedMediaSource(
      uri: 'https://example.com/audio/${song.id}.mp4',
      streamInfo: StreamInfo(
        url: 'https://example.com/audio/${song.id}.mp4',
        quality: preferredQuality,
        codec: 'mp4a',
        container: 'mp4',
        bitrate: 320,
        isAudioOnly: true,
      ),
      isOffline: false,
      videoId: song.playableId,
    );
  }

  @override
  ResolvedMediaSource? takePreResolved(String videoId) => null;
  @override
  void invalidate(String videoId) {}
  @override
  void preResolveSong(Song song, {AudioQuality preferredQuality = AudioQuality.high}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLibraryRepository implements LibraryRepository {
  @override
  Future<Either<Failure, void>> addToHistory(Song song) async => const Right(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAudioFocusOrchestratorService implements AudioFocusOrchestratorService {
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> activateForPlayback() async => true;
  @override
  Future<void> keepAlive() async {}
  @override
  Future<void> deactivate() async {}
  @override
  void notifyUserPaused(bool paused) {}
  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDownloadService implements DownloadService {
  @override
  bool isDownloaded(String songId) => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStreamLoaderService implements StreamLoaderService {
  @override
  void prefetch(Song song, {AudioQuality preferredQuality = AudioQuality.high}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAudioPlayerService fakePlayer;
  late _FakeMediaResolverService fakeResolver;
  late PlayerBloc bloc;

  Song createSong(String id, String title) => Song(
        id: id,
        title: title,
        artist: 'Artist',
        thumbnails: const Thumbnails(),
        duration: const Duration(seconds: 180),
      );

  final testSongs = [
    createSong('s1', 'Song 1'),
    createSong('s2', 'Song 2'),
    createSong('s3', 'Song 3'),
  ];

  setUpAll(() async {
    final dir = Directory('./test_hive_repeat');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    Hive.init(dir.path);
    await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      final dir = Directory('./test_hive_repeat');
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() async {
    fakePlayer = _FakeAudioPlayerService();
    fakeResolver = _FakeMediaResolverService();

    bloc = PlayerBloc(
      musicRepository: FakeMusicRepository(),
      libraryRepository: _FakeLibraryRepository(),
      audioPlayerService: fakePlayer,
      audioFocus: _FakeAudioFocusOrchestratorService(),
      mediaResolver: fakeResolver,
      reliability: PlaybackReliabilityService(),
      streamLoader: _FakeStreamLoaderService(),
      downloadService: _FakeDownloadService(),
    );
  });

  tearDown(() async {
    await bloc.close();
    await fakePlayer.dispose();
  });

  test('CycleRepeatModeEvent cycles off -> all -> one -> off', () async {
    expect(bloc.state.repeatMode, RepeatMode.off);

    bloc.add(const CycleRepeatModeEvent());
    await pumpEventQueue();
    expect(bloc.state.repeatMode, RepeatMode.all);

    bloc.add(const CycleRepeatModeEvent());
    await pumpEventQueue();
    expect(bloc.state.repeatMode, RepeatMode.one);

    bloc.add(const CycleRepeatModeEvent());
    await pumpEventQueue();
    expect(bloc.state.repeatMode, RepeatMode.off);
  });

  test('canSkipNext and canSkipPrevious allow looping when RepeatMode.all is active', () async {
    // Start playback on song 0
    bloc.add(PlaySongEvent(song: testSongs[0], queue: testSongs, queueIndex: 0));
    await pumpEventQueue();

    // In RepeatMode.off, previous is false at index 0
    expect(bloc.state.hasPrevious, isFalse);
    expect(bloc.state.canSkipPrevious, isFalse);
    expect(bloc.state.canSkipNext, isTrue);

    // Turn on RepeatMode.all
    bloc.add(const SetRepeatModeEvent(RepeatMode.all));
    await pumpEventQueue();
    expect(bloc.state.canSkipPrevious, isTrue);
    expect(bloc.state.canSkipNext, isTrue);

    // Skip to last song
    bloc.add(PlaySongEvent(song: testSongs[2], queue: testSongs, queueIndex: 2));
    await pumpEventQueue();
    expect(bloc.state.hasNext, isFalse);
    expect(bloc.state.canSkipNext, isTrue); // Enabled because RepeatMode.all loops
  });

  test('RepeatMode.one replays current track on track completion', () async {
    bloc.add(PlaySongEvent(song: testSongs[1], queue: testSongs, queueIndex: 1));
    await pumpEventQueue();
    expect(bloc.state.currentSong?.id, 's2');
    expect(bloc.state.queueIndex, 1);

    bloc.add(const SetRepeatModeEvent(RepeatMode.one));
    await pumpEventQueue();

    final initialPlayCount = fakePlayer.playCallCount;

    // Trigger track completion
    fakePlayer.completeTrack();
    await pumpEventQueue();

    // Verify still on s2 and playback was re-requested
    expect(bloc.state.queueIndex, 1);
    expect(bloc.state.currentSong?.id, 's2');
    expect(fakePlayer.playCallCount, greaterThan(initialPlayCount));
  });

  test('RepeatMode.all loops back to first song when last song completes', () async {
    bloc.add(PlaySongEvent(song: testSongs[2], queue: testSongs, queueIndex: 2));
    await pumpEventQueue();
    expect(bloc.state.queueIndex, 2);

    bloc.add(const SetRepeatModeEvent(RepeatMode.all));
    await pumpEventQueue();

    // Trigger track completion on the last track
    fakePlayer.completeTrack();
    await pumpEventQueue();

    // Verify wrapped around to index 0 (s1)
    expect(bloc.state.queueIndex, 0);
    expect(bloc.state.currentSong?.id, 's1');
  });
}
