// ignore_for_file: depend_on_referenced_packages
import 'package:file/file.dart' as pkg_file;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prism_music/core/services/artwork_prefetch_service.dart';
import 'package:prism_music/domain/entities/entities.dart';

class MockCacheManager extends Mock implements BaseCacheManager {}

class MockFileInfo extends Mock implements FileInfo {}

class MockFile extends Mock implements pkg_file.File {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCacheManager mockCacheManager;
  late ArtworkPrefetchService service;

  Song createSong(String id, String? thumbUrl) {
    return Song(
      id: id,
      title: 'Title $id',
      artist: 'Artist $id',
      duration: const Duration(seconds: 200),
      source: MusicSource.youtube,
      thumbnails: thumbUrl != null ? Thumbnails.fromUrl(thumbUrl) : const Thumbnails(),
    );
  }

  setUp(() {
    mockCacheManager = MockCacheManager();
    service = ArtworkPrefetchService.custom(cacheManager: mockCacheManager);
  });

  group('ArtworkPrefetchService', () {
    test('returns 0 for empty queue or invalid index', () async {
      expect(await service.prefetchUpcomingQueue([], 0), 0);
      expect(await service.prefetchUpcomingQueue([createSong('1', 'https://img.com/1.jpg')], -1), 0);
    });

    test('prefetches up to lookahead upcoming songs that are not in cache', () async {
      final queue = [
        createSong('0', 'https://img.com/0.jpg'),
        createSong('1', 'https://img.com/1.jpg'),
        createSong('2', 'https://img.com/2.jpg'),
        createSong('3', 'https://img.com/3.jpg'),
        createSong('4', ''), // empty thumbnail
        createSong('5', 'https://img.com/5.jpg'),
      ];

      when(() => mockCacheManager.getFileFromCache(any()))
          .thenAnswer((_) async => null);
      when(() => mockCacheManager.downloadFile(any()))
          .thenAnswer((invocation) async {
        final url = invocation.positionalArguments[0] as String;
        final file = MockFile();
        when(() => file.path).thenReturn('/cache/$url');
        return FileInfo(
          file,
          FileSource.Online,
          DateTime.now().add(const Duration(days: 7)),
          url,
        );
      });

      // Starting at index 1 with lookahead = 3 should consider index 1, 2, 3, 4
      // 1, 2, 3 have thumbnails, 4 has empty thumbnail -> 3 urls scheduled
      final scheduled = await service.prefetchUpcomingQueue(queue, 1, lookahead: 3);
      expect(scheduled, 3);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(() => mockCacheManager.downloadFile('https://img.com/1.jpg')).called(1);
      verify(() => mockCacheManager.downloadFile('https://img.com/2.jpg')).called(1);
      verify(() => mockCacheManager.downloadFile('https://img.com/3.jpg')).called(1);
      verifyNever(() => mockCacheManager.downloadFile('https://img.com/0.jpg'));
      verifyNever(() => mockCacheManager.downloadFile('https://img.com/5.jpg'));
    });

    test('skips download if artwork is already cached', () async {
      final queue = [
        createSong('0', 'https://img.com/cached.jpg'),
      ];

      final mockFileInfo = MockFileInfo();
      final mockFile = MockFile();
      when(() => mockFileInfo.file).thenReturn(mockFile);
      when(() => mockFile.exists()).thenAnswer((_) async => true);

      when(() => mockCacheManager.getFileFromCache('https://img.com/cached.jpg'))
          .thenAnswer((_) async => mockFileInfo);

      final scheduled = await service.prefetchUpcomingQueue(queue, 0, lookahead: 1);
      expect(scheduled, 1);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(() => mockCacheManager.getFileFromCache('https://img.com/cached.jpg')).called(1);
      verifyNever(() => mockCacheManager.downloadFile(any()));
    });

    test('prefetchSongArtwork handles single song prefetch', () async {
      final song = createSong('single', 'https://img.com/single.jpg');

      when(() => mockCacheManager.getFileFromCache('https://img.com/single.jpg'))
          .thenAnswer((_) async => null);
      when(() => mockCacheManager.downloadFile('https://img.com/single.jpg'))
          .thenAnswer((invocation) async {
        final file = MockFile();
        return FileInfo(
          file,
          FileSource.Online,
          DateTime.now().add(const Duration(days: 7)),
          'https://img.com/single.jpg',
        );
      });

      await service.prefetchSongArtwork(song);

      verify(() => mockCacheManager.downloadFile('https://img.com/single.jpg')).called(1);
    });
  });
}
