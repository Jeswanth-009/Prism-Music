import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/audio_focus_orchestrator_service.dart';
import '../../../core/services/audio_player_service.dart';
import '../../../core/services/download_service.dart';
import '../../../core/services/media_resolver_service.dart';
import '../../../core/services/playback_reliability_service.dart';
import '../../../core/services/recommendation_service.dart';
import '../../../core/services/stream_loader_service.dart';
import '../../../core/services/verified_recording_verifier.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/repositories.dart';
import 'mixins/scrobble_mixin.dart';
import 'mixins/sleep_timer_mixin.dart';
import 'player_event.dart';
import 'player_state.dart';

/// Represents playback state in isolation.
class PlaybackState extends Equatable {
  final PlayerStatus status;
  final Song? currentSong;
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  final double volume;
  final bool isMuted;
  final double playbackSpeed;
  final AudioQuality audioQuality;
  final StreamInfo? currentStreamInfo;
  final String? errorMessage;
  final DateTime? sleepTimerEnd;
  final bool sleepTimerEndOfTrack;

  const PlaybackState({
    this.status = PlayerStatus.initial,
    this.currentSong,
    this.position = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.isMuted = false,
    this.playbackSpeed = 1.0,
    this.audioQuality = AudioQuality.medium,
    this.currentStreamInfo,
    this.errorMessage,
    this.sleepTimerEnd,
    this.sleepTimerEndOfTrack = false,
  });

  bool get isPlaying => status == PlayerStatus.playing;
  bool get isBuffering => status == PlayerStatus.buffering;
  bool get hasActiveSleepTimer => sleepTimerEnd != null || sleepTimerEndOfTrack;

