import 'package:equatable/equatable.dart';
import '../../../domain/entities/entities.dart';
import 'player_event.dart';

/// Player state status
enum PlayerStatus {
  initial,
  loading,
  ready,
  playing,
  paused,
  buffering,
  completed,
  error,
}

/// Represents the complete player state
class PlayerState extends Equatable {
  /// Current status of the player
  final PlayerStatus status;

  /// Currently playing song
  final Song? currentSong;

  /// Current playback position
  final Duration position;

  /// Buffered position
  final Duration bufferedPosition;

  /// Total duration of current song
  final Duration duration;

  /// Current volume (0.0 to 1.0)
  final double volume;

  /// Whether audio is muted
  final bool isMuted;

  /// Whether shuffle is enabled
  final bool isShuffleEnabled;

  /// Current repeat mode
  final RepeatMode repeatMode;

  /// Playback speed
  final double playbackSpeed;

  /// Current audio quality
  final AudioQuality audioQuality;

  /// Queue of songs
  final List<Song> queue;

  /// Original queue (before shuffle)
  final List<Song> originalQueue;

  /// Current index in queue
  final int queueIndex;

  /// Error message if status is error
  final String? errorMessage;

  const PlayerState({
    this.status = PlayerStatus.initial,
    this.currentSong,
    this.position = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.isMuted = false,
    this.isShuffleEnabled = false,
    this.repeatMode = RepeatMode.off,
    this.playbackSpeed = 1.0,
    this.audioQuality = AudioQuality.medium,
    this.queue = const [],
    this.originalQueue = const [],
    this.queueIndex = 0,
    this.errorMessage,
  });

  /// Whether the player is currently playing
  bool get isPlaying => status == PlayerStatus.playing;

  /// Whether the player is buffering
  bool get isBuffering => status == PlayerStatus.buffering;

  /// Whether the player is loading/buffering
  bool get isLoading =>
      status == PlayerStatus.loading || status == PlayerStatus.buffering;

  /// Whether there's a next song in queue
  bool get hasNext => queueIndex < queue.length - 1;

  /// Whether there's a previous song in queue
  bool get hasPrevious => queueIndex > 0;

  /// Progress as percentage (0.0 to 1.0)
  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return position.inMilliseconds / duration.inMilliseconds;
  }

  /// Buffered progress as percentage (0.0 to 1.0)
  double get bufferedProgress {
    if (duration.inMilliseconds == 0) return 0.0;
    return bufferedPosition.inMilliseconds / duration.inMilliseconds;
  }

  /// Remaining time
  Duration get remaining => duration - position;

  /// Formatted position string (MM:SS)
  String get positionFormatted => _formatDuration(position);

  /// Formatted duration string (MM:SS)
  String get durationFormatted => _formatDuration(duration);

  /// Formatted remaining time string (MM:SS)
  String get remainingFormatted => _formatDuration(remaining);

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  PlayerState copyWith({
    PlayerStatus? status,
    Song? currentSong,
    Duration? position,
    Duration? bufferedPosition,
    Duration? duration,
    double? volume,
    bool? isMuted,
    bool? isShuffleEnabled,
    RepeatMode? repeatMode,
    double? playbackSpeed,
    AudioQuality? audioQuality,
    List<Song>? queue,
    List<Song>? originalQueue,
    int? queueIndex,
    String? errorMessage,
  }) {
    return PlayerState(
      status: status ?? this.status,
      currentSong: currentSong ?? this.currentSong,
      position: position ?? this.position,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      isShuffleEnabled: isShuffleEnabled ?? this.isShuffleEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      audioQuality: audioQuality ?? this.audioQuality,
      queue: queue ?? this.queue,
      originalQueue: originalQueue ?? this.originalQueue,
      queueIndex: queueIndex ?? this.queueIndex,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentSong,
        position,
        bufferedPosition,
        duration,
        volume,
        isMuted,
        isShuffleEnabled,
        repeatMode,
        playbackSpeed,
        audioQuality,
        queue,
        originalQueue,
        queueIndex,
        errorMessage,
      ];
}
