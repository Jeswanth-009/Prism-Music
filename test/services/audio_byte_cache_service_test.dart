import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/audio_byte_cache_service.dart';

void main() {
  late Directory tempDir;
  late AudioByteCacheService cacheService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('prism_byte_cache_test_');
    cacheService = AudioByteCacheService(
      cacheDirectory: tempDir,
      maxCacheSizeBytes: 1000, // 1000 bytes quota
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AudioByteCacheService', () {
    test('writes and reads cached bytes', () async {
      const songId = 'yt_12345';
      final bytes = List<int>.generate(200, (i) => i % 256);

      expect(await cacheService.isCached(songId), isFalse);

      final file = await cacheService.putBytes(songId, bytes);
      expect(file.existsSync(), isTrue);
      expect(await cacheService.isCached(songId), isTrue);

      final cachedFile = await cacheService.getCachedFile(songId);
      expect(cachedFile, isNotNull);
      expect(await cachedFile!.readAsBytes(), equals(bytes));
    });

    test('evicts oldest files when exceeding quota', () async {
      // Put song 1 (400 bytes)
      await cacheService.putBytes('song1', List.filled(400, 1));
      expect(await cacheService.isCached('song1'), isTrue);

      // Put song 2 (400 bytes) -> total 800 <= 1000
      await cacheService.putBytes('song2', List.filled(400, 2));
      expect(await cacheService.isCached('song1'), isTrue);
      expect(await cacheService.isCached('song2'), isTrue);

      // Put song 3 (400 bytes) -> total 1200 > 1000 -> song1 evicted!
      await cacheService.putBytes('song3', List.filled(400, 3));
      expect(await cacheService.isCached('song3'), isTrue);
      expect(await cacheService.isCached('song1'), isFalse);
    });

    test('clears entire cache directory', () async {
      await cacheService.putBytes('song_a', [1, 2, 3]);
      await cacheService.putBytes('song_b', [4, 5, 6]);

      expect(await cacheService.getCacheSizeBytes(), greaterThan(0));
      await cacheService.clearCache();
      expect(await cacheService.getCacheSizeBytes(), equals(0));
    });
  });
}
