import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/audio_focus_orchestrator_service.dart';
import 'package:prism_music/core/services/audio_player_service.dart';
import 'package:prism_music/core/services/download_service.dart';
import 'package:prism_music/core/services/media_resolver_service.dart';
import 'package:prism_music/core/services/playback_reliability_service.dart';
import 'package:prism_music/core/services/stream_loader_service.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/domain/repositories/repositories.dart';
import 'package:prism_music/presentation/blocs/player/player_bloc.dart';
import 'package:prism_music/presentation/blocs/player/player_event.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';

import '../helpers/fakes.dart';

class _FakeMusicRepository implements MusicRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLibraryRepository implements LibraryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAudioPlayerService implements AudioPlayerService {
  final _posCtrl = StreamController<Duration>.broadcast();
  final _bufCtrl = StreamController<Duration>.broadcast();
  final _durCtrl = StreamController<Duration?>.broadcast();
  final _playCtrl = StreamController<bool>.broadcast();
  final _bufferingCtrl = StreamController<bool>.broadcast();
  final _compCtrl = StreamController<bool>.broadcast();
  final _errCtrl = StreamController<String>.broadcast();
  final _idxCtrl = StreamController<int?>.broadcast();

  bool isPlaying = false;
  int playCalls = 0;
  int pauseCalls = 0;

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
  bool get playing => isPlaying;

  @override
  Future<void> play() async {
    playCalls++;
    isPlaying = true;
    _playCtrl.add(true);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    isPlaying = false;
    _playCtrl.add(false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> dispose() async {
    _posCtrl.close();
    _bufCtrl.close();
    _durCtrl.close();
    _playCtrl.close();
    _bufferingCtrl.close();
    _compCtrl.close();
    _errCtrl.close();
    _idxCtrl.close();
  }
}

class _FakeAudioFocus implements AudioFocusOrchestratorService {
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> activateForPlayback() async => true;
  @override
  Future<void> deactivate() async {}
  @override
  void notifyUserPaused(bool paused) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMediaResolver implements MediaResolverService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePlaybackReliability implements PlaybackReliabilityService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStreamLoader implements StreamLoaderService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDownloadService implements DownloadService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAudioPlayerService fakeAudio;
  late PlayerBloc bloc;

  setUp(() async {
    initTestHive('player_bloc_restore_test');
    await SettingsService.instance.initialize();
    fakeAudio = _FakeAudioPlayerService();
    bloc = PlayerBloc(
      musicRepository: _FakeMusicRepository(),
      libraryRepository: _FakeLibraryRepository(),
      audioPlayerService: fakeAudio,
      audioFocus: _FakeAudioFocus(),
      mediaResolver: _FakeMediaResolver(),
      reliability: _FakePlaybackReliability(),
      streamLoader: _FakeStreamLoader(),
      downloadService: _FakeDownloadService(),
    );
  });

  tearDown(() async {
    await bloc.close();
    await fakeAudio.dispose();
  });

  const song1 = Song(
    id: 's1',
    title: 'Comfortably Numb',
    artist: 'Pink Floyd',
    duration: Duration(seconds: 380),
    thumbnails: Thumbnails(),
  );

  const song2 = Song(
    id: 's2',
    title: 'Wish You Were Here',
    artist: 'Pink Floyd',
    duration: Duration(seconds: 334),
    thumbnails: Thumbnails(),
  );

  test('RestoreQueueEvent restores queue in paused state without surprise auto-play', () async {
    bloc.add(
      const RestoreQueueEvent(
        currentSong: song1,
        queue: [song1, song2],
        queueIndex: 0,
        position: Duration(seconds: 120),
        autoPlay: false,
      ),
    );

    await expectLater(
      bloc.stream,
      emits(
        predicate<PlayerState>((s) {
          return s.status == PlayerStatus.paused &&
              !s.isPlaying &&
              s.isRestoredSession &&
              s.currentSong?.id == 's1' &&
              s.queue.length == 2 &&
              s.position == const Duration(seconds: 120);
        }),
      ),
    );

    // Verify audio player play() was NOT called
    expect(fakeAudio.playCalls, 0);
  });

  test('ClearPersistedQueueEvent resets restored session flag', () async {
    bloc.add(
      const RestoreQueueEvent(
        currentSong: song1,
        queue: [song1],
        queueIndex: 0,
        position: Duration.zero,
        autoPlay: false,
      ),
    );

    await expectLater(
      bloc.stream,
      emits(
        predicate<PlayerState>((s) => s.isRestoredSession),
      ),
    );

    bloc.add(const ClearPersistedQueueEvent());

    await expectLater(
      bloc.stream,
      emits(
        predicate<PlayerState>((s) => !s.isRestoredSession),
      ),
    );
    // Allow any pending async persistence cleanup to finish before tearing down
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
}
