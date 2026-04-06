/// Circuit-breaker + retry policy for playback errors.
class PlaybackReliabilityService {
  final int maxRetriesPerSong;
  final int circuitBreakerThreshold;
  final Duration circuitBreakerCooldown;

  final Map<String, int> _retryAttemptsBySong = {};
  int _consecutiveFailures = 0;
  DateTime? _circuitOpenedAt;

  PlaybackReliabilityService({
    this.maxRetriesPerSong = 2,
    this.circuitBreakerThreshold = 3,
    this.circuitBreakerCooldown = const Duration(seconds: 25),
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
    final seconds = left.inSeconds.clamp(1, circuitBreakerCooldown.inSeconds);
    return 'Playback is temporarily paused after repeated failures. Try again in ${seconds}s.';
  }
}
