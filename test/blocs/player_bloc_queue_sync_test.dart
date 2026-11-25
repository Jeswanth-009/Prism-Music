import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Either, Right;
import 'package:hive_flutter/hive_flutter.dart';
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

class FakeAudioFocusOrchestratorService implements AudioFocusOrchestratorService {
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

class _SuccessMediaResolver implements MediaResolverService {
  @override
  Future<ResolvedMediaSource> resolveForPlayback(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
    String? preferredResolverName,
  }) async {
    return ResolvedMediaSource(
      uri: 'https://stream.example.com/${song.id}',
      isOffline: false,
      videoId: song.id,
    );
  }

  @override
  ResolvedMediaSource? takePreResolved(String songId) => null;
  @override
  void preResolveSong(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) {}
  @override
  void invalidate(String songId) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An [AudioPlayerService] fake that models a native playback queue so the
/// bloc's native/bloc queue sync logic can be exercised end to end.
class FakeQueueAudioPlayerService implements AudioPlayerService {
  final _idxCtrl = StreamController<int?>.broadcast();
  final _posCtrl = StreamController<Duration>.broadcast();
  final _bufCtrl = StreamController<Duration>.broadcast();
  final _durCtrl = StreamController<Duration?>.broadcast();
  final _playCtrl = StreamController<bool>.broadcast();
  final _bufferingCtrl = StreamController<bool>.broadcast();
  final _compCtrl = StreamController<bool>.broadcast();
  final _errCtrl = StreamController<String>.broadcast();
  final _crossfadeCtrl = StreamController<bool>.broadcast();

  /// Song ids of the simulated native queue, in native order.
  List<String> nativeIds = [];

  /// Ids appended via [appendToQueue].
  final List<String> appendedIds = [];

  int skipToNextCalls = 0;
  int skipToPreviousCalls = 0;
  int loadQueueCalls = 0;
  @override
  int currentIndex = 0;

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
  Stream<bool> get isCrossfadingStream => _crossfadeCtrl.stream;

  @override
  bool get playing => false;
  @override
  bool get isCrossfading => false;
  @override
  bool get isQueueMode => nativeIds.isNotEmpty;

  @override
  bool get hasNext => currentIndex < nativeIds.length - 1;
  @override
  bool get hasPrevious => currentIndex > 0;

  @override
  String? mediaIdAt(int index) =>
      (index >= 0 && index < nativeIds.length) ? nativeIds[index] : null;

  @override
  List<String?> get queueMediaIds => List<String?>.from(nativeIds);

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
    nativeIds = videoId != null && videoId.isNotEmpty ? [videoId] : <String>[];
    currentIndex = 0;
    _durCtrl.add(const Duration(seconds: 180));
    return const Duration(seconds: 180);
  }

  @override
  Future<Duration?> loadQueue(
    List<Map<String, dynamic>> songs, {
    int initialIndex = 0,
    int prewarmLookahead = 3,
  }) async {
    loadQueueCalls++;
    nativeIds = songs
        .map((s) => s['videoId'] as String?)
        .whereType<String>()
        .toList();
    currentIndex = initialIndex.clamp(0, nativeIds.isEmpty ? 0 : nativeIds.length - 1);
    _idxCtrl.add(currentIndex);
    _durCtrl.add(const Duration(seconds: 180));
    return const Duration(seconds: 180);
  }

  @override
  Future<void> appendToQueue(List<Map<String, dynamic>> songs) async {
    for (final song in songs) {
      final id = song['videoId'] as String?;
      if (id == null) continue;
      appendedIds.add(id);
      nativeIds.add(id);
    }
  }

