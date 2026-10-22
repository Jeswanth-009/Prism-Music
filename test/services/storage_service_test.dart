import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prism_music/core/services/storage_service.dart';
import 'package:prism_music/core/services/stream_cache_service.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late StreamCacheService streamCache;
  late StorageService storageService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('storage_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => tempDir.path,
    );
    Hive.init(tempDir.path);
    streamCache = StreamCacheService();
    storageService = StorageService(streamCacheService: streamCache);
  });

  tearDown(() async {
    try {
      await Hive.close();
    } catch (_) {}
    if (tempDir.existsSync()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  test('getStorageBreakdown accounts for stream cache and hive cache boxes', () async {
    // Populate stream cache
    streamCache.cache('video_test', streamInfo('https://example.com/audio.m4a'));

    // Populate lyrics cache box
    final lyricsBox = await Hive.openBox<Map>('lyrics_cache');
    await lyricsBox.put('song_1', {'lyrics': 'la la la'});

    final breakdown = await storageService.getStorageBreakdown();

    expect(breakdown.streamCacheCount, 1);
    expect(breakdown.lyricsCacheCount, 1);
  });

  test('clearCache purges volatile stream cache and lyrics box', () async {
    streamCache.cache('video_test', streamInfo('https://example.com/audio.m4a'));
    final lyricsBox = await Hive.openBox<Map>('lyrics_cache');
    await lyricsBox.put('song_1', {'lyrics': 'la la la'});

    expect(streamCache.isCached('video_test'), isTrue);
    expect(lyricsBox.isNotEmpty, isTrue);

    await storageService.clearCache();

    expect(streamCache.isCached('video_test'), isFalse);
    expect(lyricsBox.isEmpty, isTrue);
  });
}
