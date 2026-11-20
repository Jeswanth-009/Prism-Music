import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/media_resolver_service.dart';
import 'package:prism_music/core/services/playback_reliability_service.dart';
import 'package:prism_music/presentation/blocs/player/player_bloc.dart';
import 'package:prism_music/presentation/blocs/player/player_event.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';

import '../helpers/fakes.dart';

class _FailingResolver extends FakeMediaResolver {
  @override
  Future<ResolvedMediaSource> resolveForPlayback(
    dynamic song, {
    dynamic preferredQuality,
    String? preferredResolverName,
  }) async {
    throw Exception('Stream 403 Forbidden');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ensureWidgetTestHive();
  });

  group('PlayerLoadingStage & Playback Notifications', () {
    test('loading stages display human-readable labels', () {
      expect(PlayerLoadingStage.none.displayLabel, '');
      expect(
        PlayerLoadingStage.resolving.displayLabel,
        'Resolving audio stream…',
      );
      expect(
        PlayerLoadingStage.buffering.displayLabel,
        'Buffering audio…',
      );
    });

    test('PlayerState loading stage getters and copyWith behavior', () {
      var state = const PlayerState();
      expect(state.loadingStage, PlayerLoadingStage.none);
      expect(state.isResolving, isFalse);
      expect(state.isBufferingAudio, isFalse);
      expect(state.playbackNotification, isNull);

      state = state.copyWith(loadingStage: PlayerLoadingStage.resolving);
      expect(state.loadingStage, PlayerLoadingStage.resolving);
      expect(state.isResolving, isTrue);
      expect(state.isBufferingAudio, isFalse);

      state = state.copyWith(loadingStage: PlayerLoadingStage.buffering);
      expect(state.loadingStage, PlayerLoadingStage.buffering);
      expect(state.isResolving, isFalse);
      expect(state.isBufferingAudio, isTrue);

      state = state.copyWith(
        playbackNotification: "Couldn't play 'Song A' — skipped",
      );
      expect(state.playbackNotification, "Couldn't play 'Song A' — skipped");

      state = state.copyWith(clearPlaybackNotification: true);
      expect(state.playbackNotification, isNull);
    });

    test('auto-advance on playback failure emits skip notification', () async {
      final queue = [
        song('song-1', 'First Song'),
        song('song-2', 'Second Song'),
      ];

      final bloc = PlayerBloc(
        musicRepository: FakeMusicRepository(),
        libraryRepository: FakeLibraryRepository(),
        audioPlayerService: FakeAudioPlayerService(),
        audioFocus: FakeAudioFocusOrchestrator(),
        mediaResolver: _FailingResolver(),
        reliability: PlaybackReliabilityService(),
        streamLoader: FakeStreamLoader(),
        downloadService: FakeDownloadService(),
      );

      final notifications = <String?>[];
      final sub = bloc.stream
          .where((s) => s.playbackNotification != null)
          .listen((s) => notifications.add(s.playbackNotification));

      bloc.add(
        PlaySongEvent(
          song: queue.first,
          queue: queue,
          queueIndex: 0,
        ),
      );

      // Allow failure handling and auto-advance to process
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(notifications, contains("Couldn't play 'First Song' — skipped"));

      await sub.cancel();
      await bloc.close();
    });
  });
}
