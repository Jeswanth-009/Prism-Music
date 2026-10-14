import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/instance_health_service.dart';

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
  });
}
