import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/audio_player_service.dart';
import '../../../core/services/lastfm_service.dart';
import '../../../core/services/media_session_coordinator.dart';
import '../../../core/services/recommendation_service.dart';
import '../../../core/services/audio_focus_orchestrator_service.dart';
import '../../../core/services/media_resolver_service.dart';
import '../../../core/services/playback_reliability_service.dart';
import '../../../core/services/stream_loader_service.dart';
import '../../../core/services/download_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/di/injection.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/repositories.dart';
import 'player_event.dart';
import 'player_state.dart';

/// BLoC for managing audio player state
class PlayerBloc extends Bloc<PlayerEvent, PlayerState>
    with WidgetsBindingObserver {
  final MusicRepository _musicRepository;
  final LibraryRepository _libraryRepository;
  final AudioPlayerService _audioPlayer;
  final AudioFocusOrchestratorService _audioFocus;
  final MediaResolverService _mediaResolver;
  final PlaybackReliabilityService _reliability;
  final StreamLoaderService _streamLoader;
  final DownloadService _downloadService;
  final SettingsService _settingsService = SettingsService.instance;
  bool _fastStartEnabled = true;
  int _prefetchLookahead = 1;
  double _crossfadeDurationSeconds = 0.0;
  int _lastNearEndPrefetchIndex = -1;
  Timer? _sleepTimer;
  final LastFmService _lastFmService = LastFmService();
  RecommendationService? _recommendationService;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _bufferedSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<bool>? _bufferingSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<bool>? _completedSubscription;
  StreamSubscription<int?>? _indexSubscription;

  // Scrobbling tracking
  bool _hasScrobbled = false;
  bool _hasUpdatedNowPlaying = false;
  AppLifecycleState _lastLifecycleState = AppLifecycleState.resumed;
  int _consecutiveFailureSkips = 0;

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  PlayerBloc({
    required MusicRepository musicRepository,
    required LibraryRepository libraryRepository,
    required AudioPlayerService audioPlayerService,
    required AudioFocusOrchestratorService audioFocus,
    required MediaResolverService mediaResolver,
    required PlaybackReliabilityService reliability,
    required StreamLoaderService streamLoader,
    required DownloadService downloadService,
    RecommendationService? recommendationService,
  }) : _musicRepository = musicRepository,
       _libraryRepository = libraryRepository,
       _audioPlayer = audioPlayerService,
       _audioFocus = audioFocus,
       _mediaResolver = mediaResolver,
       _reliability = reliability,
       _streamLoader = streamLoader,
       _downloadService = downloadService,
       _recommendationService = recommendationService,
       super(const PlayerState()) {
    if (_recommendationService == null &&
        getIt.isRegistered<RecommendationService>()) {
      _recommendationService = getIt<RecommendationService>();
    }

    // Expose queue controls to the media notification. The audio_service
    // handler's next/previous buttons call these closures, which read the
    // live bloc state — the notification therefore always reflects the real
    // queue (including appended recommendations).
    MediaSessionCoordinator.instance.bindBloc(
      onNext: () async {
        if (!isClosed) add(const NextEvent());
      },
      onPrevious: () async {
        if (!isClosed) add(const PreviousEvent());
      },
      onStop: () async {
        if (!isClosed) add(const StopEvent());
      },
      hasNext: () => !isClosed && state.hasNext,
      hasPrevious: () => !isClosed && state.hasPrevious,
    );

    // Register event handlers
    on<PlaySongEvent>(_onPlaySong);
    on<DownloadSongEvent>(_onDownloadSong);
    on<ResumeEvent>(_onResume);
    on<PauseEvent>(_onPause);
    on<TogglePlayPauseEvent>(_onTogglePlayPause);
    on<NextEvent>(_onNext);
    on<PreviousEvent>(_onPrevious);
    on<SeekEvent>(_onSeek);
    on<SetVolumeEvent>(_onSetVolume);
    on<ToggleMuteEvent>(_onToggleMute);
    on<SetShuffleEvent>(_onSetShuffle);
    on<ToggleShuffleEvent>(_onToggleShuffle);
    on<SetRepeatModeEvent>(_onSetRepeatMode);
    on<CycleRepeatModeEvent>(_onCycleRepeatMode);
    on<AddToQueueEvent>(_onAddToQueue);
    on<RemoveFromQueueEvent>(_onRemoveFromQueue);
    on<ReorderQueueEvent>(_onReorderQueue);
    on<ClearQueueEvent>(_onClearQueue);
    on<SetPlaybackSpeedEvent>(_onSetPlaybackSpeed);
    on<SetAudioQualityEvent>(_onSetAudioQuality);
    on<SetSleepTimerEvent>(_onSetSleepTimer);
    on<_SleepTimerClearedEvent>(_onSleepTimerCleared);
    on<StopEvent>(_onStop);
    on<PositionUpdateEvent>(_onPositionUpdate);
    on<BufferedPositionUpdateEvent>(_onBufferedPositionUpdate);
    on<DurationUpdateEvent>(_onDurationUpdate);
    on<PlayerStateChangedEvent>(_onPlayerStateChanged);
    on<PlayerErrorEvent>(_onPlayerError);
    on<_BufferingChangedEvent>(_onBufferingChanged);
    on<_CompletedEvent>(_onCompleted);
    on<_AddRecommendationsEvent>(_onAddRecommendations);
    on<_IndexChangedEvent>(_onIndexChanged);

    // Initialize audio player stream listeners
    _initAudioPlayerStreams();
    unawaited(_audioFocus.initialize());

    // Add app lifecycle observer to keep audio session active in background
    WidgetsBinding.instance.addObserver(this);

    // Load persisted performance-related settings
    _loadSettings();
  }

  void _initAudioPlayerStreams() {
    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      add(PositionUpdateEvent(position));
    });

    _bufferedSubscription = _audioPlayer.bufferedPositionStream.listen((
      buffered,
    ) {
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

    _bufferingSubscription = _audioPlayer.bufferingStream.listen((buffering) {
      add(_BufferingChangedEvent(buffering));
    });

    _completedSubscription = _audioPlayer.completedStream.listen((completed) {
      if (completed) {
        add(const _CompletedEvent());
      }
    });

    _errorSubscription = _audioPlayer.errorStream.listen((error) {
      add(PlayerErrorEvent(error));
    });

    // Listen to index changes from the audio player (handles background auto-advance)
    _indexSubscription = _audioPlayer.currentIndexStream.listen((index) {
      add(_IndexChangedEvent(index));
    });

    // Lifecycle observation is registered once in the constructor. Registering
    // again here delivers every transition twice (visible in the device log),
    // which can race audio-session activation on OEM Android builds.
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _log(
      'PlayerBloc: App lifecycle state changed: $state (was: $_lastLifecycleState)',
    );
    _lastLifecycleState = state;

    final isPlaying = _audioPlayer.playing;

    // When app goes to background, ensure audio session stays active for playback
    // When app comes to foreground, re-activate audio session if playing
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App going to background - keep audio session active if playing
      if (isPlaying) {
        _log(
          'PlayerBloc: App backgrounded while playing, keeping audio session active',
        );
        unawaited(_audioFocus.activateForPlayback());
      }
    } else if (state == AppLifecycleState.resumed) {
      // App coming to foreground - re-activate audio session if we were playing
      if (isPlaying) {
        _log('PlayerBloc: App resumed, re-activating audio session');
        unawaited(_audioFocus.activateForPlayback());
      }
    }
  }

  void _loadSettings() {
    _settingsService
        .initialize()
        .then((_) {
          _fastStartEnabled = _settingsService.fastStartEnabled;
          _prefetchLookahead = _settingsService.prefetchLookahead;
          _crossfadeDurationSeconds = _settingsService.crossfadeDuration;
          final storedQuality = _audioQualityFromString(
            _settingsService.audioQuality,
          );
          add(SetAudioQualityEvent(storedQuality));
        })
        .catchError((error) {
          _log('Settings load failed: $error');
        });
  }

  void _refreshRuntimeSettings() {
    _fastStartEnabled = _settingsService.fastStartEnabled;
    _prefetchLookahead = _settingsService.prefetchLookahead;
    _crossfadeDurationSeconds = _settingsService.crossfadeDuration;
  }

  AudioQuality _audioQualityFromString(String quality) {
    switch (quality.toLowerCase()) {
      case 'low':
        return AudioQuality.low;
      case 'medium':
        return AudioQuality.medium;
      case 'lossless':
        return AudioQuality.lossless;
      case 'high':
      default:
        return AudioQuality.high;
    }
  }

  AudioQuality _startupQuality(AudioQuality requestedQuality) {
    if (!_fastStartEnabled) return requestedQuality;
    if (requestedQuality == AudioQuality.high ||
        requestedQuality == AudioQuality.lossless) {
      return AudioQuality.medium; // Faster manifest/stream acquisition
    }
    return requestedQuality;
  }

  void _prefetchAhead(
    List<Song> queue,
    int currentIndex, {
    AudioQuality? quality,
  }) {
    _refreshRuntimeSettings();
    if (_prefetchLookahead <= 0) return;
    if (queue.isEmpty || currentIndex < 0 || currentIndex + 1 >= queue.length) {
      return;
    }

    final preferredQuality = quality ?? _startupQuality(state.audioQuality);
    // Prefetch only the single immediately next song with a slight delay to avoid rate limiting
    final nextSong = queue[currentIndex + 1];
    Future.delayed(const Duration(seconds: 3), () {
      if (state.queueIndex == currentIndex &&
          state.status == PlayerStatus.playing) {
        _mediaResolver.preResolveSong(
          nextSong,
          preferredQuality: preferredQuality,
        );
      }
    });
  }

  void _maybePrefetchUpcomingNearEnd(Duration position) {
    if (!state.hasNext || state.duration.inMilliseconds == 0) return;
    // Prefetch when 30 seconds or less remain for smoother transitions
    final remainingMs = state.duration.inMilliseconds - position.inMilliseconds;
    if (remainingMs <= 30000 && _lastNearEndPrefetchIndex != state.queueIndex) {
      _lastNearEndPrefetchIndex = state.queueIndex;
      _prefetchAhead(state.queue, state.queueIndex);
    }
  }

  Future<void> _onDownloadSong(
    DownloadSongEvent event,
    Emitter<PlayerState> emit,
  ) async {
    _reliability.resetCircuitBreaker();
    final success = await _downloadService.downloadSong(event.song);
    if (success) {
      _log('Successfully queued download for: ${event.song.title}');
    } else {
      _log('Failed to download: ${event.song.title}');
    }
  }

  /// Monotonic counter for playback attempts. Every _onPlaySong start bumps
  /// it; anything captured before a later bump is stale (the user skipped
  /// elsewhere) and must abandon silently instead of emitting error states
  /// or scheduling retries/auto-advances that hijack newer playback.
  int _playbackGeneration = 0;

  /// Upper bounds for network-bound playback stages. Without these a dead
  /// source (e.g. a hung stream manifest fetch) leaves the UI in `loading`
  /// forever with no failure to recover from.
  static const Duration _resolveTimeout = Duration(seconds: 45);
  static const Duration _setSourceTimeout = Duration(seconds: 45);

  Future<void> _onPlaySong(
    PlaySongEvent event,
    Emitter<PlayerState> emit,
  ) async {
    // The circuit breaker only shields programmatic attempts (retries,
    // auto-advance skips). User-initiated plays always get through — a run
    // of failing songs must never leave the user unable to skip or pick
    // another song.
    if (!event.userInitiated && _reliability.isCircuitOpen) {
      emit(
        state.copyWith(
          status: PlayerStatus.error,
          errorMessage: _reliability.cooldownHint(),
        ),
      );
      return;
    }

    // Every new attempt invalidates anything still in flight from previous
    // attempts (bloc handlers run concurrently, so an old hung _onPlaySong
    // may still be awaiting its resolution right now).
    final generation = ++_playbackGeneration;

    // Quick check if this is the same song already playing - just update queue position.
    // NOTE: only when playing. Retry/auto-advance flows re-enter here with
    // status == loading right after the optimistic emit, and must proceed to
    // actually start playback.
    if (state.currentSong?.playableId == event.song.playableId &&
        state.status == PlayerStatus.playing &&
        event.queueIndex != null) {
      emit(state.copyWith(queueIndex: event.queueIndex));
      return;
    }

    // Build initial queue immediately so UI reflects it
    List<Song> initialQueue = event.queue ?? [event.song];
    int initialQueueIndex = event.queueIndex ?? 0;

    // Update UI immediately with the song info (before loading)
    emit(
      state.copyWith(
        status: PlayerStatus.loading,
        currentSong: event.song,
        position: Duration.zero,
        duration: Duration.zero,
        queue: initialQueue,
        queueIndex: initialQueueIndex,
      ),
    );
    _lastNearEndPrefetchIndex = -1; // reset for new track
    _lastRecommendationSongId =
        null; // allow fresh recommendations for new track or queue

    // Reset scrobbling flags for new song
    _hasScrobbled = false;
    _hasUpdatedNowPlaying = false;

    try {
      _refreshRuntimeSettings();
      final playbackQuality = _startupQuality(state.audioQuality);

      // Kick off next-track pre-resolve immediately after queue is known.
      _prefetchAhead(initialQueue, initialQueueIndex, quality: playbackQuality);

      final focusGranted = await _audioFocus.activateForPlayback();
      if (generation != _playbackGeneration) return; // user moved on
      if (!focusGranted) {
        emit(
          state.copyWith(
            status: PlayerStatus.error,
            errorMessage: 'Audio focus denied. Cannot start playback.',
          ),
        );
        return;
      }

      // Resolve local/offline/online source via centralized resolver.
      final resolveStopwatch = Stopwatch()..start();
      final preResolved = _mediaResolver.takePreResolved(event.song.playableId);
      final usedPreResolved = preResolved != null;
      final resolvedSource =
          preResolved ??
          await (_mediaResolver
              .resolveForPlayback(event.song, preferredQuality: playbackQuality)
              .timeout(_resolveTimeout));
      if (generation != _playbackGeneration) return; // user moved on
      resolveStopwatch.stop();
      _log(
        'PlayerBloc: Resolve stage took ${resolveStopwatch.elapsedMilliseconds}ms '
        '(preResolved=$usedPreResolved)',
      );

      // Set up the queue
      int queueIndex = initialQueueIndex;

      // Keep the queue topped up with fresh recommendations. This covers both
      // single-song playback (queue is just the seed) and finite queues built
      // from search results or playlists: as the end of the known songs
      // approaches, recommendations are appended so playback continues with
      // new music instead of stopping at the last search result.
      // Use _checkAndAddRecommendations so every entry point (search, queue
      // selection, auto-advance) shares the same guard rails.
      _checkAndAddRecommendations();

      try {
        _log(
          'PlayerBloc: Starting playback for: ${event.song.title} '
          '(offline=${resolvedSource.isOffline})',
        );

        final shouldCrossfade =
            _crossfadeDurationSeconds > 0 &&
            state.currentSong != null &&
            _audioPlayer.playing &&
            state.currentSong!.playableId != event.song.playableId;

        final setSourceStopwatch = Stopwatch()..start();
        // Notification artwork prefers the medium thumbnail: YouTube's
        // maxres URLs frequently 404, which leaves the media card art-less.
        final notificationArtwork =
            event.song.thumbnails.medium ?? event.song.thumbnailUrl;
        final duration = shouldCrossfade
            ? await _audioPlayer
                  .crossfadeTo(
                    resolvedSource.uri,
                    headers: resolvedSource.headers,
                    videoId: resolvedSource.videoId,
                    quality: _mapAudioQuality(state.audioQuality),
                    title: event.song.title,
                    artist: event.song.artist,
                    album: event.song.album,
                    artworkUrl: notificationArtwork,
                    mediaDuration: event.song.duration,
                    duration: Duration(
                      milliseconds: (_crossfadeDurationSeconds * 1000)
                          .round()
                          .clamp(0, 6000),
                    ),
                  )
                  .timeout(_setSourceTimeout)
            : await _audioPlayer
                  .setUrl(
                    resolvedSource.uri,
                    headers: resolvedSource.headers,
                    videoId: resolvedSource.videoId,
                    quality: _mapAudioQuality(state.audioQuality),
                    title: event.song.title,
                    artist: event.song.artist,
                    album: event.song.album,
                    artworkUrl: notificationArtwork,
                    mediaDuration: event.song.duration,
                    // MediaResolver has already exhausted JioSaavn, YouTube,
                    // Piped and Invidious before returning this URL. Retrying
                    // YouTube again inside the player turns a definitive 403
                    // into ~40 seconds of apparent frozen buffering.
                    allowYouTubeFallbackOnDirectFailure: false,
                  )
                  .timeout(_setSourceTimeout);
        if (generation != _playbackGeneration) return; // user moved on
        setSourceStopwatch.stop();

        _log(
          'PlayerBloc: Player source setup took '
          '${setSourceStopwatch.elapsedMilliseconds}ms '
          '(crossfade=$shouldCrossfade)',
        );

        if (duration == null) {
          throw Exception('Unable to decode selected audio source');
        }

        if (!shouldCrossfade) {
          await _audioPlayer.play();
        }
        if (generation != _playbackGeneration) return; // user moved on

        _log('PlayerBloc: Playback started, duration: $duration');

        _prefetchAhead(state.queue, queueIndex, quality: playbackQuality);

        // Use state.queue (not local queue var) — recommendations may
        // already be in the queue via _AddRecommendationsEvent
        emit(
          state.copyWith(
            status: PlayerStatus.playing,
            currentSong: event.song,
            currentStreamInfo: resolvedSource.streamInfo,
            originalQueue: state.queue,
            queueIndex: queueIndex,
            position: Duration.zero,
          ),
        );

        await _libraryRepository.addToHistory(event.song);
        _recommendationService?.recordPlay(event.song);
        _reliability.registerSuccess(event.song.playableId);
        _consecutiveFailureSkips = 0;
        _updateNowPlaying(event.song);
        // Position in the queue changed → notification skip buttons may
        // have become usable/unusable.
        MediaSessionCoordinator.instance.notifyQueueChanged();
      } catch (playbackError, stackTrace) {
        if (generation != _playbackGeneration) return; // user moved on
        _handlePlaybackError(
          emit,
          failedSong: event.song,
          error: playbackError,
          queue: event.queue ?? state.queue,
          queueIndex: event.queueIndex ?? state.queueIndex,
          isOffline: resolvedSource.isOffline,
          stackTrace: stackTrace,
          generation: generation,
        );
      }
    } catch (e, stackTrace) {
      if (generation != _playbackGeneration) return; // user moved on
      _handlePlaybackError(
        emit,
        failedSong: event.song,
        error: e,
        queue: event.queue ?? state.queue,
        queueIndex: event.queueIndex ?? state.queueIndex,
        isOffline: false,
        stackTrace: stackTrace,
        generation: generation,
      );
    }
  }

  Future<void> _updateNowPlaying(Song song) async {
    if (!_hasUpdatedNowPlaying && _lastFmService.isAuthenticated) {
      _hasUpdatedNowPlaying = true;
      await _lastFmService.updateNowPlaying(
        track: song.title,
        artist: song.artist,
        album: song.album ?? '',
      );
    }
  }

  Future<void> _attemptScrobble(
    Song song,
    Duration position,
    Duration duration,
  ) async {
    if (_hasScrobbled || !_lastFmService.isAuthenticated) return;

    // Scrobble if: played for more than 4 minutes OR more than 50% of the track
    final shouldScrobble =
        position.inSeconds > 240 ||
        (duration.inSeconds > 0 &&
            position.inSeconds > duration.inSeconds * 0.5);

    if (shouldScrobble) {
      _hasScrobbled = true;
      await _lastFmService.scrobble(
        track: song.title,
        artist: song.artist,
        album: song.album ?? '',
      );
    }
  }

  Future<void> _onResume(ResumeEvent event, Emitter<PlayerState> emit) async {
    _log('PlayerBloc: _onResume called');
    _log('  - currentSong: ${state.currentSong?.title}');
    _log('  - current status: ${state.status}');

    // Only resume if we have a song AND it's in a paused/ready state
    // DO NOT resume if loading (that means PlaySongEvent is still setting up)
    if (state.currentSong != null &&
        state.status != PlayerStatus.loading &&
        state.status != PlayerStatus.initial) {
      final focusGranted = await _audioFocus.activateForPlayback();
      if (!focusGranted) {
        emit(
          state.copyWith(
            status: PlayerStatus.error,
            errorMessage: 'Audio focus denied. Cannot resume playback.',
          ),
        );
        return;
      }

      _log('  - Calling _audioPlayer.play()');
      await _audioPlayer.play();
      emit(state.copyWith(status: PlayerStatus.playing));
    } else {
      _log(
        '  - Cannot resume: status is ${state.status}, need paused/ready state',
      );
    }
  }

  Future<void> _onPause(PauseEvent event, Emitter<PlayerState> emit) async {
    await _audioPlayer.pause();
    await _audioFocus.deactivate();
    emit(state.copyWith(status: PlayerStatus.paused));
  }

  Future<void> _onTogglePlayPause(
    TogglePlayPauseEvent event,
    Emitter<PlayerState> emit,
  ) async {
    if (state.isPlaying) {
      add(const PauseEvent());
    } else {
      add(const ResumeEvent());
    }
  }

  Future<void> _onNext(NextEvent event, Emitter<PlayerState> emit) async {
    if (state.hasNext) {
      // A manual skip is explicit user intent: clear any open circuit and
      // per-song retry budgets so the target song always gets a real attempt.
      _reliability.resetCircuitBreaker();
      final nextIndex = state.queueIndex + 1;
      final nextSong = state.queue[nextIndex];

      // Immediately update queue index to show responsiveness
      emit(state.copyWith(queueIndex: nextIndex, status: PlayerStatus.loading));
      _lastNearEndPrefetchIndex = -1; // reset for upcoming track

      // Start loading the next song
      add(
        PlaySongEvent(
          song: nextSong,
          queue: state.queue,
          queueIndex: nextIndex,
        ),
      );
    } else if (state.repeatMode == RepeatMode.all && state.queue.isNotEmpty) {
      // Loop back to first song
      _reliability.resetCircuitBreaker();
      emit(state.copyWith(queueIndex: 0, status: PlayerStatus.loading));
      add(
        PlaySongEvent(
          song: state.queue.first,
          queue: state.queue,
          queueIndex: 0,
        ),
      );
    }
  }

  Future<void> _onPrevious(
    PreviousEvent event,
    Emitter<PlayerState> emit,
  ) async {
    if (state.hasPrevious) {
      // Same as _onNext: user intent overrides the circuit breaker.
      _reliability.resetCircuitBreaker();
      final prevIndex = state.queueIndex - 1;
      final prevSong = state.queue[prevIndex];

      emit(state.copyWith(queueIndex: prevIndex, status: PlayerStatus.loading));
      _lastNearEndPrefetchIndex = -1; // reset for previous track

      add(
        PlaySongEvent(
          song: prevSong,
          queue: state.queue,
          queueIndex: prevIndex,
        ),
      );
    } else if (state.repeatMode == RepeatMode.all && state.queue.isNotEmpty) {
      _reliability.resetCircuitBreaker();
      final lastIndex = state.queue.length - 1;
      emit(state.copyWith(queueIndex: lastIndex, status: PlayerStatus.loading));
      add(
        PlaySongEvent(
          song: state.queue[lastIndex],
          queue: state.queue,
          queueIndex: lastIndex,
        ),
      );
    } else {
      emit(state.copyWith(position: Duration.zero));
    }
  }

  Future<void> _onSeek(SeekEvent event, Emitter<PlayerState> emit) async {
    await _audioPlayer.seek(event.position);
    emit(state.copyWith(position: event.position));
  }

  Future<void> _onSetVolume(
    SetVolumeEvent event,
    Emitter<PlayerState> emit,
  ) async {
    final volume = event.volume.clamp(0.0, 1.0);
    await _audioPlayer.setVolume(volume);
    emit(state.copyWith(volume: volume, isMuted: false));
  }

  Future<void> _onToggleMute(
    ToggleMuteEvent event,
    Emitter<PlayerState> emit,
  ) async {
    final newMuted = !state.isMuted;
    await _audioPlayer.setVolume(newMuted ? 0 : state.volume);
    emit(state.copyWith(isMuted: newMuted));
  }

  Future<void> _onSetShuffle(
    SetShuffleEvent event,
    Emitter<PlayerState> emit,
  ) async {
    if (event.enabled && !state.isShuffleEnabled) {
      // Enable shuffle - shuffle the queue
      final shuffled = List<Song>.from(state.queue)..shuffle();
      emit(state.copyWith(isShuffleEnabled: true, queue: shuffled));
    } else if (!event.enabled && state.isShuffleEnabled) {
      // Disable shuffle - restore original queue
      emit(state.copyWith(isShuffleEnabled: false, queue: state.originalQueue));
    }
  }

  Future<void> _onToggleShuffle(
    ToggleShuffleEvent event,
    Emitter<PlayerState> emit,
  ) async {
    add(SetShuffleEvent(!state.isShuffleEnabled));
  }

  Future<void> _onSetRepeatMode(
    SetRepeatModeEvent event,
    Emitter<PlayerState> emit,
  ) async {
    emit(state.copyWith(repeatMode: event.mode));
  }

  Future<void> _onCycleRepeatMode(
    CycleRepeatModeEvent event,
    Emitter<PlayerState> emit,
  ) async {
    final modes = RepeatMode.values;
    final currentIndex = modes.indexOf(state.repeatMode);
    final nextMode = modes[(currentIndex + 1) % modes.length];
    add(SetRepeatModeEvent(nextMode));
  }

  Future<void> _onAddToQueue(
    AddToQueueEvent event,
    Emitter<PlayerState> emit,
  ) async {
    final updatedQueue = List<Song>.from(state.queue);
    if (event.playNext) {
      updatedQueue.insert(state.queueIndex + 1, event.song);
    } else {
      updatedQueue.add(event.song);
    }

    // Update state first
    emit(state.copyWith(queue: updatedQueue));

    final preferredQuality = _startupQuality(state.audioQuality);
    // Prefetch the new song (non-blocking)
    _streamLoader.prefetch(event.song, preferredQuality: preferredQuality);

    // Also prefetch ahead based on configured lookahead
    _prefetchAhead(updatedQueue, state.queueIndex, quality: preferredQuality);
  }

  Future<void> _onRemoveFromQueue(
    RemoveFromQueueEvent event,
    Emitter<PlayerState> emit,
  ) async {
    if (event.index >= 0 && event.index < state.queue.length) {
      final updatedQueue = List<Song>.from(state.queue)..removeAt(event.index);
      int newIndex = state.queueIndex;
      if (event.index < state.queueIndex) {
        newIndex--;
      }
      emit(state.copyWith(queue: updatedQueue, queueIndex: newIndex));
    }
  }

  Future<void> _onReorderQueue(
    ReorderQueueEvent event,
    Emitter<PlayerState> emit,
  ) async {
    final updatedQueue = List<Song>.from(state.queue);
    final song = updatedQueue.removeAt(event.oldIndex);
    updatedQueue.insert(event.newIndex, song);

    int newIndex = state.queueIndex;
    if (state.queueIndex == event.oldIndex) {
      newIndex = event.newIndex;
    } else if (event.oldIndex < state.queueIndex &&
        event.newIndex >= state.queueIndex) {
      newIndex--;
    } else if (event.oldIndex > state.queueIndex &&
        event.newIndex <= state.queueIndex) {
      newIndex++;
    }

    emit(state.copyWith(queue: updatedQueue, queueIndex: newIndex));
  }

  Future<void> _onClearQueue(
    ClearQueueEvent event,
    Emitter<PlayerState> emit,
  ) async {
    emit(
      state.copyWith(
        queue: state.currentSong != null ? [state.currentSong!] : [],
        queueIndex: 0,
      ),
    );
  }

  Future<void> _onSetPlaybackSpeed(
    SetPlaybackSpeedEvent event,
    Emitter<PlayerState> emit,
  ) async {
    await _audioPlayer.setSpeed(event.speed);
    emit(state.copyWith(playbackSpeed: event.speed));
  }

  Future<void> _onSetAudioQuality(
    SetAudioQualityEvent event,
    Emitter<PlayerState> emit,
  ) async {
    emit(state.copyWith(audioQuality: event.quality));
    // Note: Quality change will apply on next song
  }

  Future<void> _onSetSleepTimer(
    SetSleepTimerEvent event,
    Emitter<PlayerState> emit,
  ) async {
    _sleepTimer?.cancel();
    _sleepTimer = null;

    final duration = event.duration;
    if (duration == null || duration <= Duration.zero) {
      emit(state.copyWith(clearSleepTimer: true));
      return;
    }

    emit(state.copyWith(sleepTimerEnd: DateTime.now().add(duration)));
    _sleepTimer = Timer(duration, () {
      _sleepTimer = null;
      // Two events: pause playback first, then surface the cleared timer.
      add(const PauseEvent());
      add(const _SleepTimerClearedEvent());
    });
  }

  void _onSleepTimerCleared(
    _SleepTimerClearedEvent event,
    Emitter<PlayerState> emit,
  ) {
    emit(state.copyWith(clearSleepTimer: true));
  }

  Future<void> _onStop(StopEvent event, Emitter<PlayerState> emit) async {
    await _audioPlayer.stop();
    await _audioFocus.deactivate();
    _reliability.resetCircuitBreaker();
    emit(const PlayerState());
  }

  void _onPositionUpdate(PositionUpdateEvent event, Emitter<PlayerState> emit) {
    emit(state.copyWith(position: event.position));

    // Attempt scrobbling if conditions are met
    final currentSong = state.currentSong;
    if (currentSong != null && state.duration.inSeconds > 0) {
      _attemptScrobble(currentSong, event.position, state.duration);
    }

    // Check if we need to add recommendations (when less than 5 songs remaining)
    _checkAndAddRecommendations();

    // Ensure next track is prefetched when nearing end of current song
    _maybePrefetchUpcomingNearEnd(event.position);
  }

  void _onBufferedPositionUpdate(
    BufferedPositionUpdateEvent event,
    Emitter<PlayerState> emit,
  ) {
    emit(state.copyWith(bufferedPosition: event.bufferedPosition));
  }

  void _onDurationUpdate(DurationUpdateEvent event, Emitter<PlayerState> emit) {
    emit(state.copyWith(duration: event.duration));
  }

  void _onPlayerStateChanged(
    PlayerStateChangedEvent event,
    Emitter<PlayerState> emit,
  ) {
    // Terminal errors must not be silently erased by stream noise (e.g. the
    // player reporting "not playing" right after we stopped it).
    if (state.status == PlayerStatus.error) return;
    emit(
      state.copyWith(
        status: event.isPlaying ? PlayerStatus.playing : PlayerStatus.paused,
      ),
    );
  }

  void _onBufferingChanged(
    _BufferingChangedEvent event,
    Emitter<PlayerState> emit,
  ) {
    if (state.status == PlayerStatus.error) return;

    // Only update status if there's actually a change to avoid UI flicker
    if (event.isBuffering && state.status != PlayerStatus.loading) {
      emit(state.copyWith(status: PlayerStatus.loading));
    } else if (!event.isBuffering) {
      if (_audioPlayer.playing && state.status != PlayerStatus.playing) {
        emit(state.copyWith(status: PlayerStatus.playing));
      } else if (!_audioPlayer.playing &&
          state.currentSong != null &&
          state.status != PlayerStatus.paused) {
        emit(state.copyWith(status: PlayerStatus.paused));
      }
    }
  }

  void _onCompleted(_CompletedEvent event, Emitter<PlayerState> emit) async {
    // Auto-play next song if available
    if (state.repeatMode == RepeatMode.one) {
      // Repeat current song - BUT only if it actually played (not an immediate 0-duration abort)
      if (state.duration > const Duration(seconds: 2) &&
          state.position > Duration.zero) {
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play();
        emit(
          state.copyWith(position: Duration.zero, status: PlayerStatus.playing),
        );
        return;
      }
      // If duration was 0 or never played, advance to next track or stop rather than infinite loop
      if (state.hasNext) {
        add(const NextEvent());
        return;
      }
    } else if (state.hasNext) {
      // Use NextEvent which now has optimized prefetching
      add(const NextEvent());
    } else if (state.repeatMode == RepeatMode.all && state.queue.isNotEmpty) {
      if (_consecutiveFailureSkips >= state.queue.length) {
        _consecutiveFailureSkips = 0;
        emit(
          state.copyWith(status: PlayerStatus.paused, position: Duration.zero),
        );
        return;
      }
      emit(state.copyWith(queueIndex: 0, status: PlayerStatus.loading));
      add(
        PlaySongEvent(
          song: state.queue.first,
          queue: state.queue,
          queueIndex: 0,
        ),
      );
    } else {
      // Queue is empty or at the end - no more songs
      emit(
        state.copyWith(status: PlayerStatus.paused, position: Duration.zero),
      );
    }
  }

  void _onPlayerError(PlayerErrorEvent event, Emitter<PlayerState> emit) {
    // If player is actively in loading state, _onPlaySong is already handling resolution,
    // retries, and error recovery. Avoid duplicate concurrent retries and infinite loops!
    if (state.status == PlayerStatus.loading) {
      _log(
        'PlayerBloc: Ignoring PlayerErrorEvent during loading (handled by _onPlaySong): ${event.message}',
      );
      return;
    }
    // If we already surfaced a terminal error for this attempt, ignore any
    // follow-up error events: re-handling them would double-count failures
    // (accelerating the circuit breaker) and schedule "resurrection" retries
    // of a song the user was already told failed.
    if (state.status == PlayerStatus.error) {
      _log(
        'PlayerBloc: Ignoring PlayerErrorEvent in terminal error state: ${event.message}',
      );
      return;
    }

    final currentSong = state.currentSong;
    if (currentSong == null) {
      emit(
        state.copyWith(status: PlayerStatus.error, errorMessage: event.message),
      );
      return;
    }

    final isOffline = _downloadService.isDownloaded(currentSong.playableId);
    _handlePlaybackError(
      emit,
      failedSong: currentSong,
      error: event.message,
      queue: state.queue,
      queueIndex: state.queueIndex,
      isOffline: isOffline,
    );
  }

  void _handlePlaybackError(
    Emitter<PlayerState> emit, {
    required Song failedSong,
    required Object error,
    required List<Song> queue,
    required int queueIndex,
    bool isOffline = false,
    StackTrace? stackTrace,
    int? generation,
  }) {
    _reliability.registerFailure(failedSong.playableId);
    _mediaResolver.invalidate(failedSong.playableId);

    if (isOffline) {
      try {
        _downloadService.deleteSong(failedSong.playableId);
        _log(
          'PlayerBloc: Removed invalid local download entry for ${failedSong.playableId}',
        );
      } catch (_) {}
    }

    // A stale attempt (user already skipped to another song) must not
    // schedule retries or advance the queue.
    bool isStale() => generation != null && generation != _playbackGeneration;

    final isFatalError = _isFatalPlaybackError(error);
    if (isFatalError) {
      _log(
        'PlayerBloc: Fatal playback error detected for "${failedSong.title}"; skipping retry.',
      );
    }

    final canRetry =
        !isFatalError &&
        !isStale() &&
        _reliability.shouldRetry(failedSong.playableId, isOffline: isOffline);

    if (canRetry) {
      _reliability.registerRetry(failedSong.playableId);
      final waitFor = _reliability.nextRetryDelay(failedSong.playableId);
      _log(
        'PlayerBloc: Retry ${_reliability.attemptsForSong(failedSong.playableId)} '
        'for "${failedSong.title}" in ${waitFor.inMilliseconds}ms',
      );
      emit(
        state.copyWith(
          status: PlayerStatus.loading,
          errorMessage: 'Retrying playback...',
        ),
      );
      Future.delayed(waitFor, () {
        if (isClosed || isStale()) return;
        add(
          PlaySongEvent(
            song: failedSong,
            queue: queue,
            queueIndex: queueIndex,
            // Programmatic retry: still subject to the circuit breaker.
            userInitiated: false,
          ),
        );
      });
      return;
    }

    _log(
      '!!! PlayerBloc: Terminal playback failure for "${failedSong.title}": $error',
    );
    if (stackTrace != null) _log('Stack trace: $stackTrace');

    final effectiveQueue = queue.isNotEmpty ? queue : state.queue;
    final effectiveIndex = queueIndex;
    final nextIndex = effectiveIndex + 1;
    final hasNextSong =
        effectiveQueue.isNotEmpty && nextIndex < effectiveQueue.length;

    _consecutiveFailureSkips++;

    // Auto-advance to next song if available, capped at 5 skips or queue length to prevent runaway loops
    final shouldAutoAdvance =
        hasNextSong &&
        !isStale() &&
        _consecutiveFailureSkips <= 5 &&
        _consecutiveFailureSkips < effectiveQueue.length;

    if (shouldAutoAdvance) {
      final nextSong = effectiveQueue[nextIndex];
      _log(
        'PlayerBloc: Auto-advancing from unplayable "${failedSong.title}" '
        'to next track [${nextIndex + 1}/${effectiveQueue.length}]: "${nextSong.title}" '
        '(consecutive skips: $_consecutiveFailureSkips)',
      );

      emit(
        state.copyWith(
          status: PlayerStatus.loading,
          currentSong: nextSong,
          queue: effectiveQueue,
          queueIndex: nextIndex,
          position: Duration.zero,
          duration: Duration.zero,
          errorMessage: 'Skipping unplayable track: "${failedSong.title}"',
        ),
      );

      Future.delayed(const Duration(milliseconds: 300), () {
        if (isClosed || isStale()) return;
        add(
          PlaySongEvent(
            song: nextSong,
            queue: effectiveQueue,
            queueIndex: nextIndex,
            // Programmatic skip: still subject to the circuit breaker.
            userInitiated: false,
          ),
        );
      });
      return;
    }

    // No next track or max consecutive skips reached. Capture the skip count
    // before resetting so the user gets a meaningful message.
    final consecutiveSkips = _consecutiveFailureSkips;
    _consecutiveFailureSkips = 0;
    unawaited(_audioPlayer.stop());
    emit(
      state.copyWith(
        status: PlayerStatus.error,
        errorMessage: effectiveQueue.length > 1 && consecutiveSkips >= 3
            ? 'Multiple songs failed to play. Please check your connection and try again.'
            : 'Playback error: $error',
      ),
    );
  }

  bool _isFatalPlaybackError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('403') ||
        message.contains('404') ||
        message.contains('forbidden') ||
        message.contains('not found') ||
        message.contains('unable to decode') ||
        message.contains('no valid audio source') ||
        message.contains('all stream sources failed')) {
      return true;
    }
    return _isVideoStream403(error);
  }

  bool _isFetchingRecommendations = false;
  String?
  _lastRecommendationSongId; // Track which song we last fetched recommendations for

  /// Songs that may remain after the current one (exclusive) before we top up
  /// the queue with recommendations. Keeps finite queues (search results,
  /// playlists) from ending abruptly or re-serving the same list forever.
  static const int _recommendTopUpRemaining = 3;
  static const int _recommendationBatchSize = 10;

  /// Check if queue is running low and add recommendations (BlackHole + BloomeeTunes approach)
  void _checkAndAddRecommendations() {
    if (_isFetchingRecommendations || _recommendationService == null) return;
    if (state.currentSong == null || state.queue.isEmpty) return;

    final currentSong = state.currentSong!;
    final int currentIndex = state.queueIndex;
    final int queueLength = state.queue.length;

    // Calculate songs remaining AFTER current song (not including current)
    final int songsRemaining = queueLength - currentIndex - 1;

    // Only fetch when the queue is running low AND we haven't already fetched
    // for this song.
    if (songsRemaining >= _recommendTopUpRemaining ||
        _lastRecommendationSongId == currentSong.playableId) {
      return;
    }

    _log(
      'Only $songsRemaining songs remaining after "${currentSong.title}", adding recommendations',
    );
    _lastRecommendationSongId =
        currentSong.playableId; // Mark this song as processed

    // If queue is empty after current song, fetch immediately so Up Next is ready.
    // Otherwise use a short delay to avoid rapid calls.
    final delay = songsRemaining == 0
        ? Duration.zero
        : const Duration(milliseconds: 500);

    Future.delayed(delay, () async {
      // Skip if the user has already moved on to a different song
      if (state.currentSong?.playableId != currentSong.playableId) return;

      _log('Fetching recommendations for: ${currentSong.title}');
      await _fetchAndAppendRecommendations(currentSong);
    });
  }

  /// Fetch recommendations for [seedSong] and append them to the queue.
  /// Falls back to the repository's own recommendation feed when the
  /// recommendation service returns nothing (e.g. algorithmic sources down).
  Future<void> _fetchAndAppendRecommendations(Song seedSong) async {
    final recommendationService = _recommendationService;
    if (recommendationService == null || _isFetchingRecommendations) return;

    _isFetchingRecommendations = true;
    try {
      final recommendations = await recommendationService.getRecommendations(
        currentSong: seedSong,
        limit: _recommendationBatchSize,
      );

      if (recommendations.isNotEmpty) {
        // Use batch event for single state emission (add() instead of emit()
        // properly routes through the bloc event system)
        add(_AddRecommendationsEvent(recommendations));
        return;
      }

      _log('RecommendationService returned 0, trying repository fallback');
      final fallback = await _musicRepository.getRecommendations(
        limit: _recommendationBatchSize,
      );
      fallback.fold(
        (failure) => _log(
          'Repository recommendation fallback failed: ${failure.message}',
        ),
        (songs) {
          if (songs.isNotEmpty) {
            _log(
              'Repository recommendation fallback returned ${songs.length} songs',
            );
            add(_AddRecommendationsEvent(songs));
          }
        },
      );
    } catch (e) {
      _log('✗ Error adding recommendations: $e');
    } finally {
      _isFetchingRecommendations = false;
    }
  }

  /// Handle batch recommendation additions (single state emission)
  void _onAddRecommendations(
    _AddRecommendationsEvent event,
    Emitter<PlayerState> emit,
  ) {
    final uniqueSongs = <Song>[];
    final seenKeys = state.queue
        .map(
          (s) =>
              '${s.title.toLowerCase().trim()}|${s.artist.toLowerCase().trim()}',
        )
        .toSet();
    final seenIds = state.queue
        .map((s) => s.playableId)
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final song in event.songs) {
      final key =
          '${song.title.toLowerCase().trim()}|${song.artist.toLowerCase().trim()}';
      if (seenKeys.contains(key)) continue;
      // Same underlying track can surface with slightly different metadata —
      // dedupe by playable id as well so it isn't queued twice.
      if (song.playableId.isNotEmpty && !seenIds.add(song.playableId)) continue;
      seenKeys.add(key);
      uniqueSongs.add(song);
    }

    if (uniqueSongs.isNotEmpty) {
      final updatedQueue = [...state.queue, ...uniqueSongs];
      emit(state.copyWith(queue: updatedQueue));
      _log(
        'Added ${uniqueSongs.length} recommendations to queue (total: ${updatedQueue.length})',
      );
      // Next button in the media notification may now be usable.
      MediaSessionCoordinator.instance.notifyQueueChanged();
    }
  }

  /// Handle index changes from the audio player (auto-advance in background)
  /// This is the KEY handler for background playback - when just_audio auto-advances
  /// in background, this syncs the BLoC state with the actual player position
  void _onIndexChanged(_IndexChangedEvent event, Emitter<PlayerState> emit) {
    if (!_audioPlayer.isQueueMode) {
      return;
    }

    final newIndex = event.index;
    _log(
      'PlayerBloc: Index changed to $newIndex (current state index: ${state.queueIndex})',
    );

    if (newIndex == null) {
      return;
    }

    if (state.queue.isEmpty || newIndex < 0 || newIndex >= state.queue.length) {
      _log(
        'PlayerBloc: Ignoring out-of-range index $newIndex for queue size ${state.queue.length}',
      );
      return;
    }

    final newSong = state.queue[newIndex];
    final indexChanged = newIndex != state.queueIndex;
    final songChanged = state.currentSong?.playableId != newSong.playableId;
    if (!indexChanged && !songChanged) {
      return;
    }

    _log('PlayerBloc: Synced active queue item to: ${newSong.title}');

    // Reset scrobbling flags for new song
    _hasScrobbled = false;
    _hasUpdatedNowPlaying = false;
    _lastNearEndPrefetchIndex = -1;

    // Update state to reflect new song/index.
    emit(
      state.copyWith(
        currentSong: newSong,
        queueIndex: newIndex,
        position: indexChanged ? Duration.zero : state.position,
        status: _audioPlayer.playing ? PlayerStatus.playing : state.status,
      ),
    );

    // Update now playing and prefetch ahead.
    _updateNowPlaying(newSong);
    _prefetchAhead(state.queue, newIndex);

    // Add to history in background.
    _libraryRepository.addToHistory(newSong);
    _recommendationService?.recordPlay(newSong);

    // Check if we need more recommendations.
    _checkAndAddRecommendations();
  }

  String _mapAudioQuality(AudioQuality quality) {
    switch (quality) {
      case AudioQuality.low:
        return 'low';
      case AudioQuality.medium:
        return 'medium';
      case AudioQuality.high:
        return 'high';
      case AudioQuality.lossless:
        return 'lossless';
    }
  }

  bool _isVideoStream403(Object error) {
    final message = error.toString().toLowerCase();
    if (!message.contains('403')) return false;

    final streamMatch = RegExp(r'stream:\s*(\d+)').firstMatch(message);
    if (streamMatch == null) return false;

    final streamId = streamMatch.group(1);
    const audioItags = {'139', '140', '141', '171', '172', '249', '250', '251'};
    return streamId != null && !audioItags.contains(streamId);
  }

  @override
  Future<void> close() async {
    WidgetsBinding.instance.removeObserver(this);
    _sleepTimer?.cancel();
    await _positionSubscription?.cancel();
    await _bufferedSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _playingSubscription?.cancel();
    await _bufferingSubscription?.cancel();
    await _completedSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _indexSubscription?.cancel();
    await _recommendationService?.dispose();
    await _audioFocus.dispose();
    await super.close();
  }
}

/// Internal event for buffering changes
class _BufferingChangedEvent extends PlayerEvent {
  final bool isBuffering;

  const _BufferingChangedEvent(this.isBuffering);

  @override
  List<Object?> get props => [isBuffering];
}

/// Internal event for completion
class _CompletedEvent extends PlayerEvent {
  const _CompletedEvent();

  @override
  List<Object?> get props => [];
}

/// Internal event to batch-add recommendation songs to the queue
class _AddRecommendationsEvent extends PlayerEvent {
  final List<Song> songs;

  const _AddRecommendationsEvent(this.songs);

  @override
  List<Object?> get props => [songs];
}

/// Internal event for track index changes (from auto-advance in background)
class _IndexChangedEvent extends PlayerEvent {
  final int? index;

  const _IndexChangedEvent(this.index);

  @override
  List<Object?> get props => [index];
}

/// Internal event fired when the sleep timer elapses and playback was
/// paused; clears the timer state.
class _SleepTimerClearedEvent extends PlayerEvent {
  const _SleepTimerClearedEvent();

  @override
  List<Object?> get props => [];
}
