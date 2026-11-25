import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';
import 'package:prism_music/core/services/youtube_audio_source.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

AudioOnlyStreamInfo _fakeStreamInfo(int itag, int bitrateBps) {
  return AudioOnlyStreamInfo(
    VideoId('dQw4w9WgXcQ'),
    itag,
    Uri.parse('https://example.com/audio_$itag.m4a'),
    StreamContainer.mp4,
    FileSize(bitrateBps * 30),
    Bitrate(bitrateBps),
    'mp4a.40.2',
    'medium',
    const [],
    MediaType('audio', 'mp4'),
    null,
  );
}

void main() {
  group('YouTubeAudioSource bitrate selection', () {
    test('selectStreamForQuality picks highest bitrate for high/lossless and lowest for low', () {
      // sortByBitrate() returns descending order (highest bitrate first).
      final descendingStreams = [
        _fakeStreamInfo(251, 256000),
        _fakeStreamInfo(140, 128000),
        _fakeStreamInfo(249, 50000),
      ];

      expect(
        YouTubeAudioSource.selectStreamForQuality(descendingStreams, 'high')?.tag,
        251,
      );
      expect(
        YouTubeAudioSource.selectStreamForQuality(descendingStreams, 'lossless')?.tag,
        251,
      );
      expect(
        YouTubeAudioSource.selectStreamForQuality(descendingStreams, 'medium')?.tag,
        140,
      );
      expect(
        YouTubeAudioSource.selectStreamForQuality(descendingStreams, 'low')?.tag,
        249,
      );
    });
  });

  group('openHttpRangeAudioStream', () {
    late HttpServer server;
    late String baseUrl;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUrl = 'http://127.0.0.1:${server.port}';
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('resolves non-null contentLength from Content-Range on 206 responses', () async {
      server.listen((req) async {
        expect(req.headers.value('user-agent'), contains('AndroidClient'));
        req.response.statusCode = HttpStatus.partialContent;
        req.response.headers.set('content-range', 'bytes 0-4/10');
        req.response.headers.set('content-type', 'audio/mp4');
        req.response.add([1, 2, 3, 4, 5]);
        await req.response.close();
      });

      final clients = <http.Client>{};
      final response = await openHttpRangeAudioStream(
        streamUrl: '$baseUrl/audio',
        start: 0,
        end: null,
        totalBytes: 0,
        fallbackContentType: 'audio/mp4',
        headers: const {'User-Agent': 'AndroidClient/20.10'},
        activeClients: clients,
      );

      expect(response.contentLength, 5);
      expect(response.sourceLength, 10);
      expect(response.offset, 0);
      final bytes = await response.stream.expand((e) => e).toList();
      expect(bytes, [1, 2, 3, 4, 5]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(clients, isEmpty);
    });

    test('concurrent range requests do not abort each other', () async {
      final firstGate = Completer<void>();
      var requestCount = 0;

      server.listen((req) async {
        final id = ++requestCount;
        if (id == 1) {
          await firstGate.future;
        }
        req.response.statusCode = HttpStatus.partialContent;
        req.response.headers.set('content-range', 'bytes 0-2/10');
        req.response.add([id, id + 1, id + 2]);
        await req.response.close();
      });

      final clients = <http.Client>{};
      final f1 = openHttpRangeAudioStream(
        streamUrl: '$baseUrl/audio',
        start: 0,
        end: 3,
        totalBytes: 10,
        fallbackContentType: 'audio/mp4',
        activeClients: clients,
      );
      await Future<void>.delayed(const Duration(milliseconds: 25));

      final f2 = openHttpRangeAudioStream(
        streamUrl: '$baseUrl/audio',
        start: 0,
        end: 3,
        totalBytes: 10,
        fallbackContentType: 'audio/mp4',
        activeClients: clients,
      );

      final r2 = await f2;
      firstGate.complete();
      final r1 = await f1;

      final b2 = await r2.stream.expand((e) => e).toList();
      final b1 = await r1.stream.expand((e) => e).toList();
      expect(b1.length, 3);
      expect(b2.length, 3);
    });
  });
}
