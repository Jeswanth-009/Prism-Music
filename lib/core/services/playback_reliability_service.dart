/// Audio stream source types tracked for circuit breaking.
enum StreamSource { jioSaavn, youtubeExplode, invidious, alternative }

/// Circuit-breaker + retry policy for playback errors and provider sources.
class PlaybackReliabilityService {
  final int maxRetriesPerSong;
  final int circuitBreakerThreshold;
  final Duration circuitBreakerCooldown;

  // Source-level circuit breaker settings
  final int sourceCircuitErrorThreshold;
  final Duration sourceCircuitCooldownDuration;

  final Map<String, int> _retryAttemptsBySong = {};
  int _consecutiveFailures = 0;
  DateTime? _circuitOpenedAt;

  // Per-source circuit breaker state
  final Map<StreamSource, DateTime> _sourceCircuitCooldownUntil = {};
  final Map<StreamSource, int> _sourceConsecutiveErrors = {};

  PlaybackReliabilityService({
    this.maxRetriesPerSong = 2,
    this.circuitBreakerThreshold = 5,
    this.circuitBreakerCooldown = const Duration(seconds: 25),
    this.sourceCircuitErrorThreshold = 3,
    this.sourceCircuitCooldownDuration = const Duration(seconds: 30),
  });

  bool get isCircuitOpen {
    final opened = _circuitOpenedAt;
    if (opened == null) return false;
    final stillCooling = DateTime.now().difference(opened) < circuitBreakerCooldown;
    if (!stillCooling) {
      _circuitOpenedAt = null;
      _consecutiveFailures = 0;
      _retryAttemptsBySong.clear();
      return false;
    }
    return true;
  }

  int attemptsForSong(String songId) => _retryAttemptsBySong[songId] ?? 0;

  bool shouldRetry(String songId, {required bool isOffline}) {
    if (isOffline || isCircuitOpen) return false;
    final attempts = attemptsForSong(songId);
    return attempts < maxRetriesPerSong;
  }

  Duration nextRetryDelay(String songId) {
    final attempt = attemptsForSong(songId) + 1;
    final base = 500 * (1 << (attempt - 1));
    final ms = base.clamp(500, 4000);
    return Duration(milliseconds: ms);
  }

  void registerRetry(String songId) {
    _retryAttemptsBySong[songId] = attemptsForSong(songId) + 1;
  }

  void registerFailure(String songId) {
    _consecutiveFailures += 1;
    if (_consecutiveFailures >= circuitBreakerThreshold) {
      _circuitOpenedAt = DateTime.now();
    }
  }

  void registerSuccess(String songId) {
    _retryAttemptsBySong.remove(songId);
    _consecutiveFailures = 0;
    _circuitOpenedAt = null;
  }

  void resetCircuitBreaker() {
    _consecutiveFailures = 0;
    _circuitOpenedAt = null;
    _retryAttemptsBySong.clear();
  }

  String cooldownHint() {
    final opened = _circuitOpenedAt;
    if (opened == null) return 'Please try again.';
    final elapsed = DateTime.now().difference(opened);
    final left = circuitBreakerCooldown - elapsed;
    final maxSec = circuitBreakerCooldown.inSeconds <= 1
        ? 1
        : circuitBreakerCooldown.inSeconds;
    final seconds = left.inSeconds.clamp(1, maxSec);
    return 'Playback is temporarily paused after repeated failures. Try again in ${seconds}s.';
  }

  // ---------------------------------------------------------------------------
  // Per-Source Circuit Breaker Logic (Consolidated from StreamLoaderService)
  // ---------------------------------------------------------------------------

  bool isSourceCircuitOpen(StreamSource source) {
    final cooldownUntil = _sourceCircuitCooldownUntil[source];
    if (cooldownUntil == null) return false;
    if (DateTime.now().isAfter(cooldownUntil)) {
      _sourceCircuitCooldownUntil.remove(source);
      _sourceConsecutiveErrors[source] = 0;
      return false;
    }
    return true;
  }

  void recordSourceSuccess(StreamSource source) {
    _sourceConsecutiveErrors[source] = 0;
    _sourceCircuitCooldownUntil.remove(source);
  }

  void recordSourceFailure(StreamSource source) {
    final count = (_sourceConsecutiveErrors[source] ?? 0) + 1;
    _sourceConsecutiveErrors[source] = count;
    if (count >= sourceCircuitErrorThreshold) {
      _sourceCircuitCooldownUntil[source] =
          DateTime.now().add(sourceCircuitCooldownDuration);
    }
  }

  void resetSourceCircuitBreaker([StreamSource? source]) {
    if (source != null) {
      _sourceConsecutiveErrors.remove(source);
      _sourceCircuitCooldownUntil.remove(source);
    } else {
      _sourceConsecutiveErrors.clear();
      _sourceCircuitCooldownUntil.clear();
    }
  }

  int getSourceConsecutiveErrors(StreamSource source) =>
      _sourceConsecutiveErrors[source] ?? 0;

  DateTime? getSourceCooldownUntil(StreamSource source) =>
      _sourceCircuitCooldownUntil[source];

  Duration? getSourceCooldownRemaining(StreamSource source) {
    final until = _sourceCircuitCooldownUntil[source];
    if (until == null) return null;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }
}
