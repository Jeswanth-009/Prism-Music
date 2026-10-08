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

  Completer<void>? pendingPlayCompleter;
  int playCallCount = 0;
  int stopCallCount = 0;
  int pauseCallCount = 0;

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
    return const Duration(seconds: 240);
  }

  @override
  Future<void> play() async {
    playCallCount++;
    _playCtrl.add(true);
    if (pendingPlayCompleter != null) {
      await pendingPlayCompleter!.future;
    }
  }

  @override
  Future<void> pause() async {
    pauseCallCount++;
    _playCtrl.add(false);
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
    _playCtrl.add(false);
  }

  void emitNativeError(String error) {
    _errCtrl.add(error);
  }

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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLibraryRepository implements LibraryRepository {
  final List<Song> history = [];

  @override
  Future<Either<Failure, void>> addToHistory(Song song) async {
    history.add(song);
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMediaResolverService implements MediaResolverService {
  Completer<ResolvedMediaSource>? slowResolutionCompleter;

  @override
  Future<ResolvedMediaSource> resolveForPlayback(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    if (slowResolutionCompleter != null) {
      return slowResolutionCompleter!.future;
    }
    return ResolvedMediaSource(
      uri: 'https://example.com/audio.mp4',
      streamInfo: StreamInfo(
        url: 'https://example.com/audio.mp4',
        quality: AudioQuality.high,
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

class _FakeAudioFocusOrchestratorService implements AudioFocusOrchestratorService {
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> activateForPlayback() async => true;
  @override
  Future<void> deactivate() async {}
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

  late _FakeAudioPlayerService audioPlayer;
  late _FakeLibraryRepository libraryRepo;
  late _FakeMediaResolverService mediaResolver;
  late PlayerBloc bloc;

  Song createSong(String id, String title) => Song(
        id: id,
        title: title,
        artist: 'Artist',
        thumbnails: const Thumbnails(),
        duration: const Duration(seconds: 240),
      );

  setUpAll(() {
    final dir = Directory('./test_hive_concurrency');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    Hive.init(dir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      final dir = Directory('./test_hive_concurrency');
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() async {
    audioPlayer = _FakeAudioPlayerService();
    libraryRepo = _FakeLibraryRepository();
    mediaResolver = _FakeMediaResolverService();

    bloc = PlayerBloc(
      musicRepository: FakeMusicRepository(),
      libraryRepository: libraryRepo,
      audioPlayerService: audioPlayer,
      audioFocus: _FakeAudioFocusOrchestratorService(),
      mediaResolver: mediaResolver,
      reliability: PlaybackReliabilityService(),
      streamLoader: _FakeStreamLoaderService(),
      downloadService: _FakeDownloadService(),
    );
  });

  tearDown(() async {
    audioPlayer.pendingPlayCompleter?.complete();
    await bloc.close();
    await audioPlayer.dispose();
  });

  group('F01: Playback startup does not wait for entire lifetime', () {
    test('commits playing state and records history immediately even if play future is pending',
        () async {
      audioPlayer.pendingPlayCompleter = Completer<void>();
      final songA = createSong('s1', 'Song A');

      final playingFuture = bloc.stream.firstWhere(
        (s) => s.status == PlayerStatus.playing && s.currentSong?.id == 's1',
      );
      bloc.add(PlaySongEvent(song: songA));
      await playingFuture;

      expect(libraryRepo.history, contains(songA));
      expect(bloc.state.status, PlayerStatus.playing);
    });
  });

  group('F02: Stop and pause concurrency invalidation', () {
    test('dispatching stop while resolving cancels playback and stays stopped', () async {
      final slowGate = Completer<ResolvedMediaSource>();
      mediaResolver.slowResolutionCompleter = slowGate;

      final songB = createSong('s2', 'Song B');
      bloc.add(PlaySongEvent(song: songB));

      // Allow loading to start
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.status, PlayerStatus.loading);

      // User immediately clicks Stop
      bloc.add(const StopEvent());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.status, PlayerStatus.initial);

      // Now resolution finishes in the background
      slowGate.complete(
        ResolvedMediaSource(
          uri: 'https://example.com/audio.mp4',
          streamInfo: StreamInfo(
            url: 'https://example.com/audio.mp4',
            quality: AudioQuality.high,
            codec: 'mp4a',
            container: 'mp4',
            bitrate: 320,
            isAudioOnly: true,
          ),
          isOffline: false,
          videoId: songB.playableId,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Must remain stopped, NOT resurrected to playing
      expect(bloc.state.status, PlayerStatus.initial);
      expect(bloc.state.currentSong, isNull);
    });

    test('dispatching pause while resolving prevents play() from triggering', () async {
      final slowGate = Completer<ResolvedMediaSource>();
      mediaResolver.slowResolutionCompleter = slowGate;

      final songC = createSong('s3', 'Song C');
      bloc.add(PlaySongEvent(song: songC));

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.status, PlayerStatus.loading);

      // User clicks Pause while resolving
      bloc.add(const PauseEvent());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.status, PlayerStatus.paused);

      slowGate.complete(
        ResolvedMediaSource(
          uri: 'https://example.com/audio.mp4',
          streamInfo: StreamInfo(
            url: 'https://example.com/audio.mp4',
            quality: AudioQuality.high,
            codec: 'mp4a',
            container: 'mp4',
            bitrate: 320,
            isAudioOnly: true,
          ),
          isOffline: false,
          videoId: songC.playableId,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Status must not have flipped back to playing
      expect(bloc.state.status, PlayerStatus.paused);
    });
  });

  group('F03: Forwarding native playback errors', () {
    test('native errors emitted on audio player errorStream are handled', () async {
      final songD = createSong('s4', 'Song D');
      final playingFuture = bloc.stream.firstWhere((s) => s.status == PlayerStatus.playing);
      bloc.add(PlaySongEvent(song: songD));
      await playingFuture;

      final errorFuture = bloc.stream.firstWhere((s) => s.status == PlayerStatus.error);
      // Mid-stream native error occurs (fatal decoder error)
      audioPlayer.emitNativeError('Unable to decode selected audio source');
      await errorFuture;

      expect(bloc.state.errorMessage, contains('Unable to decode'));
    });
  });

  group('F08: Queue edits and shuffle identity / index coherence', () {
    test('enabling shuffle preserves current song at active pointer and saves originalQueue',
        () async {
      final s1 = createSong('1', 'One');
      final s2 = createSong('2', 'Two');
      final s3 = createSong('3', 'Three');
      final initialQueue = [s1, s2, s3];

      final playingFuture = bloc.stream.firstWhere((s) => s.status == PlayerStatus.playing);
      bloc.add(PlaySongEvent(song: s2, queue: initialQueue, queueIndex: 1));
      await playingFuture;

      expect(bloc.state.currentSong?.id, '2');
      expect(bloc.state.queueIndex, 1);

      // Turn shuffle on
      bloc.add(const SetShuffleEvent(true));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.isShuffleEnabled, isTrue);

      // Shuffled queue preserves active track at queueIndex
      expect(bloc.state.queue[bloc.state.queueIndex].id, '2');
      expect(bloc.state.originalQueue.map((s) => s.id).toList(), ['1', '2', '3']);

      // Turn shuffle off
      bloc.add(const SetShuffleEvent(false));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.isShuffleEnabled, isFalse);

      // Unshuffling restores original queue and points queueIndex to s2
      expect(bloc.state.queue.map((s) => s.id).toList(), ['1', '2', '3']);
      expect(bloc.state.queueIndex, 1);
    });

    test('adding to queue while shuffled updates both queue and originalQueue',
        () async {
      final s1 = createSong('1', 'One');
      final s2 = createSong('2', 'Two');
      final sNew = createSong('new', 'New Song');

      final playingFuture = bloc.stream.firstWhere((s) => s.status == PlayerStatus.playing);
      bloc.add(PlaySongEvent(song: s1, queue: [s1, s2], queueIndex: 0));
      await playingFuture;

      bloc.add(const SetShuffleEvent(true));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.isShuffleEnabled, isTrue);

      bloc.add(AddToQueueEvent(song: sNew));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(bloc.state.queue.map((s) => s.id), contains('new'));
      expect(bloc.state.originalQueue.map((s) => s.id), contains('new'));

      // Disabling shuffle still contains the new song
      bloc.add(const SetShuffleEvent(false));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.isShuffleEnabled, isFalse);
      expect(bloc.state.queue.map((s) => s.id), contains('new'));
    });

    test('removing the current item advances safely to next song', () async {
      final s1 = createSong('1', 'One');
      final s2 = createSong('2', 'Two');
      final s3 = createSong('3', 'Three');

      final playingFuture = bloc.stream.firstWhere((s) => s.status == PlayerStatus.playing);
      bloc.add(PlaySongEvent(song: s2, queue: [s1, s2, s3], queueIndex: 1));
      await playingFuture;

      // Remove current track (index 1)
      final advanceFuture = bloc.stream.firstWhere((s) => s.currentSong?.id == '3');
      bloc.add(const RemoveFromQueueEvent(1));
      await advanceFuture;

      expect(bloc.state.queue.map((s) => s.id).toList(), ['1', '3']);
    });
  });
}
