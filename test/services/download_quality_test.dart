import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prism_music/core/services/download_service.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/core/services/stream_loader_service.dart';
import 'package:prism_music/domain/entities/entities.dart';

class MockStreamLoaderService extends Mock implements StreamLoaderService {}

class FakeSong extends Fake implements Song {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    registerFallbackValue(FakeSong());
    registerFallbackValue(AudioQuality.high);
    final tempDir = await Directory.systemTemp.createTemp('download_quality_test_');
    Hive.init(tempDir.path);
    await SettingsService.instance.initialize();
  });

  group('AudioQuality.fromString', () {
    test('parses known quality strings case-insensitively', () {
      expect(AudioQuality.fromString('low'), AudioQuality.low);
      expect(AudioQuality.fromString('LOW'), AudioQuality.low);
      expect(AudioQuality.fromString('medium'), AudioQuality.medium);
      expect(AudioQuality.fromString('MEDIUM'), AudioQuality.medium);
      expect(AudioQuality.fromString('high'), AudioQuality.high);
      expect(AudioQuality.fromString('HIGH'), AudioQuality.high);
      expect(AudioQuality.fromString('lossless'), AudioQuality.lossless);
      expect(AudioQuality.fromString('ultra'), AudioQuality.lossless);
      expect(AudioQuality.fromString('ULTRA'), AudioQuality.lossless);
    });

    test('defaults to AudioQuality.high for null or unrecognized strings', () {
      expect(AudioQuality.fromString(null), AudioQuality.high);
      expect(AudioQuality.fromString(''), AudioQuality.high);
      expect(AudioQuality.fromString('unknown_quality'), AudioQuality.high);
    });
  });

  group('SettingsService download quality', () {
    test('defaults to high when not configured', () {
      final settings = SettingsService.instance;
      expect(settings.downloadAudioQuality, 'high');
    });

    test('updates downloadAudioQuality', () async {
      final settings = SettingsService.instance;
      await settings.setDownloadAudioQuality('medium');
      expect(settings.downloadAudioQuality, 'medium');

      await settings.setDownloadAudioQuality('lossless');
      expect(settings.downloadAudioQuality, 'lossless');

      // Reset back to high
      await settings.setDownloadAudioQuality('high');
      expect(settings.downloadAudioQuality, 'high');
    });
  });

  group('DownloadService quality selection', () {
    late MockStreamLoaderService mockStreamLoader;
    late DownloadService downloadService;

    final testSong = Song(
      id: 'test_song_dl_q',
      title: 'Download Quality Test Song',
      artist: 'Prism Tester',
      duration: const Duration(seconds: 180),
      source: MusicSource.youtube,
      thumbnails: const Thumbnails(),
    );

    setUp(() {
      mockStreamLoader = MockStreamLoaderService();
      downloadService = DownloadService(mockStreamLoader);
    });

    test('invokes streamLoader with explicit requested quality', () async {
      AudioQuality? passedQuality;

      when(() => mockStreamLoader.loadStream(
            any(),
            useCache: any(named: 'useCache'),
            preferredQuality: any(named: 'preferredQuality'),
          )).thenAnswer((invocation) async {
        passedQuality = invocation.namedArguments[#preferredQuality] as AudioQuality?;
        return const StreamInfo(
          url: 'https://audio.example.com/stream.m4a',
          codec: 'aac',
          bitrate: 64000,
          container: 'm4a',
          quality: AudioQuality.low,
        );
      });

      // We call downloadSong with low quality.
      downloadService.downloadSong(testSong, quality: AudioQuality.low);

      // Allow microtasks to run
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(passedQuality, AudioQuality.low);
    });

    test('falls back to SettingsService downloadAudioQuality when no quality passed', () async {
      await SettingsService.instance.setDownloadAudioQuality('medium');
      AudioQuality? passedQuality;

      when(() => mockStreamLoader.loadStream(
            any(),
            useCache: any(named: 'useCache'),
            preferredQuality: any(named: 'preferredQuality'),
          )).thenAnswer((invocation) async {
        passedQuality = invocation.namedArguments[#preferredQuality] as AudioQuality?;
        return const StreamInfo(
          url: 'https://audio.example.com/stream.m4a',
          codec: 'aac',
          bitrate: 128000,
          container: 'm4a',
          quality: AudioQuality.medium,
        );
      });

      downloadService.downloadSong(testSong);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(passedQuality, AudioQuality.medium);

      // Clean up
      await SettingsService.instance.setDownloadAudioQuality('high');
    });
  });
}
