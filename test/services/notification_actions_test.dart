import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prism_music/core/services/media_session_coordinator.dart';
import 'package:prism_music/core/services/prism_audio_handler.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAudioPlayer mockPlayer;
  late StreamController<Duration?> durationController;
  late PrismAudioHandler handler;

  setUp(() {
    mockPlayer = MockAudioPlayer();
    durationController = StreamController<Duration?>.broadcast();

    when(() => mockPlayer.playbackEventStream).thenAnswer((_) => const Stream.empty());
    when(() => mockPlayer.durationStream).thenAnswer((_) => durationController.stream);
    when(() => mockPlayer.sequenceStateStream).thenAnswer((_) => const Stream.empty());
    when(() => mockPlayer.sequenceStream).thenAnswer((_) => const Stream.empty());
    when(() => mockPlayer.playing).thenReturn(true);
    when(() => mockPlayer.position).thenReturn(const Duration(seconds: 45));
    when(() => mockPlayer.duration).thenReturn(const Duration(minutes: 4));
    when(() => mockPlayer.bufferedPosition).thenReturn(const Duration(seconds: 90));
    when(() => mockPlayer.speed).thenReturn(1.0);
    when(() => mockPlayer.processingState).thenReturn(ProcessingState.ready);
    when(() => mockPlayer.playbackEvent).thenReturn(PlaybackEvent());

    handler = PrismAudioHandler(mockPlayer);
    MediaSessionCoordinator.instance.attachHandler(handler);
  });

  tearDown(() async {
    await durationController.close();
  });

  group('Notification Actions & Progress Seekbar', () {
    test('renders Like action with outline icon when song is unliked', () {
      MediaSessionCoordinator.instance.isCurrentSongLiked = false;
      handler.refreshNotificationState();

      final state = handler.playbackState.value;
      final likeControl = state.controls.firstWhere((c) => c.label == 'Like');
      expect(likeControl.androidIcon, 'drawable/ic_heart_outline');
    });

    test('renders Unlike action with filled heart icon when song is liked', () {
      MediaSessionCoordinator.instance.isCurrentSongLiked = true;
      handler.refreshNotificationState();

      final state = handler.playbackState.value;
      final unlikeControl = state.controls.firstWhere((c) => c.label == 'Unlike');
      expect(unlikeControl.androidIcon, 'drawable/ic_heart');
    });

    test('playbackState provides seek action, updatePosition, and bufferedPosition for seekbar', () {
      handler.refreshNotificationState();
      final state = handler.playbackState.value;

      expect(state.systemActions.contains(MediaAction.seek), isTrue);
      expect(state.updatePosition, const Duration(seconds: 45));
      expect(state.bufferedPosition, const Duration(seconds: 90));
      expect(state.speed, 1.0);
    });

    test('durationStream updates mediaItem duration for notification progress bar', () async {
      handler.mediaItem.add(const MediaItem(
        id: 'test_song',
        title: 'Test Song',
        album: 'Test Album',
      ));

      durationController.add(const Duration(seconds: 240));
      await pumpEventQueue();

      expect(handler.mediaItem.value?.duration, const Duration(seconds: 240));
    });

    test('updatePlaybackInfo updates quality indicator label and re-renders', () {
      handler.mediaItem.add(const MediaItem(
        id: 'test_song_2',
        title: 'Test Song 2',
      ));

      MediaSessionCoordinator.instance.updatePlaybackInfo(
        isLiked: true,
        qualityLabel: 'Ultra (320 kbps)',
      );

      expect(handler.mediaItem.value?.displayDescription, 'Ultra (320 kbps)');
      expect(MediaSessionCoordinator.instance.isCurrentSongLiked, isTrue);

      final state = handler.playbackState.value;
      expect(state.controls.any((c) => c.label == 'Unlike'), isTrue);
    });
  });
}
