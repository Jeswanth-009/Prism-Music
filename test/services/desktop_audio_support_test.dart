import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prism_music/core/services/audio_player_service.dart';
import 'package:prism_music/core/services/desktop_audio_support.dart';
import 'package:prism_music/core/services/desktop_shortcuts_service.dart';
import 'package:prism_music/core/services/desktop_window_service.dart';
import 'package:prism_music/domain/entities/song.dart';

class MockAudioPlayerService extends Mock implements AudioPlayerService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAudioPlayerService mockPlayerService;

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockPlayerService = MockAudioPlayerService();
  });

  group('DesktopAudioSupport', () {
    test('reports platform detection and platform name', () {
      final support = DesktopAudioSupport.instance;
      expect(support.platformName, isNotEmpty);
      // stepVolume tests
      expect(support.stepVolume(0.5, true), closeTo(0.55, 0.001));
      expect(support.stepVolume(0.98, true), equals(1.0));
      expect(support.stepVolume(0.5, false), closeTo(0.45, 0.001));
      expect(support.stepVolume(0.02, false), equals(0.0));
    });

    test('getPlatformAudioLoadConfiguration executes safely', () {
      final config = DesktopAudioSupport.instance.getPlatformAudioLoadConfiguration();
      // On non-android (test environment), should return null
      expect(config == null || config.androidLoadControl != null, isTrue);
    });
  });

  group('DesktopWindowService', () {
    test('formats window title correctly for idle and playing states', () {
      final service = DesktopWindowService.instance;

      expect(service.formatTitle(song: null, isPlaying: false), equals('Prism Music'));
      expect(service.formatTitle(song: null, isPlaying: true), equals('Prism Music'));

      const song = Song(
        id: 's1',
        title: 'Midnight City',
        artist: 'M83',
        thumbnails: Thumbnails(),
        duration: Duration(minutes: 4),
      );

      expect(
        service.formatTitle(song: song, isPlaying: false),
        equals('Prism Music'),
      );
      expect(
        service.formatTitle(song: song, isPlaying: true),
        equals('Prism Music - Midnight City • M83'),
      );
    });

    test('updateWindowTitle tracks current title', () async {
      final service = DesktopWindowService.instance;
      const song = Song(
        id: 's2',
        title: 'Intro',
        artist: 'The xx',
        thumbnails: Thumbnails(),
        duration: Duration(minutes: 2),
      );

      await service.updateWindowTitle(song: song, isPlaying: true);
      expect(service.currentTitle, equals('Prism Music - Intro • The xx'));

      await service.updateWindowTitle(song: null, isPlaying: false);
      expect(service.currentTitle, equals('Prism Music'));
    });
  });

  group('DesktopShortcutsService', () {
    test('handles Space key to toggle playback', () {
      when(() => mockPlayerService.playing).thenReturn(false);
      when(() => mockPlayerService.play()).thenAnswer((_) async {});

      final shortcuts = DesktopShortcutsService(playerService: mockPlayerService);

      const event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.space,
        logicalKey: LogicalKeyboardKey.space,
        timeStamp: Duration.zero,
      );

      final handled = shortcuts.handleKeyEvent(event);
      expect(handled, isTrue);
      verify(() => mockPlayerService.play()).called(1);
    });

    test('handles ArrowRight and ArrowLeft keys to seek', () {
      when(() => mockPlayerService.position).thenReturn(const Duration(seconds: 30));
      when(() => mockPlayerService.seek(any())).thenAnswer((_) async {});

      final shortcuts = DesktopShortcutsService(playerService: mockPlayerService);

      const seekFwd = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.arrowRight,
        logicalKey: LogicalKeyboardKey.arrowRight,
        timeStamp: Duration.zero,
      );

      expect(shortcuts.handleKeyEvent(seekFwd), isTrue);
      verify(() => mockPlayerService.seek(const Duration(seconds: 40))).called(1);

      const seekBack = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.arrowLeft,
        logicalKey: LogicalKeyboardKey.arrowLeft,
        timeStamp: Duration.zero,
      );

      expect(shortcuts.handleKeyEvent(seekBack), isTrue);
      verify(() => mockPlayerService.seek(const Duration(seconds: 20))).called(1);
    });

    test('handles ArrowUp and ArrowDown keys for volume stepping', () {
      when(() => mockPlayerService.volume).thenReturn(0.5);
      when(() => mockPlayerService.setVolume(any())).thenAnswer((_) async {});

      final shortcuts = DesktopShortcutsService(playerService: mockPlayerService);

      const volUp = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.arrowUp,
        logicalKey: LogicalKeyboardKey.arrowUp,
        timeStamp: Duration.zero,
      );
      expect(shortcuts.handleKeyEvent(volUp), isTrue);
      verify(() => mockPlayerService.setVolume(any(that: closeTo(0.55, 0.001)))).called(1);

      const volDown = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.arrowDown,
        logicalKey: LogicalKeyboardKey.arrowDown,
        timeStamp: Duration.zero,
      );
      expect(shortcuts.handleKeyEvent(volDown), isTrue);
      verify(() => mockPlayerService.setVolume(any(that: closeTo(0.45, 0.001)))).called(1);
    });

    test('ignores shortcuts when text field is focused', () {
      final shortcuts = DesktopShortcutsService(playerService: mockPlayerService);

      const space = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.space,
        logicalKey: LogicalKeyboardKey.space,
        timeStamp: Duration.zero,
      );

      final handled = shortcuts.handleKeyEvent(space, isTextFieldFocused: true);
      expect(handled, isFalse);
      verifyNever(() => mockPlayerService.play());
      verifyNever(() => mockPlayerService.pause());
    });
  });
}
