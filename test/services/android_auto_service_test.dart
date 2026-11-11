import 'package:audio_service/audio_service.dart';
import 'package:fpdart/fpdart.dart' show Right;
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prism_music/core/services/download_service.dart';
import 'package:prism_music/core/services/media_session_coordinator.dart';
import 'package:prism_music/core/services/prism_audio_handler.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/domain/repositories/repositories.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}
class MockDownloadService extends Mock implements DownloadService {}
class MockLibraryRepository extends Mock implements LibraryRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAudioPlayer mockPlayer;
  late MockDownloadService mockDownloads;
  late MockLibraryRepository mockLibrary;
  late PrismAudioHandler handler;

  const testSong1 = Song(
    id: 'song1',
    title: 'Song One',
    artist: 'Artist A',
    duration: Duration(seconds: 180),
    thumbnails: Thumbnails(high: 'https://example.com/art1.jpg'),
  );

  const testSong2 = Song(
    id: 'song2',
    title: 'Song Two',
    artist: 'Artist B',
    duration: Duration(seconds: 210),
    thumbnails: Thumbnails(high: 'https://example.com/art2.jpg'),
  );

  const testPlaylist = Playlist(
    id: 'pl1',
    name: 'Road Trip Hits',
    trackCount: 2,
    songs: [testSong1, testSong2],
  );

  setUp(() {
    mockPlayer = MockAudioPlayer();
    mockDownloads = MockDownloadService();
    mockLibrary = MockLibraryRepository();

    when(() => mockPlayer.playbackEventStream).thenAnswer((_) => const Stream.empty());
    when(() => mockPlayer.durationStream).thenAnswer((_) => const Stream.empty());
    when(() => mockPlayer.sequenceStateStream).thenAnswer((_) => const Stream.empty());
    when(() => mockPlayer.sequenceStream).thenAnswer((_) => const Stream.empty());
    when(() => mockPlayer.playing).thenReturn(false);
    when(() => mockPlayer.position).thenReturn(Duration.zero);
    when(() => mockPlayer.duration).thenReturn(const Duration(minutes: 3));
    when(() => mockPlayer.bufferedPosition).thenReturn(Duration.zero);
    when(() => mockPlayer.speed).thenReturn(1.0);
    when(() => mockPlayer.processingState).thenReturn(ProcessingState.idle);
    when(() => mockPlayer.playbackEvent).thenReturn(PlaybackEvent());

    handler = PrismAudioHandler(
      mockPlayer,
      downloadService: mockDownloads,
      libraryRepository: mockLibrary,
    );
  });

  group('PrismAudioHandler - Android Auto MediaBrowser Tree', () {
    test('getChildren at root returns 4 browsable categories', () async {
      final children = await handler.getChildren(AudioService.MEDIA_ROOT_ID);
      expect(children.length, 4);
      expect(children.map((c) => c.id).toList(), ['downloads', 'favorites', 'playlists', 'recent']);
      expect(children.every((c) => c.playable == false), isTrue);
    });

    test('getChildren for downloads returns downloaded playable songs', () async {
      when(() => mockDownloads.getDownloadedSongsList()).thenReturn([testSong1, testSong2]);

      final children = await handler.getChildren('downloads');
      expect(children.length, 2);
      expect(children[0].id, 'download_song1');
      expect(children[0].title, 'Song One');
      expect(children[0].playable, isTrue);
      expect(children[1].id, 'download_song2');
    });

    test('getChildren for favorites returns liked songs', () async {
      when(() => mockLibrary.getLikedSongs()).thenAnswer((_) async => const Right([testSong1]));

      final children = await handler.getChildren('favorites');
      expect(children.length, 1);
      expect(children[0].id, 'fav_song1');
      expect(children[0].title, 'Song One');
      expect(children[0].playable, isTrue);
    });

    test('getChildren for playlists returns user playlists', () async {
      when(() => mockLibrary.getUserPlaylists()).thenAnswer((_) async => const Right([testPlaylist]));

      final children = await handler.getChildren('playlists');
      expect(children.length, 1);
      expect(children[0].id, 'playlist_pl1');
      expect(children[0].title, 'Road Trip Hits');
      expect(children[0].playable, isFalse);
    });

    test('getChildren for playlist_pl1 returns its playable tracks', () async {
      when(() => mockLibrary.getUserPlaylists()).thenAnswer((_) async => const Right([testPlaylist]));

      final children = await handler.getChildren('playlist_pl1');
      expect(children.length, 2);
      expect(children[0].id, 'pl_pl1_song1');
      expect(children[0].title, 'Song One');
      expect(children[0].playable, isTrue);
      expect(children[1].id, 'pl_pl1_song2');
      expect(children[1].title, 'Song Two');
      expect(children[1].playable, isTrue);
    });

    test('getChildren for recent returns listening history songs', () async {
      when(() => mockLibrary.getListeningHistory(limit: any(named: 'limit')))
          .thenAnswer((_) async => const Right([testSong2]));

      final children = await handler.getChildren('recent');
      expect(children.length, 1);
      expect(children[0].id, 'rec_song2');
      expect(children[0].title, 'Song Two');
      expect(children[0].playable, isTrue);
    });
  });

  group('PrismAudioHandler - Android Auto getItem', () {
    test('getItem returns item for root and downloads', () async {
      final rootItem = await handler.getItem('root');
      expect(rootItem, isNotNull);
      expect(rootItem!.title, 'Prism Music');

      final downItem = await handler.getItem('downloads');
      expect(downItem, isNotNull);
      expect(downItem!.title, 'Downloads');
    });

    test('getItem returns playlist item for playlist_pl1', () async {
      when(() => mockLibrary.getUserPlaylists()).thenAnswer((_) async => const Right([testPlaylist]));

      final plItem = await handler.getItem('playlist_pl1');
      expect(plItem, isNotNull);
      expect(plItem!.title, 'Road Trip Hits');
      expect(plItem.playable, isFalse);
    });

    test('getItem returns song item for download_song1', () async {
      when(() => mockDownloads.getDownloadedSongsList()).thenReturn([testSong1]);
      when(() => mockLibrary.getLikedSongs()).thenAnswer((_) async => const Right([]));
      when(() => mockLibrary.getListeningHistory(limit: any(named: 'limit'))).thenAnswer((_) async => const Right([]));

      final songItem = await handler.getItem('download_song1');
      expect(songItem, isNotNull);
      expect(songItem!.title, 'Song One');
      expect(songItem.playable, isTrue);
    });
  });

  group('PrismAudioHandler - Android Auto Playback Callbacks', () {
    test('playFromMediaId with playlist plays first track with playlist queue', () async {
      when(() => mockLibrary.getUserPlaylists()).thenAnswer((_) async => const Right([testPlaylist]));

      Song? playedSong;
      List<Song>? playedQueue;
      int? playedIndex;

      MediaSessionCoordinator.instance.bindBloc(
        onNext: () async {},
        onPrevious: () async {},
        onStop: () async {},
        hasNext: () => true,
        hasPrevious: () => true,
        onPlayMedia: (song, queue, index) {
          playedSong = song;
          playedQueue = queue;
          playedIndex = index;
        },
      );

      await handler.playFromMediaId('playlist_pl1');

      expect(playedSong, equals(testSong1));
      expect(playedQueue?.length, 2);
      expect(playedIndex, 0);
    });

    test('playFromMediaId with download_song2 plays target track at index 1', () async {
      when(() => mockDownloads.getDownloadedSongsList()).thenReturn([testSong1, testSong2]);

      Song? playedSong;
      int? playedIndex;

      MediaSessionCoordinator.instance.bindBloc(
        onNext: () async {},
        onPrevious: () async {},
        onStop: () async {},
        hasNext: () => true,
        hasPrevious: () => true,
        onPlayMedia: (song, queue, index) {
          playedSong = song;
          playedIndex = index;
        },
      );

      await handler.playFromMediaId('download_song2');

      expect(playedSong, equals(testSong2));
      expect(playedIndex, 1);
    });

    test('search and playFromSearch matches downloads and initiates playback', () async {
      when(() => mockDownloads.searchDownloadedSongs('song one')).thenReturn([testSong1]);

      final searchResults = await handler.search('song one');
      expect(searchResults.length, 1);
      expect(searchResults.first.title, 'Song One');

      Song? playedSong;
      when(() => mockDownloads.getDownloadedSongsList()).thenReturn([testSong1]);
      MediaSessionCoordinator.instance.bindBloc(
        onNext: () async {},
        onPrevious: () async {},
        onStop: () async {},
        hasNext: () => true,
        hasPrevious: () => true,
        onPlayMedia: (song, queue, index) {
          playedSong = song;
        },
      );

      await handler.playFromSearch('song one');
      expect(playedSong, equals(testSong1));
    });
  });
}
