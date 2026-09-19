import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'media_session_coordinator.dart';

/// audio_service handler producing the system media notification.
///
/// The underlying player is always in single-track mode (the PlayerBloc starts
/// a new source per song), so next/previous/stop are routed through
/// [MediaSessionCoordinator] into the bloc's queue logic instead of the
/// player's own (no-op) seekToNext/seekToPrevious.
class PrismAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player;

  PrismAudioHandler(this.player) {
    // Broadcast player state to the system notification
    player.playbackEventStream.listen(_broadcastState);

    // Update notification metadata (title, artist, artwork)
    player.sequenceStateStream.listen((sequenceState) {
      if (sequenceState.currentSource != null) {
        final tag = sequenceState.currentSource!.tag;
        if (tag is MediaItem) {
          mediaItem.add(tag);
          // Re-broadcast so the control buttons re-render for the new
          // track's position in the queue (e.g. previous becomes usable).
          _broadcastState(player.playbackEvent);
        }
      }
    });

    // Update queue metadata
    player.sequenceStream.listen((sequence) {
      final items = sequence
          .where((s) => s.tag is MediaItem)
          .map((s) => s.tag as MediaItem)
          .toList();
      queue.add(items);
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = player.playing;
    final coordinator = MediaSessionCoordinator.instance;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          // Only offer skips the real queue can satisfy, so buttons never
          // appear on the card while doing nothing.
          if (coordinator.canSkipPrevious) MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          if (coordinator.canSkipNext) MediaControl.skipToNext,
          MediaControl.stop, // Adds the X (Close) button when expanded
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.stop, // Required for Android 13+ to recognize the stop action
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[player.processingState]!,
        playing: playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: event.currentIndex,
      ),
    );
  }

  /// Re-render the notification's controls after queue enablement changed.
  void refreshNotificationState() {
    _broadcastState(player.playbackEvent);
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() async {
    // The X on the notification means "close playback": let the bloc reset
    // its state (history, queue UI) instead of only stopping raw audio.
    await MediaSessionCoordinator.instance.stopFromNotification();
    return super.stop();
  }

  @override
  Future<void> skipToNext() => MediaSessionCoordinator.instance.skipNext();

  @override
  Future<void> skipToPrevious() =>
      MediaSessionCoordinator.instance.skipPrevious();

  @override
  Future<void> seek(Duration position) => player.seek(position);
}
