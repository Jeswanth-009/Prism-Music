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
import 'package:prism_music/presentation/blocs/player/player_state.dart';

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

  int pauseCallCount = 0;
  bool _isPlaying = true;
  final bool _isQueueMode = true;

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
  bool get playing => _isPlaying;
  @override
  bool get isQueueMode => _isQueueMode;

  @override
  Future<void> pause() async {
    pauseCallCount++;
    _isPlaying = false;
  }

  @override
  Future<void> play() async {
    _isPlaying = true;
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMediaResolverService implements MediaResolverService {
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
  ];

  setUpAll(() async {
    final dir = Directory('./test_hive_sleep_timer');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    Hive.init(dir.path);
    await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      final dir = Directory('./test_hive_sleep_timer');
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() {
    fakePlayer = _FakeAudioPlayerService();
    bloc = PlayerBloc(
      audioPlayerService: fakePlayer,
      musicRepository: FakeMusicRepository(),
      mediaResolver: _FakeMediaResolverService(),
      libraryRepository: _FakeLibraryRepository(),
      audioFocus: _FakeAudioFocusOrchestratorService(),
      downloadService: _FakeDownloadService(),
      streamLoader: _FakeStreamLoaderService(),
      reliability: PlaybackReliabilityService(),
    );
  });

  tearDown(() async {
    await bloc.close();
  });

  test('SetSleepTimerEvent with endOfTrack sets sleepTimerEndOfTrack to true', () async {
    bloc.add(const SetSleepTimerEvent(null, endOfTrack: true));
    await pumpEventQueue();

    expect(bloc.state.sleepTimerEndOfTrack, isTrue);
    expect(bloc.state.sleepTimerEnd, isNull);
  });

  test('End-of-track sleep timer pauses player on track completion stream', () async {
    bloc.emit(bloc.state.copyWith(
      currentSong: testSongs[0],
      queue: testSongs,
      queueIndex: 0,
      status: PlayerStatus.playing,
      sleepTimerEndOfTrack: true,
    ));

    fakePlayer._compCtrl.add(true);
    await pumpEventQueue();

    expect(fakePlayer.pauseCallCount, greaterThanOrEqualTo(1));
    expect(bloc.state.sleepTimerEndOfTrack, isFalse);
    expect(bloc.state.status, PlayerStatus.paused);
  });

  test('End-of-track sleep timer pauses player when queue auto-advances in background', () async {
    bloc.emit(bloc.state.copyWith(
      currentSong: testSongs[0],
      queue: testSongs,
      queueIndex: 0,
      status: PlayerStatus.playing,
      sleepTimerEndOfTrack: true,
    ));

    // Player automatically advances to index 1 in queue
    fakePlayer._idxCtrl.add(1);
    await pumpEventQueue();

    expect(fakePlayer.pauseCallCount, greaterThanOrEqualTo(1));
    expect(bloc.state.sleepTimerEndOfTrack, isFalse);
    expect(bloc.state.status, PlayerStatus.paused);
  });

  test('End-of-track sleep timer triggers when position reaches track duration', () async {
    bloc.emit(bloc.state.copyWith(
      currentSong: testSongs[0],
      queue: testSongs,
      queueIndex: 0,
      duration: const Duration(seconds: 180),
      status: PlayerStatus.playing,
      sleepTimerEndOfTrack: true,
    ));

    fakePlayer._posCtrl.add(const Duration(seconds: 180));
    await pumpEventQueue();

    expect(fakePlayer.pauseCallCount, greaterThanOrEqualTo(1));
    expect(bloc.state.sleepTimerEndOfTrack, isFalse);
    expect(bloc.state.status, PlayerStatus.paused);
  });

  test('Cancelling sleep timer clears sleepTimerEndOfTrack', () async {
    bloc.add(const SetSleepTimerEvent(null, endOfTrack: true));
    await pumpEventQueue();
    expect(bloc.state.sleepTimerEndOfTrack, isTrue);

    bloc.add(const SetSleepTimerEvent(null, endOfTrack: false));
    await pumpEventQueue();
    expect(bloc.state.sleepTimerEndOfTrack, isFalse);
  });
}