  PlaybackState copyWith({
    PlayerStatus? status,
    Song? currentSong,
    Duration? position,
    Duration? bufferedPosition,
    Duration? duration,
    double? volume,
    bool? isMuted,
    double? playbackSpeed,
    AudioQuality? audioQuality,
    StreamInfo? currentStreamInfo,
    String? errorMessage,
    DateTime? sleepTimerEnd,
    bool clearSleepTimer = false,
    bool? sleepTimerEndOfTrack,
  }) {
    return PlaybackState(
      status: status ?? this.status,
      currentSong: currentSong ?? this.currentSong,
      position: position ?? this.position,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      audioQuality: audioQuality ?? this.audioQuality,
      currentStreamInfo: currentStreamInfo ?? this.currentStreamInfo,
      errorMessage: errorMessage,
      sleepTimerEnd: clearSleepTimer ? null : (sleepTimerEnd ?? this.sleepTimerEnd),
      sleepTimerEndOfTrack: clearSleepTimer ? false : (sleepTimerEndOfTrack ?? this.sleepTimerEndOfTrack),
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
        playbackSpeed,
        audioQuality,
        currentStreamInfo,
        errorMessage,
        sleepTimerEnd,
        sleepTimerEndOfTrack,
      ];
}

/// Standalone BLoC for audio playback pipeline, stream events, seeking, volume, and sleep timer.
class PlaybackBloc extends Bloc<PlayerEvent, PlaybackState>
    with SleepTimerMixin, ScrobbleMixin {
  final MusicRepository _musicRepository;
  final LibraryRepository _libraryRepository;
  final AudioPlayerService _audioPlayer;
  final AudioFocusOrchestratorService _audioFocus;
  final MediaResolverService _mediaResolver;
  final PlaybackReliabilityService _reliability;
  final StreamLoaderService _streamLoader;
  final DownloadService _downloadService;
  final RecommendationService? _recommendationService;

  MusicRepository get musicRepository => _musicRepository;
  MediaResolverService get mediaResolver => _mediaResolver;
  AudioPlayerService get audioPlayer => _audioPlayer;
  PlaybackReliabilityService get reliability => _reliability;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _bufferedSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<bool>? _bufferingSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<bool>? _completedSubscription;

  PlaybackBloc({
    required MusicRepository musicRepository,
    required LibraryRepository libraryRepository,
    required AudioPlayerService audioPlayerService,
    required AudioFocusOrchestratorService audioFocus,
    required MediaResolverService mediaResolver,
    required PlaybackReliabilityService reliability,
    required StreamLoaderService streamLoader,
    required DownloadService downloadService,
    RecommendationService? recommendationService,
  })  : _musicRepository = musicRepository,
        _libraryRepository = libraryRepository,
        _audioPlayer = audioPlayerService,
        _audioFocus = audioFocus,
        _mediaResolver = mediaResolver,
        _reliability = reliability,
        _streamLoader = streamLoader,
        _downloadService = downloadService,
        _recommendationService = recommendationService,
        super(const PlaybackState()) {
    on<ResumeEvent>(_onResume);
    on<PauseEvent>(_onPause);
    on<TogglePlayPauseEvent>(_onTogglePlayPause);
    on<SeekEvent>(_onSeek);
    on<SetVolumeEvent>(_onSetVolume);
    on<ToggleMuteEvent>(_onToggleMute);
    on<SetPlaybackSpeedEvent>(_onSetPlaybackSpeed);
    on<SetAudioQualityEvent>(_onSetAudioQuality);
    on<StopEvent>(_onStop);
    on<DownloadSongEvent>(_onDownloadSong);
    on<SetSleepTimerEvent>(_onSetSleepTimer);
    on<PositionUpdateEvent>(_onPositionUpdate);
    on<BufferedPositionUpdateEvent>(_onBufferedPositionUpdate);
    on<DurationUpdateEvent>(_onDurationUpdate);
    on<PlayerStateChangedEvent>(_onPlayerStateChanged);
    on<PlayerErrorEvent>(_onPlayerError);
    on<SwitchStreamSourceEvent>(_onSwitchStreamSource);

    _initAudioStreams();
  }

  void _initAudioStreams() {
    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      add(PositionUpdateEvent(position));
    });
    _bufferedSubscription = _audioPlayer.bufferedPositionStream.listen((buffered) {
      add(BufferedPositionUpdateEvent(buffered));
    });
    _durationSubscription = _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        add(DurationUpdateEvent(duration));
      }
    });
    _playingSubscription = _audioPlayer.playingStream.listen((playing) {
      add(PlayerStateChangedEvent(playing));
    });
    _errorSubscription = _audioPlayer.errorStream.listen((error) {
      add(PlayerErrorEvent(error));
    });
  }

  Future<void> _onResume(ResumeEvent event, Emitter<PlaybackState> emit) async {
    _audioFocus.notifyUserPaused(false);
    final focusGranted = await _audioFocus.activateForPlayback();
    if (!focusGranted) {
      emit(state.copyWith(
        status: PlayerStatus.error,
        errorMessage: 'Audio focus denied. Cannot resume playback.',
      ));
      return;
    }
    await _audioPlayer.play();
    emit(state.copyWith(status: PlayerStatus.playing));
  }

  Future<void> _onPause(PauseEvent event, Emitter<PlaybackState> emit) async {
    _audioFocus.notifyUserPaused(true);
    await _audioPlayer.pause();
    emit(state.copyWith(status: PlayerStatus.paused));
  }

  Future<void> _onTogglePlayPause(
    TogglePlayPauseEvent event,
    Emitter<PlaybackState> emit,
  ) async {
    if (state.isPlaying) {
      add(const PauseEvent());
    } else {
      add(const ResumeEvent());
    }
  }

  Future<void> _onSeek(SeekEvent event, Emitter<PlaybackState> emit) async {
    await _audioPlayer.seek(event.position);
    emit(state.copyWith(position: event.position));
  }

  Future<void> _onSetVolume(SetVolumeEvent event, Emitter<PlaybackState> emit) async {
    final vol = event.volume.clamp(0.0, 1.0);
    await _audioPlayer.setVolume(vol);
    emit(state.copyWith(volume: vol, isMuted: false));
  }

  Future<void> _onToggleMute(ToggleMuteEvent event, Emitter<PlaybackState> emit) async {
    final newMuted = !state.isMuted;
    await _audioPlayer.setVolume(newMuted ? 0 : state.volume);
    emit(state.copyWith(isMuted: newMuted));
  }

  Future<void> _onSetPlaybackSpeed(
    SetPlaybackSpeedEvent event,
    Emitter<PlaybackState> emit,
  ) async {
    await _audioPlayer.setSpeed(event.speed);
    emit(state.copyWith(playbackSpeed: event.speed));
  }

  void _onSetAudioQuality(SetAudioQualityEvent event, Emitter<PlaybackState> emit) {
    emit(state.copyWith(audioQuality: event.quality));
  }

  Future<void> _onStop(StopEvent event, Emitter<PlaybackState> emit) async {
    cancelSleepTimer();
    _audioFocus.notifyUserPaused(true);
    await _audioPlayer.stop();
    emit(const PlaybackState());
  }

  Future<void> _onDownloadSong(DownloadSongEvent event, Emitter<PlaybackState> emit) async {
    _reliability.resetCircuitBreaker();
    await _downloadService.downloadSong(event.song);
  }

  void _onSetSleepTimer(SetSleepTimerEvent event, Emitter<PlaybackState> emit) {
    cancelSleepTimer();

    if (event.endOfTrack) {
      emit(state.copyWith(sleepTimerEndOfTrack: true, clearSleepTimer: true));
      return;
    }

    final duration = event.duration;
    if (duration == null || duration <= Duration.zero) {
      emit(state.copyWith(clearSleepTimer: true, sleepTimerEndOfTrack: false));
      return;
    }

    final targetTime = DateTime.now().add(duration);
    emit(state.copyWith(sleepTimerEnd: targetTime, sleepTimerEndOfTrack: false));

    startSleepTimer(duration, onElapsed: () {
      unawaited(_audioPlayer.pause());
      if (!isClosed) {
        emit(state.copyWith(
          clearSleepTimer: true,
          sleepTimerEndOfTrack: false,
          status: PlayerStatus.paused,
        ));
      }
    });
  }

  void _onPositionUpdate(PositionUpdateEvent event, Emitter<PlaybackState> emit) {
    emit(state.copyWith(position: event.position));
    final song = state.currentSong;
    if (song != null) {
      if (state.duration.inSeconds > 0) {
        attemptScrobble(song, event.position, state.duration);
      }
      attemptRecordListeningSession(
        song: song,
        position: event.position,
        duration: state.duration,
        libraryRepository: _libraryRepository,
        recommendationService: _recommendationService,
      );
    }
  }

  void _onBufferedPositionUpdate(
    BufferedPositionUpdateEvent event,
    Emitter<PlaybackState> emit,
  ) {
    emit(state.copyWith(bufferedPosition: event.bufferedPosition));
  }

  void _onDurationUpdate(DurationUpdateEvent event, Emitter<PlaybackState> emit) {
    emit(state.copyWith(duration: event.duration));
  }

  void _onPlayerStateChanged(
    PlayerStateChangedEvent event,
    Emitter<PlaybackState> emit,
  ) {
    emit(state.copyWith(
      status: event.isPlaying ? PlayerStatus.playing : PlayerStatus.paused,
    ));
  }

  void _onPlayerError(PlayerErrorEvent event, Emitter<PlaybackState> emit) {
    emit(state.copyWith(
      status: PlayerStatus.error,
      errorMessage: event.message,
    ));
  }

  Future<void> _onSwitchStreamSource(
    SwitchStreamSourceEvent event,
    Emitter<PlaybackState> emit,
  ) async {
    final song = state.currentSong;
    if (song == null) return;

    try {
      final candidateStream = await _streamLoader.resolveCandidateStream(
        song,
        event.targetResolverName,
        preferredQuality: state.audioQuality,
      );

      if (candidateStream == null) {
        emit(state.copyWith(
          errorMessage: 'Unable to resolve audio stream from ${event.targetResolverName}',
        ));
        return;
      }

      final verification = VerifiedRecordingVerifier.verify(
        referenceSong: song,
        candidateStream: candidateStream,
      );

      if (!verification.isVerified) {
        emit(state.copyWith(
          errorMessage: 'Cannot switch source: ${verification.reason}',
        ));
        return;
      }

      final success = await _audioPlayer.switchStreamSource(
        candidateStream,
        song: song,
      );

      if (success) {
        emit(state.copyWith(
          currentStreamInfo: candidateStream,
          errorMessage: null,
        ));
      } else {
        emit(state.copyWith(
          errorMessage: 'Failed to switch player pipeline to ${event.targetResolverName}',
        ));
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Source switch error: $e'));
    }
  }

  @override
  Future<void> close() async {
    cancelSleepTimer();
    await _positionSubscription?.cancel();
    await _bufferedSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _playingSubscription?.cancel();
    await _bufferingSubscription?.cancel();
    await _completedSubscription?.cancel();
    await _errorSubscription?.cancel();
    await super.close();
  }
}
