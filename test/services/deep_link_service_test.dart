import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prism_music/core/services/deep_link_service.dart';
import 'package:prism_music/core/utils/media_share_helper.dart';
import 'package:prism_music/domain/entities/playlist.dart';
import 'package:prism_music/domain/entities/song.dart';
import 'package:prism_music/presentation/blocs/player/player_bloc.dart';
import 'package:prism_music/presentation/blocs/player/player_event.dart';

class MockPlayerBloc extends Mock implements PlayerBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      const PlaySongEvent(
        song: Song(
          id: 'dummy',
          title: 'dummy',
          artist: 'dummy',
          duration: Duration.zero,
          thumbnails: Thumbnails(),
        ),
      ),
    );
  });

  group('DeepLinkService - URI & Text Parsing', () {
    test('parses custom prism://song URI with metadata query parameters', () {
      const uri =
          'prism://song?id=dQw4w9WgXcQ&title=Never%20Gonna%20Give%20You%20Up&artist=Rick%20Astley&album=Greatest%20Hits';
      final parsed = DeepLinkService.parse(uri);

      expect(parsed.isValid, isTrue);
      expect(parsed.type, equals(DeepLinkType.song));
      expect(parsed.id, equals('dQw4w9WgXcQ'));
      expect(parsed.title, equals('Never Gonna Give You Up'));
      expect(parsed.artist, equals('Rick Astley'));
      expect(parsed.album, equals('Greatest Hits'));
    });

    test('parses custom prism://playlist URI', () {
      const uri = 'prism://playlist?id=PL4fGSI1pDJn6puJdseH2Rt9sMvt9E2M4i&name=Party%20Hits';
      final parsed = DeepLinkService.parse(uri);

      expect(parsed.isValid, isTrue);
      expect(parsed.type, equals(DeepLinkType.playlist));
      expect(parsed.id, equals('PL4fGSI1pDJn6puJdseH2Rt9sMvt9E2M4i'));
      expect(parsed.title, equals('Party Hits'));
    });

    test('parses custom prism://search URI', () {
      const uri = 'prism://search?q=Taylor%20Swift';
      final parsed = DeepLinkService.parse(uri);

      expect(parsed.isValid, isTrue);
      expect(parsed.type, equals(DeepLinkType.search));
      expect(parsed.query, equals('Taylor Swift'));
    });

    test('parses standard YouTube Music watch link', () {
      const url = 'https://music.youtube.com/watch?v=dQw4w9WgXcQ';
      final parsed = DeepLinkService.parse(url);

      expect(parsed.isValid, isTrue);
      expect(parsed.type, equals(DeepLinkType.song));
      expect(parsed.id, equals('dQw4w9WgXcQ'));
    });

    test('parses shortened youtu.be link', () {
      const url = 'https://youtu.be/dQw4w9WgXcQ?si=abcdef123';
      final parsed = DeepLinkService.parse(url);

      expect(parsed.isValid, isTrue);
      expect(parsed.type, equals(DeepLinkType.song));
      expect(parsed.id, equals('dQw4w9WgXcQ'));
    });

    test('parses YouTube Music playlist link', () {
      const url =
          'https://music.youtube.com/playlist?list=PL4fGSI1pDJn6puJdseH2Rt9sMvt9E2M4i';
      final parsed = DeepLinkService.parse(url);

      expect(parsed.isValid, isTrue);
      expect(parsed.type, equals(DeepLinkType.playlist));
      expect(parsed.id, equals('PL4fGSI1pDJn6puJdseH2Rt9sMvt9E2M4i'));
    });

    test('extracts link from arbitrary shared text snippet', () {
      const sharedText =
          'Hey check out this cool song: https://music.youtube.com/watch?v=dQw4w9WgXcQ shared via Prism';
      final parsed = DeepLinkService.parse(sharedText);

      expect(parsed.isValid, isTrue);
      expect(parsed.type, equals(DeepLinkType.song));
      expect(parsed.id, equals('dQw4w9WgXcQ'));
    });

    test('returns unknown for invalid, empty, or non-media URLs', () {
      expect(DeepLinkService.parse('').isValid, isFalse);
      expect(DeepLinkService.parse('https://example.com/other').type, equals(DeepLinkType.unknown));
      expect(DeepLinkService.parse('random words with no link').isValid, isFalse);
    });
  });

  group('MediaShareHelper - Prism Deep Link Generators', () {
    const song = Song(
      id: 'dQw4w9WgXcQ',
      youtubeId: 'dQw4w9WgXcQ',
      title: 'Starboy',
      artist: 'The Weeknd',
      album: 'Starboy Deluxe',
      duration: Duration(minutes: 3, seconds: 50),
      thumbnails: Thumbnails(),
    );

    const playlist = Playlist(
      id: 'PL12345678901234567',
      name: 'Weekend Vibez',
    );

    test('buildPrismSongUri formats valid prism://song URI', () {
      final uri = MediaShareHelper.buildPrismSongUri(song);
      expect(uri, startsWith('prism://song?'));
      expect(uri, contains('id=dQw4w9WgXcQ'));
      expect(uri, contains('title=Starboy'));
      expect(uri, contains('artist=The+Weeknd'));

      final parsed = DeepLinkService.parse(uri);
      expect(parsed.isValid, isTrue);
      expect(parsed.id, equals('dQw4w9WgXcQ'));
      expect(parsed.title, equals('Starboy'));
      expect(parsed.artist, equals('The Weeknd'));
    });

    test('buildPrismPlaylistUri formats valid prism://playlist URI', () {
      final uri = MediaShareHelper.buildPrismPlaylistUri(playlist);
      expect(uri, startsWith('prism://playlist?'));
      expect(uri, contains('id=PL12345678901234567'));
      expect(uri, contains('name=Weekend+Vibez'));

      final parsed = DeepLinkService.parse(uri);
      expect(parsed.isValid, isTrue);
      expect(parsed.id, equals('PL12345678901234567'));
      expect(parsed.title, equals('Weekend Vibez'));
    });
  });

  group('DeepLinkService - Playback Dispatch & Channel Integration', () {
    late MockPlayerBloc mockPlayerBloc;
    late MethodChannel testChannel;

    setUp(() {
      mockPlayerBloc = MockPlayerBloc();
      testChannel = const MethodChannel('test.com.prismmusic/deep_link');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, (call) async {
        if (call.method == 'getInitialLink') {
          return 'prism://song?id=dQw4w9WgXcQ&title=InitialSong&artist=Rick';
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, null);
    });

    test('handleRawLink dispatches PlaySongEvent to PlayerBloc', () async {
      final service = DeepLinkService(
        playerBloc: mockPlayerBloc,
        platformChannel: testChannel,
      );

      final events = <ParsedDeepLink>[];
      final sub = service.linkStream.listen(events.add);

      await service.handleRawLink(
        'prism://song?id=dQw4w9WgXcQ&title=TestTrack&artist=TestArtist',
      );

      expect(events.length, equals(1));
      expect(events.first.id, equals('dQw4w9WgXcQ'));

      verify(() => mockPlayerBloc.add(any(that: isA<PlaySongEvent>())))
          .called(1);

      await sub.cancel();
      service.dispose();
    });

    test('initialize processes cold-start launch link', () async {
      final service = DeepLinkService(
        playerBloc: mockPlayerBloc,
        platformChannel: testChannel,
      );

      await service.initialize();

      verify(() => mockPlayerBloc.add(any(that: isA<PlaySongEvent>())))
          .called(1);

      service.dispose();
    });
  });
}
