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
  @override
  Future<ResolvedMediaSource> resolveForPlayback(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
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

  setUp(() async {
    Hive.init('./test_hive_player');
    playerBloc = PlayerBloc(
      musicRepository: FakeMusicRepository(),
      libraryRepository: FakeLibraryRepository(),
      audioPlayerService: FakeAudioPlayerService(),
      audioFocus: FakeAudioFocusOrchestratorService(),
      mediaResolver: FakeMediaResolverService(),
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
}
