import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/stream_cache_service.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StreamCacheService', () {
    late StreamCacheService cache;

    setUp(() {
      cache = StreamCacheService();
    });

    test('miss returns null before anything is cached', () {
      expect(cache.getCached('video_1'), isNull);
      expect(cache.isCached('video_1'), isFalse);
    });

    test('hit returns the identical stream info', () {
      final info = streamInfo('https://stream.example.com/v1');
      cache.cache('video_1', info);

      expect(cache.isCached('video_1'), isTrue);
      expect(cache.getCached('video_1')!.url, 'https://stream.example.com/v1');
    });

    test('entries expire after their TTL', () async {
      cache.cache('video_1', streamInfo(), ttl: const Duration(milliseconds: 20));
      expect(cache.isCached('video_1'), isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(cache.isCached('video_1'), isFalse);
      expect(cache.getCached('video_1'), isNull);
    });

    test('stats separate valid from expired entries', () async {
      cache.cache('fresh', streamInfo());
      cache.cache('dead', streamInfo(), ttl: const Duration(milliseconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final stats = cache.getStats();
      expect(stats['total'], 2);
      expect(stats['valid'], 1);
      expect(stats['expired'], 1);
    });

    test('invalidate drops a single entry', () {
      cache.cache('a', streamInfo());
      cache.cache('b', streamInfo());

      cache.invalidate('a');

      expect(cache.isCached('a'), isFalse);
      expect(cache.isCached('b'), isTrue);
    });

    test('clearAll empties everything', () {
      cache.cache('a', streamInfo());
      cache.cache('b', streamInfo());

      cache.clearAll();

      expect(cache.getStats()['total'], 0);
    });
  });
}
