import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/playback_reliability_service.dart';
import 'package:prism_music/presentation/blocs/player/player_bloc.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';

import '../helpers/fakes.dart';

/// A player running in queue mode whose current-index stream the test drives
/// by hand, standing in for the native queue advancing on its own.
class _QueueModePlayer extends FakeAudioPlayerService {
  final _indexCtrl = StreamController<int?>.broadcast();

  @override
  bool get isQueueMode => true;

  @override
  Stream<int?> get currentIndexStream => _indexCtrl.stream;

  void emitIndex(int? index) => _indexCtrl.add(index);
}

/// Records which songs had their cached stream dropped, so the tests can
/// prove a recovery re-resolves instead of reusing the stuck stream.
class _RecordingMediaResolver extends FakeMediaResolver {
  final List<String> invalidated = [];

  @override
  void invalidate(String songId) => invalidated.add(songId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ensureWidgetTestHive();
  });

  late _QueueModePlayer player;
  late _RecordingMediaResolver resolver;
  late PlayerBloc bloc;

  final queue = [
    song('a', 'Song A'),
    song('b', 'Song B'),
    song('c', 'Song C'),
  ];

  setUp(() {
    player = _QueueModePlayer()..isPlayingFlag = true;
    resolver = _RecordingMediaResolver();
    bloc = PlayerBloc(
      musicRepository: FakeMusicRepository(),
      libraryRepository: FakeLibraryRepository(),
      audioPlayerService: player,
      audioFocus: FakeAudioFocusOrchestrator(),
      mediaResolver: resolver,
      reliability: PlaybackReliabilityService(),
      streamLoader: FakeStreamLoader(),
      downloadService: FakeDownloadService(),
      // Far shorter than the real 15s so the tests stay quick, but wide
      // enough that a slow step on a loaded CI runner (cold code, GC) between
      // emitting an index and the test's next action cannot trip it early.
      trackStartWatchdogTimeout: const Duration(milliseconds: 600),
    );
    // "Song A" is playing normally at the head of the queue.
    bloc.emit(
      bloc.state.copyWith(
        currentSong: queue[0],
        queue: queue,
        queueIndex: 0,
        status: PlayerStatus.playing,
        position: const Duration(seconds: 42),
      ),
    );
  });

  tearDown(() async {
    await bloc.close();
  });

  // For the "nothing should happen" cases: comfortably longer than the 600ms
  // watchdog above, so a wrongly-armed timer would certainly have fired.
  Future<void> waitPastWatchdog() async {
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await pumpEventQueue();
  }

  group('PlayerBloc track-start watchdog', () {
    test('recovers a native auto-advance that never starts playing', () async {
      player.emitIndex(1); // the native queue moves on to "Song B"...
      await pumpEventQueue();
      expect(bloc.state.currentSong?.id, 'b');
      expect(bloc.state.queueIndex, 1);
      expect(bloc.state.position, Duration.zero);

      // ...but no audio ever arrives: the position never leaves zero. Poll
      // for the recovery rather than sleeping a fixed time, so the check
      // cannot race the retry that follows it.
      await waitFor(() => bloc.state.status == PlayerStatus.loading);

      // The stall goes through the normal playback-error policy: the stuck
      // stream is dropped from the cache and playback is retried, instead of
      // the player staying silent forever.
      expect(bloc.state.errorMessage, 'Retrying playback...');
      expect(bloc.state.currentSong?.id, 'b');
      expect(resolver.invalidated, contains('b'));
    });

    test('leaves a track that is making progress alone', () async {
      player.emitIndex(1);
      await pumpEventQueue();

      // Audio flows: the position moves well past the start threshold.
      bloc.emit(bloc.state.copyWith(position: const Duration(seconds: 3)));

      await waitPastWatchdog();

      expect(bloc.state.status, PlayerStatus.playing);
      expect(bloc.state.errorMessage, isNull);
      expect(resolver.invalidated, isEmpty);
    });

    test('does not treat a paused player as stalled', () async {
      player.emitIndex(1);
      await pumpEventQueue();

      player.isPlayingFlag = false; // the user paused right after the skip

      await waitPastWatchdog();

      expect(bloc.state.status, isNot(PlayerStatus.loading));
      expect(bloc.state.errorMessage, isNull);
      expect(resolver.invalidated, isEmpty);
    });

    test('is not armed when the reported index did not change', () async {
      // Right after a queue load the player re-reports the index it is on.
      bloc.emit(bloc.state.copyWith(position: Duration.zero));
      player.emitIndex(0);

      await waitPastWatchdog();

      expect(bloc.state.status, PlayerStatus.playing);
      expect(bloc.state.errorMessage, isNull);
      expect(resolver.invalidated, isEmpty);
    });

    test('a stale watchdog never acts on the track that replaced it', () async {
      player.emitIndex(1);
      await pumpEventQueue();
      player.emitIndex(2); // skipped again before "Song B" ever started
      await pumpEventQueue();
      expect(bloc.state.currentSong?.id, 'c');

      // "Song C", unlike "Song B", is making progress.
      bloc.emit(bloc.state.copyWith(position: const Duration(seconds: 3)));

      await waitPastWatchdog();

      expect(bloc.state.status, PlayerStatus.playing);
      expect(bloc.state.currentSong?.id, 'c');
      expect(bloc.state.errorMessage, isNull);
      expect(resolver.invalidated, isEmpty);
    });
  });
}
