/// Thread-safe lightweight cancellation token for long-running asynchronous tasks
/// such as playlist importing or multi-track batch fetching.
class ImportCancellationToken {
  bool _isCancelled = false;

  /// Whether cancellation has been requested.
  bool get isCancelled => _isCancelled;

  /// Trigger cancellation.
  void cancel() {
    _isCancelled = true;
  }

  /// Reset the cancellation flag if reusing the token.
  void reset() {
    _isCancelled = false;
  }
}
