import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
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

import 'package:dartz/dartz.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prism_music/core/error/failures.dart';

class FakeMusicRepository implements MusicRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLibraryRepository implements LibraryRepository {
  @override
  Future<Either<Failure, void>> addToHistory(Song song) async => const Right(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAudioPlayerService implements AudioPlayerService {
  final _posCtrl = StreamController<Duration>.broadcast();
  final _bufCtrl = StreamController<Duration>.broadcast();
  final _durCtrl = StreamController<Duration?>.broadcast();
  final _playCtrl = StreamController<bool>.broadcast();
  final _bufferingCtrl = StreamController<bool>.broadcast();
  final _compCtrl = StreamController<bool>.broadcast();
  final _errCtrl = StreamController<String>.broadcast();
  final _idxCtrl = StreamController<int?>.broadcast();

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
    if (url.contains('unplayable')) {
      _errCtrl.add('HTTP 403 Forbidden');
      return null;
    }
    return const Duration(seconds: 180);
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> stop() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAudioFocusOrchestratorService implements AudioFocusOrchestratorService {
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

class FakeMediaResolverService implements MediaResolverService {
  /// songId -> number of initial resolve calls that fail (with a NON-fatal
  /// 503) before succeeding. Exercises the retry path end to end.
  final Map<String, int> failTimes = {};

  /// songIds whose resolution throws TimeoutException (non-fatal) forever.
  final Set<String> timeoutSongIds = {};

  /// songId -> gate that holds resolution open until the test completes it.
  final Map<String, Completer<ResolvedMediaSource>> gates = {};

  final _attemptCounts = <String, int>{};

  @override
  Future<ResolvedMediaSource> resolveForPlayback(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    final gate = gates[song.id];
    if (gate != null) {
      return gate.future;
    }

    final failures = failTimes[song.id] ?? 0;
    final attempt = (_attemptCounts[song.id] ?? 0) + 1;
    _attemptCounts[song.id] = attempt;
    if (attempt <= failures) {
      // 503: not in the fatal-error list, so the bloc should retry.
      throw Exception('Stream resolution failed: 503 Service Unavailable');
    }
    if (timeoutSongIds.contains(song.id)) {
      throw TimeoutException('Stream resolution timed out');
    }
    if (song.id == 'broken_song') {
      throw Exception('Stream resolution failed: 403 Forbidden');
    }
    return ResolvedMediaSource(
      uri: 'https://stream.example.com/${song.id}',
      isOffline: false,
      videoId: song.id,
    );
  }

  @override
  ResolvedMediaSource? takePreResolved(String songId) => null;
  @override
  void preResolveSong(Song song, {AudioQuality preferredQuality = AudioQuality.high}) {}
  @override
  void invalidate(String songId) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDownloadService implements DownloadService {
  @override
  bool isDownloaded(String songId) => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStreamLoaderService implements StreamLoaderService {
  @override
  void prefetch(Song song, {AudioQuality preferredQuality = AudioQuality.high}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlayerBloc playerBloc;
  late FakeMediaResolverService mediaResolver;

  setUp(() async {
    Hive.init('./test_hive_player');
    mediaResolver = FakeMediaResolverService();
    playerBloc = PlayerBloc(
      musicRepository: FakeMusicRepository(),
      libraryRepository: FakeLibraryRepository(),
      audioPlayerService: FakeAudioPlayerService(),
      audioFocus: FakeAudioFocusOrchestratorService(),
      mediaResolver: mediaResolver,
      reliability: PlaybackReliabilityService(),
      streamLoader: FakeStreamLoaderService(),
      downloadService: FakeDownloadService(),
    );
  });

  tearDown(() async {
    await playerBloc.close();
  });

  test('Auto-advances to next song when first song in queue is unplayable', () async {
    const song1 = Song(
      id: 'broken_song',
      title: 'Broken Track',
      artist: 'Artist A',
      duration: Duration(seconds: 180),
      thumbnails: Thumbnails(),
    );

    const song2 = Song(
      id: 'valid_song_2',
      title: 'Good Track',
      artist: 'Artist B',
      duration: Duration(seconds: 200),
      thumbnails: Thumbnails(),
    );

    final queue = [song1, song2];

    playerBloc.add(
      PlaySongEvent(
        song: song1,
        queue: queue,
        queueIndex: 0,
      ),
    );

    // Wait for resolution failure, skip notice, and auto-advance to song 2
    await expectLater(
      playerBloc.stream,
      emitsThrough(
        predicate<PlayerState>(
          (s) => s.currentSong?.id == 'valid_song_2' && s.status == PlayerStatus.playing,
        ),
      ),
    );

    expect(playerBloc.state.currentSong?.id, 'valid_song_2');
    expect(playerBloc.state.queueIndex, 1);
  });

  test('Stops gracefully without infinite loop when all songs in queue fail', () async {
    const song1 = Song(
      id: 'broken_song',
      title: 'Broken Track 1',
      artist: 'Artist A',
      duration: Duration(seconds: 180),
      thumbnails: Thumbnails(),
    );

    final queue = [song1];

    playerBloc.add(
      PlaySongEvent(
        song: song1,
        queue: queue,
        queueIndex: 0,
      ),
    );

    // Wait for error state without infinite loop
    await expectLater(
      playerBloc.stream,
      emitsThrough(
        predicate<PlayerState>((s) => s.status == PlayerStatus.error),
      ),
    );

    expect(playerBloc.state.status, PlayerStatus.error);
  });

  test('Non-fatal failure retries the song and succeeds', () async {
    const song1 = Song(
      id: 'flaky_song',
      title: 'Flaky Track',
      artist: 'Artist A',
      duration: Duration(seconds: 180),
      thumbnails: Thumbnails(),
    );

    mediaResolver.failTimes['flaky_song'] = 1; // fail once (503), then succeed

    playerBloc.add(
      PlaySongEvent(song: song1, queue: [song1], queueIndex: 0),
    );

    await expectLater(
      playerBloc.stream,
      emitsThrough(
        predicate<PlayerState>(
          (s) =>
              s.currentSong?.id == 'flaky_song' &&
              s.status == PlayerStatus.playing,
        ),
      ),
    );

    expect(playerBloc.state.status, PlayerStatus.playing);
  });

  test('Timeout during resolution is retried, then auto-advances', () async {
    const song1 = Song(
      id: 'timeout_song',
      title: 'Slow Track',
      artist: 'Artist A',
      duration: Duration(seconds: 180),
      thumbnails: Thumbnails(),
    );
    const song2 = Song(
      id: 'valid_song_2',
      title: 'Good Track',
      artist: 'Artist B',
      duration: Duration(seconds: 200),
      thumbnails: Thumbnails(),
    );

    mediaResolver.timeoutSongIds.add('timeout_song');

    playerBloc.add(
      PlaySongEvent(song: song1, queue: [song1, song2], queueIndex: 0),
    );

    // Both retries of song1 fail with TimeoutException (non-fatal), then the
    // bloc must skip ahead instead of hanging in loading forever.
    await expectLater(
      playerBloc.stream,
      emitsThrough(
        predicate<PlayerState>(
          (s) =>
              s.currentSong?.id == 'valid_song_2' &&
              s.status == PlayerStatus.playing,
        ),
      ),
    );

    expect(playerBloc.state.currentSong?.id, 'valid_song_2');
    expect(playerBloc.state.queueIndex, 1);
  });

  test('Circuit breaker blocks programmatic advance but manual play still works', () async {
    // A separate bloc whose breaker is already open (5 consecutive failures).
    final reliability = PlaybackReliabilityService();
    for (var i = 0; i < 5; i++) {
      reliability.registerFailure('warm_up_$i');
    }
    final blockedBloc = PlayerBloc(
      musicRepository: FakeMusicRepository(),
      libraryRepository: FakeLibraryRepository(),
      audioPlayerService: FakeAudioPlayerService(),
      audioFocus: FakeAudioFocusOrchestratorService(),
      mediaResolver: FakeMediaResolverService(),
      reliability: reliability,
      streamLoader: FakeStreamLoaderService(),
      downloadService: FakeDownloadService(),
    );
    addTearDown(blockedBloc.close);

    const song1 = Song(
      id: 'broken_song',
      title: 'Broken Track',
      artist: 'Artist A',
      duration: Duration(seconds: 180),
      thumbnails: Thumbnails(),
    );
    const song2 = Song(
      id: 'valid_song_2',
      title: 'Good Track',
      artist: 'Artist B',
      duration: Duration(seconds: 200),
      thumbnails: Thumbnails(),
    );
    final queue = [song1, song2];

    // User taps a song: user-initiated plays pass the open circuit.
    blockedBloc.add(PlaySongEvent(song: song1, queue: queue, queueIndex: 0));

    // song1 fails fatally; the programmatic auto-skip is rejected by the
    // open circuit and playback settles into a visible error state.
    await expectLater(
      blockedBloc.stream,
      emitsThrough(
        predicate<PlayerState>((s) => s.status == PlayerStatus.error),
      ),
    );
    expect(blockedBloc.state.status, PlayerStatus.error);
    expect(blockedBloc.state.errorMessage, contains('Try again in'));

    // The user then explicitly picks the next song: must play despite the
    // still-open circuit.
    blockedBloc.add(PlaySongEvent(song: song2, queue: queue, queueIndex: 1));
    await expectLater(
      blockedBloc.stream,
      emitsThrough(
        predicate<PlayerState>(
          (s) =>
              s.currentSong?.id == 'valid_song_2' &&
              s.status == PlayerStatus.playing,
        ),
      ),
    );
    expect(blockedBloc.state.currentSong?.id, 'valid_song_2');
    expect(blockedBloc.state.queueIndex, 1);
  });

  test('Manual skip during hung resolution abandons the stale attempt', () async {
    const song1 = Song(
      id: 'hung_song',
      title: 'Hung Track',
      artist: 'Artist A',
      duration: Duration(seconds: 180),
      thumbnails: Thumbnails(),
    );
    const song2 = Song(
      id: 'valid_song_2',
      title: 'Good Track',
      artist: 'Artist B',
      duration: Duration(seconds: 200),
      thumbnails: Thumbnails(),
    );

    mediaResolver.gates['hung_song'] = Completer<ResolvedMediaSource>();

    playerBloc.add(
      PlaySongEvent(song: song1, queue: [song1, song2], queueIndex: 0),
    );
    await Future.delayed(const Duration(milliseconds: 100));
    expect(playerBloc.state.status, PlayerStatus.loading);
    expect(playerBloc.state.currentSong?.id, 'hung_song');

    // User skips while song1's resolution is still hanging.
    playerBloc.add(const NextEvent());
    await expectLater(
      playerBloc.stream,
      emitsThrough(
        predicate<PlayerState>(
          (s) =>
              s.currentSong?.id == 'valid_song_2' &&
              s.status == PlayerStatus.playing,
        ),
      ),
    );

    // The stale attempt finally fails — it must NOT clobber song2's state,
    // register failures, or schedule an auto-advance back to song1.
    mediaResolver.gates['hung_song']!
        .completeError(Exception('Stream resolution failed: 403 Forbidden'));
    await Future.delayed(const Duration(milliseconds: 300));

    expect(playerBloc.state.currentSong?.id, 'valid_song_2');
    expect(playerBloc.state.queueIndex, 1);
    expect(playerBloc.state.status, PlayerStatus.playing);
  });
}
