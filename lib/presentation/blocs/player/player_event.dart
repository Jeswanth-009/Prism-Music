import 'package:equatable/equatable.dart';
import '../../../domain/entities/entities.dart';

/// Base class for all player events
abstract class PlayerEvent extends Equatable {
  const PlayerEvent();

  @override
  List<Object?> get props => [];
}

/// Play a specific song
class PlaySongEvent extends PlayerEvent {
  final Song song;
  final List<Song>? queue;
  final int? queueIndex;

  const PlaySongEvent({
    required this.song,
    this.queue,
    this.queueIndex,
  });

  @override
  List<Object?> get props => [song, queue, queueIndex];
}

/// Play/Resume current song
class ResumeEvent extends PlayerEvent {
  const ResumeEvent();
}

/// Pause current song
class PauseEvent extends PlayerEvent {
  const PauseEvent();
}

/// Toggle play/pause
class TogglePlayPauseEvent extends PlayerEvent {
  const TogglePlayPauseEvent();
}

/// Skip to next song
class NextEvent extends PlayerEvent {
  const NextEvent();
}

/// Skip to previous song
class PreviousEvent extends PlayerEvent {
  const PreviousEvent();
}

/// Seek to a specific position
class SeekEvent extends PlayerEvent {
  final Duration position;

  const SeekEvent(this.position);

  @override
  List<Object?> get props => [position];
}

/// Set volume level (0.0 to 1.0)
class SetVolumeEvent extends PlayerEvent {
  final double volume;

  const SetVolumeEvent(this.volume);

  @override
  List<Object?> get props => [volume];
}

/// Toggle mute
class ToggleMuteEvent extends PlayerEvent {
  const ToggleMuteEvent();
}

/// Set shuffle mode
class SetShuffleEvent extends PlayerEvent {
  final bool enabled;

  const SetShuffleEvent(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

/// Toggle shuffle mode
class ToggleShuffleEvent extends PlayerEvent {
  const ToggleShuffleEvent();
}

/// Set repeat mode
class SetRepeatModeEvent extends PlayerEvent {
  final RepeatMode mode;

  const SetRepeatModeEvent(this.mode);

  @override
  List<Object?> get props => [mode];
}

/// Cycle through repeat modes
class CycleRepeatModeEvent extends PlayerEvent {
  const CycleRepeatModeEvent();
}

/// Add song to queue
class AddToQueueEvent extends PlayerEvent {
  final Song song;
  final bool playNext;

  const AddToQueueEvent({
    required this.song,
    this.playNext = false,
  });

  @override
  List<Object?> get props => [song, playNext];
}

/// Remove song from queue
class RemoveFromQueueEvent extends PlayerEvent {
  final int index;

  const RemoveFromQueueEvent(this.index);

  @override
  List<Object?> get props => [index];
}

/// Reorder queue
class ReorderQueueEvent extends PlayerEvent {
  final int oldIndex;
  final int newIndex;

  const ReorderQueueEvent({
    required this.oldIndex,
    required this.newIndex,
  });

  @override
  List<Object?> get props => [oldIndex, newIndex];
}

/// Clear queue
class ClearQueueEvent extends PlayerEvent {
  const ClearQueueEvent();
}

/// Set playback speed
class SetPlaybackSpeedEvent extends PlayerEvent {
  final double speed;

  const SetPlaybackSpeedEvent(this.speed);

  @override
  List<Object?> get props => [speed];
}

/// Set audio quality preference
class SetAudioQualityEvent extends PlayerEvent {
  final AudioQuality quality;

  const SetAudioQualityEvent(this.quality);

  @override
  List<Object?> get props => [quality];
}

/// Stop playback completely
class StopEvent extends PlayerEvent {
  const StopEvent();
}

/// Download a song
class DownloadSongEvent extends PlayerEvent {
  final Song song;

  const DownloadSongEvent(this.song);

  @override
  List<Object?> get props => [song];
}

/// Internal event: position update from player
class PositionUpdateEvent extends PlayerEvent {
  final Duration position;

  const PositionUpdateEvent(this.position);

  @override
  List<Object?> get props => [position];
}

/// Internal event: buffered position update
class BufferedPositionUpdateEvent extends PlayerEvent {
  final Duration bufferedPosition;

  const BufferedPositionUpdateEvent(this.bufferedPosition);

  @override
  List<Object?> get props => [bufferedPosition];
}

/// Internal event: duration update
class DurationUpdateEvent extends PlayerEvent {
  final Duration duration;

  const DurationUpdateEvent(this.duration);

  @override
  List<Object?> get props => [duration];
}

/// Internal event: player state change
class PlayerStateChangedEvent extends PlayerEvent {
  final bool isPlaying;

  const PlayerStateChangedEvent(this.isPlaying);

  @override
  List<Object?> get props => [isPlaying];
}

/// Internal event: error occurred
class PlayerErrorEvent extends PlayerEvent {
  final String message;

  const PlayerErrorEvent(this.message);

  @override
  List<Object?> get props => [message];
}

/// Repeat mode options
enum RepeatMode {
  off,
  all,
  one,
}