  @override
  Future<void> skipToNext() async {
    skipToNextCalls++;
    if (hasNext) {
      currentIndex++;
      _idxCtrl.add(currentIndex);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    skipToPreviousCalls++;
    if (hasPrevious) {
      currentIndex--;
      _idxCtrl.add(currentIndex);
    }
  }

  /// Simulates a native auto-advance to [index] without going through the
  /// skip helpers (mirrors just_audio advancing on track completion).
  void nativeAdvancesTo(int index) {
    currentIndex = index;
    _idxCtrl.add(index);
  }

  void emitBuffering(bool isBuffering) {
    _bufferingCtrl.add(isBuffering);
  }

  void emitError(String message) {
    _errCtrl.add(message);
  }

  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> applySongNormalization(Song? song) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlayerBloc playerBloc;
  late FakeQueueAudioPlayerService audioPlayer;

  // 11-char ids: valid YouTube-id shapes, matching the production pattern.
  const songA = Song(
    id: 'song_AAA001',
    title: 'Song A',
    artist: 'Artist A',
    duration: Duration(seconds: 180),
    thumbnails: Thumbnails(),
    youtubeId: 'song_AAA001',
  );
  const songB = Song(
    id: 'song_BBB002',
    title: 'Song B',
    artist: 'Artist B',
    duration: Duration(seconds: 180),
    thumbnails: Thumbnails(),
    youtubeId: 'song_BBB002',
  );
  const songC = Song(
    id: 'song_CCC003',
    title: 'Song C',
    artist: 'Artist C',
    duration: Duration(seconds: 180),
    thumbnails: Thumbnails(),
    youtubeId: 'song_CCC003',
  );
  const songD = Song(
    id: 'song_DDD004',
    title: 'Song D',
    artist: 'Artist D',
    duration: Duration(seconds: 180),
    thumbnails: Thumbnails(),
    youtubeId: 'song_DDD004',
  );

  setUp(() async {
    Hive.init('./test_hive_player');
    audioPlayer = FakeQueueAudioPlayerService();
    playerBloc = PlayerBloc(
      musicRepository: FakeMusicRepository(),
      libraryRepository: FakeLibraryRepository(),
      audioPlayerService: audioPlayer,
      audioFocus: FakeAudioFocusOrchestratorService(),
      mediaResolver: _SuccessMediaResolver(),
      reliability: PlaybackReliabilityService(),
      streamLoader: FakeStreamLoaderService(),
      downloadService: FakeDownloadService(),
    );
  });

  tearDown(() async {
    await playerBloc.close();
  });

  /// Plays a 3-song queue and waits until the bloc reports [songA] playing.
  Future<void> playThreeSongQueue() async {
    playerBloc.add(
      PlaySongEvent(song: songA, queue: [songA, songB, songC], queueIndex: 0),
    );
    await expectLater(
      playerBloc.stream,
      emitsThrough(
        predicate<PlayerState>(
          (s) => s.currentSong?.id == songA.id && s.status == PlayerStatus.playing,
        ),
      ),
    );
  }

  test('native auto-advance over a skipped entry lands on the right song',
      () async {
    await playThreeSongQueue();

    // The native queue silently dropped songB (no URL, no valid YouTube id),
    // so native position 1 is songC while bloc position 1 is still songB.
    audioPlayer.nativeIds = [songA.id, songC.id];
    audioPlayer.nativeAdvancesTo(1);

    await expectLater(
      playerBloc.stream,
      emitsThrough(
        predicate<PlayerState>(
          (s) => s.currentSong?.id == songC.id && s.queueIndex == 2,
        ),
      ),
    );

    expect(playerBloc.state.currentSong?.id, songC.id);
    expect(playerBloc.state.queueIndex, 2);
  });

  test('manual next with a desynced native queue follows the bloc order',
      () async {
    await playThreeSongQueue();

    // Native queue is stale (missing songB): skipToNext would land on the
    // wrong song, so the bloc must fall back to its own order.
    audioPlayer.nativeIds = [songA.id, songC.id];
    audioPlayer.nativeAdvancesTo(0);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    playerBloc.add(const NextEvent());

    await expectLater(
      playerBloc.stream,
      emitsThrough(
        predicate<PlayerState>(
          (s) => s.currentSong?.id == songB.id && s.queueIndex == 1,
        ),
      ),
    );

    expect(audioPlayer.skipToNextCalls, 0);
    // The bloc path rebuilds the native queue (back in sync afterwards).
    expect(audioPlayer.loadQueueCalls, greaterThanOrEqualTo(2));
    expect(audioPlayer.nativeIds, [
      songA.id,
      songB.id,
      songC.id,
    ]);
  });

  test('manual next with an in-sync native queue uses native skipToNext',
      () async {
    await playThreeSongQueue();

    playerBloc.add(const NextEvent());

    await expectLater(
      playerBloc.stream,
      emitsThrough(
        predicate<PlayerState>(
          (s) => s.currentSong?.id == songB.id && s.queueIndex == 1,
        ),
      ),
    );

    expect(audioPlayer.skipToNextCalls, 1);
  });

  test('add-to-queue while in sync appends to the native queue', () async {
    await playThreeSongQueue();

    playerBloc.add(AddToQueueEvent(song: songD));

    await expectLater(
      playerBloc.stream,
      emitsThrough(
        predicate<PlayerState>((s) => s.queue.length == 4),
      ),
    );

    expect(audioPlayer.appendedIds, [songD.id]);
    expect(audioPlayer.nativeIds, [
      songA.id,
      songB.id,
      songC.id,
      songD.id,
    ]);
  });

  test('play-next insertion does not touch the native queue', () async {
    await playThreeSongQueue();

    playerBloc.add(AddToQueueEvent(song: songD, playNext: true));

    await expectLater(
      playerBloc.stream,
      emitsThrough(
        predicate<PlayerState>(
          (s) =>
              s.queue.length == 4 && s.queue[1].id == songD.id,
        ),
      ),
    );

    expect(audioPlayer.appendedIds, isEmpty);
    expect(audioPlayer.nativeIds, [
      songA.id,
      songB.id,
      songC.id,
    ]);
  });

  test('add-to-queue while desynced leaves the native queue alone', () async {
    await playThreeSongQueue();

    audioPlayer.nativeIds = [songA.id, songC.id];
    audioPlayer.nativeAdvancesTo(0);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    playerBloc.add(AddToQueueEvent(song: songD));

    await expectLater(
      playerBloc.stream,
      emitsThrough(
        predicate<PlayerState>((s) => s.queue.length == 4),
      ),
    );

    expect(audioPlayer.appendedIds, isEmpty);
    expect(audioPlayer.nativeIds, [songA.id, songC.id]);
  });

  test('handles native error while loading during auto-advance instead of deadlocking', () async {
    await playThreeSongQueue();

    // Native player auto-advances to songB and begins buffering (PlayerStatus.loading).
    audioPlayer.nativeAdvancesTo(1);
    audioPlayer.emitBuffering(true);
    await expectLater(
      playerBloc.stream,
      emitsThrough(
        predicate<PlayerState>(
          (s) =>
              s.currentSong?.id == songB.id &&
              s.status == PlayerStatus.loading,
        ),
      ),
    );

    // songB fails with fatal 404 while in PlayerStatus.loading; PlayerBloc must
    // recover and skip forward to songC instead of dropping the error event.
    audioPlayer.emitError('Media source not found (404)');

    await expectLater(
      playerBloc.stream,
      emitsThrough(
        predicate<PlayerState>(
          (s) =>
              s.currentSong?.id == songC.id &&
              s.status == PlayerStatus.playing,
        ),
      ),
    );

    expect(playerBloc.state.queueIndex, 2);
  });
}
