import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prism_music/core/services/audio_player_service.dart';
import 'package:prism_music/core/services/wear_os_service.dart';
import 'package:prism_music/domain/entities/song.dart';

class MockAudioPlayerService extends Mock implements AudioPlayerService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAudioPlayerService mockPlayerService;
  late List<MethodCall> channelCalls;
  const channel = MethodChannel('com.prismmusic/wear_os');

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockPlayerService = MockAudioPlayerService();
    when(() => mockPlayerService.playingStream)
        .thenAnswer((_) => const Stream<bool>.empty());
    channelCalls = [];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      channelCalls.add(call);
      if (call.method == 'updatePlaybackState') {
        return true;
      }
      if (call.method == 'isCompanionAvailable') {
        return true;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('WearOsService', () {
    test('initializes and handles updatePlaybackState', () async {
      final service = WearOsService.createForTesting(channel: channel);
      service.initialize(playerService: mockPlayerService);

      const song = Song(
        id: 's1',
        title: 'Starboy',
        artist: 'The Weeknd',
        thumbnails: Thumbnails(high: 'https://example.com/art.jpg'),
        duration: Duration(minutes: 3, seconds: 50),
      );

      final success = await service.updatePlaybackState(
        song: song,
        isPlaying: true,
        position: const Duration(seconds: 45),
        duration: const Duration(minutes: 3, seconds: 50),
      );

      if (service.isSupported) {
        expect(success, isTrue);
        expect(channelCalls, isNotEmpty);
        final call = channelCalls.first;
        expect(call.method, equals('updatePlaybackState'));
        expect(call.arguments['title'], equals('Starboy'));
        expect(call.arguments['artist'], equals('The Weeknd'));
        expect(call.arguments['isPlaying'], isTrue);
        expect(call.arguments['positionMs'], equals(45000));
        expect(call.arguments['durationMs'], equals(230000));
      } else {
        expect(success, isFalse);
      }
    });

    test('handles incoming smartwatch play command', () async {
      final service = WearOsService.createForTesting(channel: channel);
      when(() => mockPlayerService.playing).thenReturn(false);
      when(() => mockPlayerService.play()).thenAnswer((_) async {});

      service.initialize(playerService: mockPlayerService);

      final byteData = const StandardMethodCodec().encodeMethodCall(
        const MethodCall('play', null),
      );

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage('com.prismmusic/wear_os', byteData, (data) {});

      verify(() => mockPlayerService.play()).called(1);
    });

    test('handles incoming smartwatch pause command', () async {
      final service = WearOsService.createForTesting(channel: channel);
      when(() => mockPlayerService.playing).thenReturn(true);
      when(() => mockPlayerService.pause()).thenAnswer((_) async {});

      service.initialize(playerService: mockPlayerService);

      final byteData = const StandardMethodCodec().encodeMethodCall(
        const MethodCall('pause', null),
      );

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage('com.prismmusic/wear_os', byteData, (data) {});

      verify(() => mockPlayerService.pause()).called(1);
    });

    test('handles incoming smartwatch next and previous commands', () async {
      var nextCalled = false;
      var prevCalled = false;
      final service = WearOsService.createForTesting(
        channel: channel,
        onSkipNext: () async => nextCalled = true,
        onSkipPrevious: () async => prevCalled = true,
      );

      service.initialize(playerService: mockPlayerService);

      final nextCall = const StandardMethodCodec().encodeMethodCall(
        const MethodCall('next', null),
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage('com.prismmusic/wear_os', nextCall, (data) {});
      expect(nextCalled, isTrue);

      final prevCall = const StandardMethodCodec().encodeMethodCall(
        const MethodCall('previous', null),
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage('com.prismmusic/wear_os', prevCall, (data) {});
      expect(prevCalled, isTrue);
    });

    test('handles incoming smartwatch seek command', () async {
      final service = WearOsService.createForTesting(channel: channel);
      when(() => mockPlayerService.seek(any())).thenAnswer((_) async {});

      service.initialize(playerService: mockPlayerService);

      final seekCall = const StandardMethodCodec().encodeMethodCall(
        const MethodCall('seek', {'positionMs': 60000}),
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage('com.prismmusic/wear_os', seekCall, (data) {});

      verify(() => mockPlayerService.seek(const Duration(minutes: 1))).called(1);
    });

    test('handles incoming smartwatch setVolume command', () async {
      final service = WearOsService.createForTesting(channel: channel);
      when(() => mockPlayerService.setVolume(any())).thenAnswer((_) async {});

      service.initialize(playerService: mockPlayerService);

      final volCall = const StandardMethodCodec().encodeMethodCall(
        const MethodCall('setVolume', {'volume': 0.75}),
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage('com.prismmusic/wear_os', volCall, (data) {});

      verify(() => mockPlayerService.setVolume(0.75)).called(1);
    });

    test('handles incoming smartwatch getPlaybackState query', () async {
      final service = WearOsService.createForTesting(channel: channel);
      when(() => mockPlayerService.playing).thenReturn(true);
      when(() => mockPlayerService.position).thenReturn(const Duration(seconds: 30));
      when(() => mockPlayerService.duration).thenReturn(const Duration(minutes: 3));

      service.initialize(playerService: mockPlayerService);
      service.setCurrentSong(const Song(
        id: 's2',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        thumbnails: Thumbnails(high: 'https://example.com/bl.jpg'),
        duration: Duration(minutes: 3),
      ));

      final stateCall = const StandardMethodCodec().encodeMethodCall(
        const MethodCall('getPlaybackState', null),
      );

      ByteData? responseBytes;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage('com.prismmusic/wear_os', stateCall, (data) {
        responseBytes = data;
      });

      expect(responseBytes, isNotNull);
      final result = const StandardMethodCodec().decodeEnvelope(responseBytes!) as Map;
      expect(result['title'], equals('Blinding Lights'));
      expect(result['artist'], equals('The Weeknd'));
      expect(result['isPlaying'], isTrue);
      expect(result['positionMs'], equals(30000));
      expect(result['durationMs'], equals(180000));
    });
  });
}
