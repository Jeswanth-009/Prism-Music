import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Right;
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:prism_music/core/services/collaborative_queue_service.dart';
import 'package:prism_music/domain/entities/song.dart';
import 'package:prism_music/domain/repositories/music_repository.dart';

class MockMusicRepository extends Mock implements MusicRepository {}

void main() {
  late MockMusicRepository mockMusicRepository;
  final service = CollaborativeQueueService.instance;
  const testPort = 8099;

  Song makeSong(String id, String title, String artist) {
    return Song(
      id: id,
      title: title,
      artist: artist,
      album: 'Test Album',
      duration: const Duration(seconds: 210),
      thumbnails: const Thumbnails(),
      source: MusicSource.youtube,
      youtubeId: id,
    );
  }

  setUp(() {
    mockMusicRepository = MockMusicRepository();
  });

  tearDown(() async {
    await service.stopServer();
  });

  group('CollaborativeQueueService (Party Mode)', () {
    test('starts and stops server cleanly', () async {
      expect(service.isRunning, isFalse);

      final started = await service.startServer(port: testPort);
      expect(started, isTrue);
      expect(service.isRunning, isTrue);
      expect(service.pin.length, 4);

      await service.stopServer();
      expect(service.isRunning, isFalse);
    });

    test('serves web app HTML at root /', () async {
      await service.startServer(port: testPort);

      final res = await http.get(Uri.parse('http://127.0.0.1:$testPort/'));
      expect(res.statusCode, 200);
      expect(res.headers['content-type'], contains('text/html'));
      expect(res.body, contains('Prism Party'));
    });

    test('serves session info at /api/session', () async {
      final nowPlaying = makeSong('np1', 'Current Track', 'Artist 1');
      final queuedSong = makeSong('q1', 'Next Track', 'Artist 2');

      service.configure(
        musicRepository: mockMusicRepository,
        onSongQueued: (_, __) {},
        nowPlayingProvider: () => nowPlaying,
        queueProvider: () => [queuedSong],
      );

      await service.startServer(port: testPort);

      final res = await http.get(Uri.parse('http://127.0.0.1:$testPort/api/session'));
      expect(res.statusCode, 200);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      expect(json['status'], 'ok');
      expect(json['pin'], service.pin);
      expect(json['nowPlaying']['title'], 'Current Track');
      expect((json['queue'] as List).first['title'], 'Next Track');
    });

    test('handles song search at /api/search?q=query', () async {
      final searchResult = [makeSong('s1', 'Found Song', 'Search Artist')];
      when(() => mockMusicRepository.searchSongs('test', limit: any(named: 'limit')))
          .thenAnswer((_) async => Right(searchResult));

      service.configure(
        musicRepository: mockMusicRepository,
        onSongQueued: (_, __) {},
      );

      await service.startServer(port: testPort);

      final res = await http.get(Uri.parse('http://127.0.0.1:$testPort/api/search?q=test'));
      expect(res.statusCode, 200);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      expect((json['results'] as List).length, 1);
      expect((json['results'] as List).first['title'], 'Found Song');
    });

    test('queues song on POST /api/queue/add with valid PIN', () async {
      Song? receivedSong;
      String? receivedGuest;

      service.configure(
        musicRepository: mockMusicRepository,
        onSongQueued: (song, guest) {
          receivedSong = song;
          receivedGuest = guest;
        },
      );

      await service.startServer(port: testPort);

      // 1. Unauthorized attempt with bad PIN
      final badRes = await http.post(
        Uri.parse('http://127.0.0.1:$testPort/api/queue/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pin': 'WRONG',
          'title': 'Party Anthem',
          'artist': 'DJ Alex',
        }),
      );
      expect(badRes.statusCode, 401);
      expect(receivedSong, isNull);

      // 2. Authorized attempt with correct PIN
      final goodRes = await http.post(
        Uri.parse('http://127.0.0.1:$testPort/api/queue/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pin': service.pin,
          'guestName': 'Maya',
          'title': 'Party Anthem',
          'artist': 'DJ Alex',
          'duration': 195,
        }),
      );
      expect(goodRes.statusCode, 200);
      expect(receivedSong, isNotNull);
      expect(receivedSong!.title, 'Party Anthem');
      expect(receivedGuest, 'Maya');
      expect(service.activityLog.first.guestName, 'Maya');
      expect(service.activityLog.first.songTitle, 'Party Anthem');
    });
  });
}
