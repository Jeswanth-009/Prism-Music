import 'dart:math' as math;

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

  static const MediaControl favoriteControl = MediaControl(
    androidIcon: 'drawable/ic_heart',
    label: 'Favorite',
    action: MediaAction.custom,
  );

  void _broadcastState(PlaybackEvent event) {
    final playing = player.playing;
    final coordinator = MediaSessionCoordinator.instance;
    final controls = <MediaControl>[
      if (coordinator.canSkipPrevious) MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      if (coordinator.canSkipNext) MediaControl.skipToNext,
      favoriteControl,
      MediaControl.fastForward,
      MediaControl.rewind,
      MediaControl.stop,
    ];

    // Compute compact action indices for lock screen: center on playback & skips.
    final compactActionIndices = <int>[];
    final prevIdx = controls.indexOf(MediaControl.skipToPrevious);
    final playIdx = controls.indexOf(playing ? MediaControl.pause : MediaControl.play);
    final nextIdx = controls.indexOf(MediaControl.skipToNext);
    if (prevIdx != -1) {
      compactActionIndices.add(prevIdx);
    } else {
      final favIdx = controls.indexOf(favoriteControl);
      if (favIdx != -1) compactActionIndices.add(favIdx);
    }
    if (playIdx != -1) compactActionIndices.add(playIdx);
    if (nextIdx != -1) compactActionIndices.add(nextIdx);

    playbackState.add(
      playbackState.value.copyWith(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.fastForward,
          MediaAction.rewind,
          MediaAction.setRepeatMode,
          MediaAction.setShuffleMode,
          MediaAction.custom,
          MediaAction.stop,
        },
        androidCompactActionIndices: compactActionIndices,
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

  @override
  Future<void> fastForward() async {
    final current = player.position;
    final total = player.duration;
    final target = current + const Duration(seconds: 10);
    if (total != null && target > total) {
      await player.seek(total);
    } else {
      await player.seek(target);
    }
  }

  @override
  Future<void> rewind() async {
    final current = player.position;
    final target = current - const Duration(seconds: 10);
    await player.seek(target < Duration.zero ? Duration.zero : target);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    await MediaSessionCoordinator.instance.cycleRepeatMode();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    await MediaSessionCoordinator.instance.toggleShuffle();
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'toggleLike' || name == 'favorite' || name == 'like') {
      await MediaSessionCoordinator.instance.toggleCurrentSongLike();
      return true;
    }
    return super.customAction(name, extras);
  }
}
