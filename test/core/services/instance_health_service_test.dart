import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/instance_health_service.dart';

class _MockDioAdapter implements HttpClientAdapter {
  ResponseBody Function(RequestOptions options)? handler;

  _MockDioAdapter([this.handler]);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (handler != null) {
      return handler!(options);
    }
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('InstanceHealthService', () {
    late InstanceHealthService service;

    setUp(() {
      service = InstanceHealthService();
      service.resetQuarantines();
    });

    test('returns default healthy instances initially', () {
      final pipedApi = service.getHealthyPipedApi();
      final pipedProxy = service.getHealthyPipedProxy();
      final invidious = service.getHealthyInvidious();

      expect(InstanceHealthService.defaultPipedApiInstances.contains(pipedApi), isTrue);
      expect(InstanceHealthService.defaultPipedProxyInstances.contains(pipedProxy), isTrue);
      expect(InstanceHealthService.defaultInvidiousInstances.contains(invidious), isTrue);
    });

    test('quarantines instance after 2 consecutive failures', () {
      const host = 'https://pipedapi.kavin.rocks';

      expect(service.isHostQuarantined(host), isFalse);

      service.recordFailure(host, 'Timeout');
      expect(service.isHostQuarantined(host), isFalse);

      service.recordFailure(host, 'HTTP 502');
      expect(service.isHostQuarantined(host), isTrue);
    });

    test('promotes alternative healthy instance when primary is quarantined', () {
      final initial = service.getHealthyPipedApi();

      // Fail initial host twice to quarantine it
      service.recordFailure(initial, 'Timeout 1');
      service.recordFailure(initial, 'Timeout 2');

      final nextHost = service.getHealthyPipedApi();
      expect(nextHost, isNot(equals(initial)));
      expect(service.isHostQuarantined(nextHost), isFalse);
    });

    test('success resets failure count and clears quarantine', () {
      const host = 'https://inv.nadeko.net';

      service.recordFailure(host, 'Temporary 500');
      service.recordFailure(host, 'Temporary 500');
      expect(service.isHostQuarantined(host), isTrue);

      service.recordSuccess(host, const Duration(milliseconds: 300));
      expect(service.isHostQuarantined(host), isFalse);
    });

    test('prioritizes lowest latency instance among healthy candidates', () {
      final instances = InstanceHealthService.defaultPipedApiInstances;
      final fastHost = instances[1];
      final slowHost = instances[0];

      service.recordSuccess(slowHost, const Duration(milliseconds: 1800));
      service.recordSuccess(fastHost, const Duration(milliseconds: 250));

      final selected = service.getHealthyPipedApi();
      expect(selected, fastHost);
    });

    test('fails soft to earliest expiring instance when all instances quarantined', () {
      final pool = InstanceHealthService.defaultInvidiousInstances;

      for (final host in pool) {
        service.recordFailure(host, 'Down');
        service.recordFailure(host, 'Down');
      }

      // All are quarantined, but getHealthyInvidious should not throw
      final fallback = service.getHealthyInvidious();
      expect(pool.contains(fallback), isTrue);
    });

    test('resetQuarantines clears all quarantined hosts', () {
      const host = 'https://pipedapi.kavin.rocks';
      service.recordFailure(host, 'Err 1');
      service.recordFailure(host, 'Err 2');
      expect(service.isHostQuarantined(host), isTrue);

      service.resetQuarantines();
      expect(service.isHostQuarantined(host), isFalse);
    });

    test('adds instances dynamically to the pools and cleans trailing slashes', () {
      service.addInvidiousInstance('https://new-invidious.example.org///');
      expect(service.invidiousPool.contains('https://new-invidious.example.org'), isTrue);

      service.addPipedApiInstance('https://new-piped.example.org/');
      expect(service.pipedApiPool.contains('https://new-piped.example.org'), isTrue);

      service.addPipedProxyInstance('https://new-proxy.example.org');
      expect(service.pipedProxyPool.contains('https://new-proxy.example.org'), isTrue);
    });

    test('probeHost records success and latency on healthy response', () async {
      const host = 'https://healthy.invidious.org';
      final dio = Dio()..httpClientAdapter = _MockDioAdapter((options) {
        return ResponseBody.fromString('', 200);
      });

      await service.probeHost(host, dio: dio);

      final stats = service.getStats();
      final latencies = stats['latencies'] as Map<String, int>;
      final successCounts = stats['successCounts'] as Map<String, int>;

      expect(latencies.containsKey(host), isTrue);
      expect(successCounts[host], 1);
      expect(service.isHostQuarantined(host), isFalse);
    });

    test('probeHost records failure and quarantines on consecutive 502s', () async {
      const host = 'https://unhealthy.invidious.org';
      final dio = Dio()..httpClientAdapter = _MockDioAdapter((options) {
        return ResponseBody.fromString('', 502);
      });

      await service.probeHost(host, dio: dio);
      expect(service.isHostQuarantined(host), isFalse);

      await service.probeHost(host, dio: dio);
      expect(service.isHostQuarantined(host), isTrue);
    });

    test('startBackgroundHealthProbes executes non-blocking and handles failures gracefully', () async {
      final dio = Dio()..httpClientAdapter = _MockDioAdapter((options) {
        return ResponseBody.fromString('[]', 200);
      });

      // Should not block or throw
      service.startBackgroundHealthProbes(dio: dio);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.isProbingInProgress, isFalse);
    });
  });
}
