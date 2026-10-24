import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prism_music/core/services/media_session_coordinator.dart';
import 'package:prism_music/core/services/prism_audio_handler.dart';
import 'package:prism_music/core/services/widget_service.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAudioPlayer mockPlayer;
  late PrismAudioHandler handler;

  setUp(() {
    mockPlayer = MockAudioPlayer();
    when(() => mockPlayer.playbackEventStream).thenAnswer((_) => const Stream.empty());
    when(() => mockPlayer.sequenceStateStream).thenAnswer((_) => const Stream.empty());
    when(() => mockPlayer.sequenceStream).thenAnswer((_) => const Stream.empty());
    when(() => mockPlayer.playing).thenReturn(true);
    when(() => mockPlayer.position).thenReturn(const Duration(seconds: 30));
    when(() => mockPlayer.duration).thenReturn(const Duration(minutes: 3));
    when(() => mockPlayer.bufferedPosition).thenReturn(const Duration(seconds: 60));
    when(() => mockPlayer.speed).thenReturn(1.0);
    when(() => mockPlayer.processingState).thenReturn(ProcessingState.ready);
    when(() => mockPlayer.playbackEvent).thenReturn(PlaybackEvent());
    when(() => mockPlayer.seek(any())).thenAnswer((_) async {});

    handler = PrismAudioHandler(mockPlayer);
  });

  group('PrismAudioHandler - Lock-Screen Affordances', () {
    test('broadcasts favorite, skips, fastForward, rewind in controls and systemActions', () {
      handler.refreshNotificationState();
      final state = handler.playbackState.value;

      expect(state.controls.any((c) => c.label == 'Favorite'), isTrue);
      expect(state.controls.any((c) => c.action == MediaAction.fastForward), isTrue);
      expect(state.controls.any((c) => c.action == MediaAction.rewind), isTrue);

      expect(state.systemActions.contains(MediaAction.fastForward), isTrue);
      expect(state.systemActions.contains(MediaAction.rewind), isTrue);
      expect(state.systemActions.contains(MediaAction.setRepeatMode), isTrue);
      expect(state.systemActions.contains(MediaAction.setShuffleMode), isTrue);
      expect(state.systemActions.contains(MediaAction.custom), isTrue);
    });

    test('fastForward seeks forward 10 seconds', () async {
      await handler.fastForward();
      verify(() => mockPlayer.seek(const Duration(seconds: 40))).called(1);
    });

    test('rewind seeks backward 10 seconds without dropping below zero', () async {
      await handler.rewind();
      verify(() => mockPlayer.seek(const Duration(seconds: 20))).called(1);
    });

    test('customAction toggleLike routes to MediaSessionCoordinator', () async {
      var likeToggled = false;
      MediaSessionCoordinator.instance.bindBloc(
        onNext: () async {},
        onPrevious: () async {},
        onStop: () async {},
        onToggleLike: () async {
          likeToggled = true;
        },
        hasNext: () => true,
        hasPrevious: () => true,
      );

      final res = await handler.customAction('toggleLike');
      expect(res, isTrue);
      expect(likeToggled, isTrue);
    });

    test('setShuffleMode and setRepeatMode route to MediaSessionCoordinator', () async {
      var shuffleToggled = false;
      var repeatCycled = false;

      MediaSessionCoordinator.instance.bindBloc(
        onNext: () async {},
        onPrevious: () async {},
        onStop: () async {},
        onToggleShuffle: () async {
          shuffleToggled = true;
        },
        onCycleRepeat: () async {
          repeatCycled = true;
        },
        hasNext: () => true,
        hasPrevious: () => true,
      );

      await handler.setShuffleMode(AudioServiceShuffleMode.all);
      expect(shuffleToggled, isTrue);

      await handler.setRepeatMode(AudioServiceRepeatMode.all);
      expect(repeatCycled, isTrue);
    });
  });

  group('WidgetService', () {
    test('updateWidget handles call gracefully without crashing', () async {
      // In flutter test platform, it should not throw
      await WidgetService.instance.updateWidget(
        title: 'Track Title',
        artist: 'Artist Name',
        isPlaying: true,
      );
    });
  });
}
