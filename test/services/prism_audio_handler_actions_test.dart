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
    when(() => mockPlayer.durationStream).thenAnswer((_) => const Stream.empty());
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

      expect(state.controls.any((c) => c.label == 'Like' || c.label == 'Unlike' || c.label == 'Favorite'), isTrue);
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

    test('defensive error handling catches underlying player exceptions silently', () async {
      when(() => mockPlayer.play()).thenThrow(Exception('Simulated native play crash'));
      when(() => mockPlayer.pause()).thenThrow(Exception('Simulated native pause crash'));
      when(() => mockPlayer.seek(any())).thenThrow(Exception('Simulated native seek crash'));

      // None of these should throw or crash the handler
      await expectLater(handler.play(), completes);
      await expectLater(handler.pause(), completes);
      await expectLater(handler.seek(const Duration(seconds: 10)), completes);
      await expectLater(handler.fastForward(), completes);
      await expectLater(handler.rewind(), completes);
    });

    test('defensive error handling catches media browsing exceptions safely', () async {
      final children = await handler.getChildren('corrupted_unknown_id');
      expect(children, isEmpty);

      final item = await handler.getMediaItem('corrupted_unknown_id');
      expect(item, isNull);

      await expectLater(handler.playFromMediaId('corrupted_unknown_id'), completes);
      await expectLater(handler.search(''), completes);
      await expectLater(handler.playFromSearch(''), completes);
    });

    test('getChildren returns enriched Android Auto top-level categories including artists', () async {
      final root = await handler.getChildren(AudioService.MEDIA_ROOT_ID);
      expect(root.map((i) => i.id).toList(), containsAll(['downloads', 'favorites', 'playlists', 'recent', 'artists']));
      expect(root.every((i) => i.playable == false), isTrue);
    });

    test('getMediaItem returns root and category items', () async {
      final root = await handler.getMediaItem(AudioService.MEDIA_ROOT_ID);
      expect(root, isNotNull);
      expect(root?.id, 'root');

      final artistsItem = await handler.getMediaItem('artists');
      expect(artistsItem, isNotNull);
      expect(artistsItem?.title, 'Favorite Artists');
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
