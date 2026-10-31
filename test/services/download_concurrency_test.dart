import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/download_service.dart';
import 'package:prism_music/core/services/stream_loader_service.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/domain/entities/entities.dart';

import '../helpers/fakes.dart';

class _FakeStreamLoaderService implements StreamLoaderService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ControllableAdapter implements HttpClientAdapter {
  final Map<String, Completer<void>> inflight = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final completer = Completer<void>();
    inflight[options.path] = completer;

    // Support cancellation
    cancelFuture?.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
          ),
        );
      }
    });

    await completer.future;

    // Return dummy valid audio bytes (>= 16KB with ID3 magic bytes)
    final bytes = Uint8List(20 * 1024);
    bytes[0] = 0x49;
    bytes[1] = 0x44;
    bytes[2] = 0x33;
    bytes[3] = 0x03;
    return ResponseBody(
      Stream.value(bytes),
      200,
      headers: {
        Headers.contentTypeHeader: ['audio/mp4'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Song _testSong(String id) {
  return Song(
    id: id,
    title: 'Song $id',
    artist: 'Artist',
    duration: const Duration(minutes: 3),
    thumbnails: const Thumbnails(),
    source: MusicSource.jiosaavn,
    streamUrl: 'https://example.com/audio_$id.m4a',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DownloadService downloadService;
  late _ControllableAdapter adapter;
  late Directory tempDir;

  setUp(() async {
    initTestHive('download_pool_test');
    await SettingsService.instance.initialize();
    await SettingsService.instance.setDownloadWifiOnly(false);

    tempDir = Directory('./test_downloads_concurrency').absolute;
    if (!tempDir.existsSync()) {
      tempDir.createSync(recursive: true);
    }
    await SettingsService.instance.setDownloadFolderPath(tempDir.path);

    adapter = _ControllableAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    downloadService = DownloadService(_FakeStreamLoaderService(), dio: dio);
    await downloadService.initialize();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  test('concurrency limiter caps active downloads at 3 and queues the rest', () async {
    final s1 = _testSong('s1');
    final s2 = _testSong('s2');
    final s3 = _testSong('s3');
    final s4 = _testSong('s4');
    final s5 = _testSong('s5');

    // Trigger 5 concurrent downloads
    unawaited(downloadService.downloadSong(s1));
    unawaited(downloadService.downloadSong(s2));
    unawaited(downloadService.downloadSong(s3));
    unawaited(downloadService.downloadSong(s4));
    unawaited(downloadService.downloadSong(s5));

    await Future<void>.delayed(const Duration(milliseconds: 30));

    // First 3 should be downloading
    expect(downloadService.getDownloadStatus('s1'), DownloadStatus.downloading);
    expect(downloadService.getDownloadStatus('s2'), DownloadStatus.downloading);
    expect(downloadService.getDownloadStatus('s3'), DownloadStatus.downloading);

    // 4th and 5th should be queued
    expect(downloadService.getDownloadStatus('s4'), DownloadStatus.queued);
    expect(downloadService.getDownloadStatus('s5'), DownloadStatus.queued);

    // Complete the first download
    adapter.inflight['https://example.com/audio_s1.m4a']?.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // s1 should complete, s4 should be promoted from queued to downloading
    expect(downloadService.getDownloadStatus('s1'), DownloadStatus.completed);
    expect(downloadService.getDownloadStatus('s4'), DownloadStatus.downloading);
    // s5 should still be queued
    expect(downloadService.getDownloadStatus('s5'), DownloadStatus.queued);

    // Complete s2 and s3 to free remaining slots
    adapter.inflight['https://example.com/audio_s2.m4a']?.complete();
    adapter.inflight['https://example.com/audio_s3.m4a']?.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // s5 should now be promoted to downloading
    expect(downloadService.getDownloadStatus('s5'), DownloadStatus.downloading);

    // Complete s4 and s5
    adapter.inflight['https://example.com/audio_s4.m4a']?.complete();
    adapter.inflight['https://example.com/audio_s5.m4a']?.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(downloadService.getDownloadStatus('s4'), DownloadStatus.completed);
    expect(downloadService.getDownloadStatus('s5'), DownloadStatus.completed);
  });

  test('cancelling a queued download removes it from the queue cleanly', () async {
    final s1 = _testSong('q1');
    final s2 = _testSong('q2');
    final s3 = _testSong('q3');
    final s4 = _testSong('q4');

    unawaited(downloadService.downloadSong(s1));
    unawaited(downloadService.downloadSong(s2));
    unawaited(downloadService.downloadSong(s3));
    unawaited(downloadService.downloadSong(s4));

    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(downloadService.getDownloadStatus('q4'), DownloadStatus.queued);

    // Cancel q4 while it is still waiting in queue
    downloadService.cancelDownload('q4');

    expect(downloadService.getDownloadStatus('q4'), DownloadStatus.notDownloaded);

    // Complete q1 to free up a slot
    adapter.inflight['https://example.com/audio_q1.m4a']?.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // q4 was cancelled, so no download was initiated for q4
    expect(adapter.inflight.containsKey('https://example.com/audio_q4.m4a'), isFalse);
  });
}
