import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/media_resolver_service.dart';
import 'package:prism_music/core/services/stream_loader_service.dart';
import 'package:prism_music/domain/entities/song.dart';
import 'package:prism_music/domain/entities/stream_info.dart';
import '../../helpers/fakes.dart';

/// Scripted [StreamLoaderService]: only the members the media resolver uses.
class _ScriptedStreamLoader implements StreamLoaderService {
  StreamInfo? nextResult;
  final List<String> invalidatedIds = [];
  int loadCalls = 0;

  @override
  Future<StreamInfo> loadStream(
    Song song, {
    bool useCache = true,
    AudioQuality preferredQuality = AudioQuality.high,
    String? preferredResolverName,
  }) async {
    loadCalls++;
    final result = nextResult;
    if (result == null) {
      throw Exception('no scripted stream for ${song.playableId}');
    }
    return result;
  }

  @override
  void invalidateCache(String videoId) => invalidatedIds.add(videoId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('MediaResolverService', () {
    late _ScriptedStreamLoader streamLoader;
    late FakeDownloadService downloadService;
    late MediaResolverService resolver;

    final ytSong = Song(
      id: 'yt_abc',
      title: 'Kesariya',
      artist: 'Arijit Singh',
      duration: const Duration(seconds: 240),
      thumbnails: const Thumbnails(),
      source: MusicSource.youtube,
      youtubeId: 'yt_abc',
    );

    String googleVideoUrl({required bool expired}) {
      final expireSeconds = expired
          ? DateTime.now()
                .subtract(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
          1000
          : DateTime.now()
                .add(const Duration(hours: 6))
                .millisecondsSinceEpoch ~/
          1000;
      return 'https://rr3---sn-example.googlevideo.com/videoplayback'
          '?itag=140&mime=audio%2Fmp4&expire=$expireSeconds';
    }

    setUp(() {
      streamLoader = _ScriptedStreamLoader();
      downloadService = FakeDownloadService();
      resolver = MediaResolverService(
        streamLoader: streamLoader,
        downloadService: downloadService,
      );
    });

    test('a direct stream URL that is still valid is used as a HIT', () async {
      final validUrl = googleVideoUrl(expired: false);

      final resolved = await resolver.resolveForPlayback(
        ytSong.copyWith(streamUrl: validUrl),
      );

      expect(resolved.uri, equals(validUrl));
      expect(resolved.isOffline, isFalse);
      expect(streamLoader.loadCalls, equals(0));
    });

    test('an expired direct stream URL is ignored and re-resolved fresh',
        () async {
      final fresh = StreamInfo(
        url: 'https://rr1---sn-example.googlevideo.com/videoplayback?itag=251',
        codec: 'opus',
        bitrate: 160,
        container: 'webm',
        quality: AudioQuality.high,
        streamProvenance: 'youtube_explode',
      );
      streamLoader.nextResult = fresh;

      final resolved = await resolver.resolveForPlayback(
        ytSong.copyWith(streamUrl: googleVideoUrl(expired: true)),
      );

      expect(resolved.uri, equals(fresh.url));
      expect(streamLoader.loadCalls, equals(1));
    });

    test('takePreResolved discards a pre-resolved source whose URL expired',
        () async {
      streamLoader.nextResult = StreamInfo(
        url: googleVideoUrl(expired: true),
        codec: 'mp4a',
        bitrate: 320,
        container: 'm4a',
        quality: AudioQuality.high,
      );

      resolver.preResolveSong(ytSong);
      // Let the fire-and-forget pre-resolution run to completion.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final resolved = resolver.takePreResolved(ytSong.playableId);

      expect(resolved, isNull);
      expect(streamLoader.invalidatedIds, contains(ytSong.playableId));
    });

    test('takePreResolved returns a fresh pre-resolved source intact',
        () async {
      final validUrl = googleVideoUrl(expired: false);
      streamLoader.nextResult = StreamInfo(
        url: validUrl,
        codec: 'mp4a',
        bitrate: 320,
        container: 'm4a',
        quality: AudioQuality.high,
      );

      resolver.preResolveSong(ytSong);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final resolved = resolver.takePreResolved(ytSong.playableId);

      expect(resolved, isNotNull);
      expect(resolved!.uri, equals(validUrl));
      expect(streamLoader.invalidatedIds, isNot(contains(ytSong.playableId)));
    });

    test('a pre-resolved offline (local file) source stays usable', () async {
      // FakeDownloadService maps downloaded ids to /tmp/downloads/<id>.m4a;
      // create that file so the resolver's existsSync() gate passes.
      final localFile = File('/tmp/downloads/${ytSong.playableId}.m4a');
      await localFile.parent.create(recursive: true);
      await localFile.writeAsBytes(List<int>.filled(16, 0));
      addTearDown(() async {
        if (await localFile.exists()) await localFile.delete();
        try {
          await localFile.parent.delete();
        } catch (_) {}
      });
      downloadService.downloadedIds.add(ytSong.playableId);

      resolver.preResolveSong(ytSong);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final resolved = resolver.takePreResolved(ytSong.playableId);

      expect(resolved, isNotNull);
      expect(resolved!.isOffline, isTrue);
      expect(resolved.uri, contains(ytSong.playableId));
      expect(streamLoader.loadCalls, equals(0));
    });
  });
}
