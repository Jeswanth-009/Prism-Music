import 'prism_audio_handler.dart';

/// Bridge between the audio_service handler (system media notification) and
/// the PlayerBloc.
///
/// The real playback queue and advance logic live in [PlayerBloc], but the
/// media notification is driven by [PrismAudioHandler], which wraps a raw
/// just_audio player that only ever holds a single track. The two cannot
/// reference each other directly (the handler is created before the bloc and
/// the bloc has no import path to audio_service), so both register callbacks
/// here:
///
///   * `main.dart` attaches the handler after `AudioService.init`.
///   * The bloc binds next/previous/stop controls and queue enablement.
///   * The handler routes notification button presses through this class and
///     reads `canSkipNext` / `canSkipPrevious` to show only usable controls.
class MediaSessionCoordinator {
  MediaSessionCoordinator._();

  static final MediaSessionCoordinator instance = MediaSessionCoordinator._();

  PrismAudioHandler? _handler;

  Future<void> Function()? _onNext;
  Future<void> Function()? _onPrevious;
  Future<void> Function()? _onStop;
  bool Function()? _hasNext;
  bool Function()? _hasPrevious;

  /// Called once from main() after AudioService.init so the coordinator can
  /// ask the handler to re-render its controls when the queue changes.
  void attachHandler(PrismAudioHandler handler) {
    _handler = handler;
  }

  /// Called once when the PlayerBloc is created.
  void bindBloc({
    required Future<void> Function() onNext,
    required Future<void> Function() onPrevious,
    required Future<void> Function() onStop,
    required bool Function() hasNext,
    required bool Function() hasPrevious,
  }) {
    _onNext = onNext;
    _onPrevious = onPrevious;
    _onStop = onStop;
    _hasNext = hasNext;
    _hasPrevious = hasPrevious;
  }

  /// Whether the current queue position allows skipping forward — drives the
  /// next button's visibility in the notification.
  bool get canSkipNext => _hasNext?.call() ?? false;

  /// Whether the current queue position allows skipping back — drives the
  /// previous button's visibility in the notification.
  bool get canSkipPrevious => _hasPrevious?.call() ?? false;

  /// Notification "next" pressed → route to the bloc's queue logic.
  Future<void> skipNext() async {
    final callback = _onNext;
    if (callback != null) {
      await callback();
    }
  }

  /// Notification "previous" pressed → route to the bloc's queue logic.
  Future<void> skipPrevious() async {
    final callback = _onPrevious;
    if (callback != null) {
      await callback();
    }
  }

  /// Notification dismissed/closed → let the bloc stop playback cleanly.
  Future<void> stopFromNotification() async {
    final callback = _onStop;
    if (callback != null) {
      await callback();
    }
  }

  /// Notify the handler that queue contents/position changed so the
  /// notification's controls re-render (e.g. next becomes available after
  /// recommendations are appended).
  void notifyQueueChanged() {
    _handler?.refreshNotificationState();
  }
}
