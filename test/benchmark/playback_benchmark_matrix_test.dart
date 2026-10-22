import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/benchmark/playback_benchmark_matrix.dart';
import 'package:prism_music/core/providers/audio_stream_resolver.dart';
import 'package:prism_music/core/services/diagnostics_service.dart';
import 'package:prism_music/core/services/playback_reliability_service.dart';
import 'package:prism_music/domain/entities/entities.dart';

class FakeStreamResolver implements AudioStreamResolver {
  @override
  final String resolverName;
  @override
  final bool isAvailable;
  final Duration latency;
  final bool shouldFail;

  FakeStreamResolver({
    required this.resolverName,
    this.isAvailable = true,
    this.latency = const Duration(milliseconds: 30),
    this.shouldFail = false,
  });

  @override
  Future<StreamInfo?> resolveStream(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    await Future.delayed(latency);
    if (shouldFail) return null;
    return StreamInfo(
      url: 'https://cdn.example.com/audio.m4a',
      codec: 'aac',
      bitrate: 256,
      container: 'm4a',
      quality: preferredQuality,
      streamProvenance: resolverName,
      matchConfidence: 0.98,
    );
  }
}

void main() {
  group('LatencyPercentiles', () {
    test('computes correct percentiles and handles empty sets gracefully', () {
      final empty = LatencyPercentiles.fromDurations([]);
      expect(empty.p50Ms, 0.0);
      expect(empty.p90Ms, 0.0);
      expect(empty.meanMs, 0.0);

      final durations = [
        const Duration(milliseconds: 100),
        const Duration(milliseconds: 200),
        const Duration(milliseconds: 300),
        const Duration(milliseconds: 400),
        const Duration(milliseconds: 500),
      ];

      final percentiles = LatencyPercentiles.fromDurations(durations);
      expect(percentiles.p50Ms, 300.0);
      expect(percentiles.minMs, 100.0);
      expect(percentiles.maxMs, 500.0);
      expect(percentiles.meanMs, 300.0);

      final json = percentiles.toJson();
      expect(json['p50Ms'], 300.0);
      expect(json['p90Ms'], 500.0);
    });
  });

  group('LowEndDeviceBufferProfile', () {
    test('provides tailored buffer bounds for low memory devices', () {
      final lowMem = LowEndDeviceBufferProfile.lowMemory();
      final standard = LowEndDeviceBufferProfile.standard();

      expect(lowMem.minBufferDuration.inSeconds, 12);
      expect(lowMem.estimatedHeapUsageKb, lessThan(standard.estimatedHeapUsageKb));
      expect(lowMem.bufferForPlaybackDuration.inMilliseconds, 1200);

      expect(standard.minBufferDuration.inSeconds, 30);
      expect(standard.estimatedHeapUsageKb, 15360);
    });
  });

  group('PlaybackBenchmarkMatrix Runner', () {
    const testSong = Song(
      id: 'test_track_1',
      title: 'Midnight Drive',
      artist: 'Synthwave Pilot',
      duration: Duration(minutes: 3, seconds: 45),
      thumbnails: Thumbnails(high: 'https://example.com/art.jpg'),
      source: MusicSource.youtube,
      youtubeId: 'yt_midnight_1',
    );

    late List<AudioStreamResolver> resolvers;
    late PlaybackReliabilityService reliabilityService;
    late PlaybackBenchmarkMatrix matrix;

    setUp(() {
      resolvers = [
        FakeStreamResolver(resolverName: 'jiosaavn', latency: const Duration(milliseconds: 10)),
        FakeStreamResolver(resolverName: 'youtube_explode', latency: const Duration(milliseconds: 15)),
        FakeStreamResolver(resolverName: 'piped', isAvailable: false),
        FakeStreamResolver(resolverName: 'invidious', shouldFail: true),
      ];
      reliabilityService = PlaybackReliabilityService(
        circuitBreakerThreshold: 3,
        circuitBreakerCooldown: const Duration(seconds: 10),
      );
      matrix = PlaybackBenchmarkMatrix(
        resolvers: resolvers,
        reliability: reliabilityService,
      );
    });

    test('benchmarks cold start and provider resolvers accurately', () async {
      final coldStart = await matrix.benchmarkColdStart(testSong: testSong, iterations: 3);
      expect(coldStart.p50Ms, greaterThan(0.0));
      expect(coldStart.p50Ms, lessThan(1000.0));

      final providerResults = await matrix.benchmarkProviders(testSong: testSong, runsPerProvider: 2);
      expect(providerResults.length, 4);

      final jioResult = providerResults.firstWhere((p) => p.providerName == 'jiosaavn');
      expect(jioResult.successRate, 1.0);
      expect(jioResult.isAvailable, true);

      final pipedResult = providerResults.firstWhere((p) => p.providerName == 'piped');
      expect(pipedResult.isAvailable, false);

      final invidiousResult = providerResults.firstWhere((p) => p.providerName == 'invidious');
      expect(invidiousResult.successRate, 0.0);
    });

    test('benchmarks unstable network scenarios and circuit breaker engagement', () async {
      final networkRes = await matrix.benchmarkNetworkResilience(testSong: testSong);

      expect(networkRes.highLatencyRecoveryRate, 1.0);
      expect(networkRes.circuitBreakerEngaged, true);
      expect(networkRes.circuitCooldownHint, contains('Playback is temporarily paused'));

      final json = networkRes.toJson();
      expect(json['circuitBreakerEngaged'], true);
    });

    test('runs full benchmark matrix and generates markdown report', () async {
      final report = await matrix.runFullMatrix(testSong: testSong, deviceMemoryMb: 2048);

      expect(report.coldStartLatency.p50Ms, greaterThan(0.0));
      expect(report.providerResults.isNotEmpty, true);
      expect(report.lowEndProfile.estimatedHeapUsageKb, 5120);
      expect(report.meetsReleaseSlo, isA<bool>());

      final md = report.toMarkdownSummary();
      expect(md, contains('Playback Performance Benchmark Matrix'));
      expect(md, contains('Cold Start Playback Latency'));
      expect(md, contains('Provider Resolution Breakdown'));
      expect(md, contains('Low-End Android Buffer Profile'));
    });

    test('DiagnosticsService integrates with playback benchmark matrix', () async {
      final diag = DiagnosticsService.instance;
      final report = await diag.runPlaybackBenchmark(testSong: testSong);

      expect(report.providerResults, isA<List<ProviderBenchmarkResult>>());
      expect(report.lowEndProfile, isA<LowEndDeviceBufferProfile>());
    });
  });
}
