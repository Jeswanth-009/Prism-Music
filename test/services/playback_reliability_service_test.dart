import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/playback_reliability_service.dart';

void main() {
  group('PlaybackReliabilityService - Song Retry & Global Breaker', () {
    late PlaybackReliabilityService service;

    setUp(() {
      service = PlaybackReliabilityService(
        maxRetriesPerSong: 3,
        circuitBreakerThreshold: 3,
        circuitBreakerCooldown: const Duration(milliseconds: 100),
      );
    });

    test('increments retry attempts and calculates exponential backoff', () {
      expect(service.attemptsForSong('song_1'), 0);
      expect(service.shouldRetry('song_1', isOffline: false), isTrue);

      service.registerRetry('song_1');
      expect(service.attemptsForSong('song_1'), 1);
      expect(service.nextRetryDelay('song_1').inMilliseconds, 1000);

      service.registerRetry('song_1');
      expect(service.attemptsForSong('song_1'), 2);
      expect(service.nextRetryDelay('song_1').inMilliseconds, 2000);

      service.registerRetry('song_1');
      expect(service.attemptsForSong('song_1'), 3);
      expect(service.shouldRetry('song_1', isOffline: false), isFalse);
    });

    test('prevents retry when offline', () {
      expect(service.shouldRetry('song_1', isOffline: true), isFalse);
    });

    test('trips global circuit breaker after threshold consecutive failures', () async {
      expect(service.isCircuitOpen, isFalse);

      service.registerFailure('song_1');
      service.registerFailure('song_2');
      expect(service.isCircuitOpen, isFalse);

      service.registerFailure('song_3');
      expect(service.isCircuitOpen, isTrue);
      expect(service.cooldownHint(), contains('temporarily paused'));

      // Wait for cooldown to expire
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(service.isCircuitOpen, isFalse);
    });

    test('registerSuccess clears attempts and resets failure counter', () {
      service.registerRetry('song_1');
      service.registerFailure('song_1');
      expect(service.attemptsForSong('song_1'), 1);

      service.registerSuccess('song_1');
      expect(service.attemptsForSong('song_1'), 0);
      expect(service.isCircuitOpen, isFalse);
    });
  });

  group('PlaybackReliabilityService - Source Circuit Breaker', () {
    late PlaybackReliabilityService service;

    setUp(() {
      service = PlaybackReliabilityService(
        sourceCircuitErrorThreshold: 3,
        sourceCircuitCooldownDuration: const Duration(milliseconds: 80),
      );
    });

    test('trips source breaker after reaching threshold consecutive errors', () async {
      expect(service.isSourceCircuitOpen(StreamSource.jioSaavn), isFalse);
      expect(service.getSourceConsecutiveErrors(StreamSource.jioSaavn), 0);

      service.recordSourceFailure(StreamSource.jioSaavn);
      expect(service.getSourceConsecutiveErrors(StreamSource.jioSaavn), 1);
      expect(service.isSourceCircuitOpen(StreamSource.jioSaavn), isFalse);

      service.recordSourceFailure(StreamSource.jioSaavn);
      expect(service.getSourceConsecutiveErrors(StreamSource.jioSaavn), 2);
      expect(service.isSourceCircuitOpen(StreamSource.jioSaavn), isFalse);

      // Third failure trips breaker
      service.recordSourceFailure(StreamSource.jioSaavn);
      expect(service.getSourceConsecutiveErrors(StreamSource.jioSaavn), 3);
      expect(service.isSourceCircuitOpen(StreamSource.jioSaavn), isTrue);
      expect(service.getSourceCooldownUntil(StreamSource.jioSaavn), isNotNull);

      // Other sources remain unaffected
      expect(service.isSourceCircuitOpen(StreamSource.youtubeExplode), isFalse);

      // Wait for cooldown expiration
      await Future<void>.delayed(const Duration(milliseconds: 95));
      expect(service.isSourceCircuitOpen(StreamSource.jioSaavn), isFalse);
      expect(service.getSourceConsecutiveErrors(StreamSource.jioSaavn), 0);
    });

    test('recordSourceSuccess resets failure count and clears cooldown', () {
      service.recordSourceFailure(StreamSource.jioSaavn);
      service.recordSourceFailure(StreamSource.jioSaavn);
      service.recordSourceFailure(StreamSource.jioSaavn);
      expect(service.isSourceCircuitOpen(StreamSource.jioSaavn), isTrue);

      service.recordSourceSuccess(StreamSource.jioSaavn);
      expect(service.isSourceCircuitOpen(StreamSource.jioSaavn), isFalse);
      expect(service.getSourceConsecutiveErrors(StreamSource.jioSaavn), 0);
    });

    test('resetSourceCircuitBreaker clears specific or all source cooldowns', () {
      service.recordSourceFailure(StreamSource.jioSaavn);
      service.recordSourceFailure(StreamSource.jioSaavn);
      service.recordSourceFailure(StreamSource.jioSaavn);

      service.recordSourceFailure(StreamSource.invidious);
      service.recordSourceFailure(StreamSource.invidious);
      service.recordSourceFailure(StreamSource.invidious);

      expect(service.isSourceCircuitOpen(StreamSource.jioSaavn), isTrue);
      expect(service.isSourceCircuitOpen(StreamSource.invidious), isTrue);

      // Reset only JioSaavn
      service.resetSourceCircuitBreaker(StreamSource.jioSaavn);
      expect(service.isSourceCircuitOpen(StreamSource.jioSaavn), isFalse);
      expect(service.isSourceCircuitOpen(StreamSource.invidious), isTrue);

      // Reset all
      service.resetSourceCircuitBreaker();
      expect(service.isSourceCircuitOpen(StreamSource.invidious), isFalse);
    });
  });
}
