import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class PrismAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player;

  PrismAudioHandler(this.player) {
    // Broadcast player state to the system notification
    player.playbackEventStream.listen(_broadcastState);
    
    // Update notification metadata (title, artist, artwork)
    player.sequenceStateStream.listen((sequenceState) {
      if (sequenceState != null && sequenceState.currentSource != null) {
        final tag = sequenceState.currentSource!.tag;
        if (tag is MediaItem) {
          mediaItem.add(tag);
        }
      }
    });

    // Update queue metadata
    player.sequenceStream.listen((sequence) {
      if (sequence != null) {
        final items = sequence
            .where((s) => s.tag is MediaItem)
            .map((s) => s.tag as MediaItem)
            .toList();
        queue.add(items);
      }
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
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

  @override
  Future<void> play() => player.play();
  
  @override
  Future<void> pause() => player.pause();
  
  @override
  Future<void> stop() async {
    await player.stop();
    return super.stop();
  }
  
  @override
  Future<void> skipToNext() => player.seekToNext();
  
  @override
  Future<void> skipToPrevious() => player.seekToPrevious();
  
  @override
  Future<void> seek(Duration position) => player.seek(position);
}