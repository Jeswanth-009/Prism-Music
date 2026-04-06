import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/audio_player_service.dart';
import '../../../core/services/lastfm_service.dart';
import '../../../core/services/recommendation_service.dart';
import '../../../core/services/download_service.dart';
import '../../../core/services/audio_focus_orchestrator_service.dart';
import '../../../core/services/media_resolver_service.dart';
import '../../../core/services/playback_reliability_service.dart';
import '../../../core/services/stream_loader_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/repositories.dart';
import 'player_event.dart';
import 'player_state.dart';

/// BLoC for managing audio player state
class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
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
  }) : _musicRepository = musicRepository,
       _libraryRepository = libraryRepository,
       _audioPlayer = audioPlayerService,
       _audioFocus = audioFocus,
       _mediaResolver = mediaResolver,
       _reliability = reliability,
       _streamLoader = streamLoader,
       _downloadService = downloadService,
       super(const PlayerState()) {
    // Initialize recommendation service — pass library repo for history-based recs
    _recommendationService = RecommendationService(
      _musicRepository,
      _libraryRepository,
    );
    _recommendationService?.initialize();

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
    if (queue.isEmpty || currentIndex < 0 || currentIndex >= queue.length) {
      return;
    }

    final preferredQuality = quality ?? _startupQuality(state.audioQuality);
    for (
      int i = 1;
      i <= _prefetchLookahead && currentIndex + i < queue.length;
      i++
    ) {
      _mediaResolver.preResolveSong(
        queue[currentIndex + i],
        preferredQuality: preferredQuality,
      );
    }
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

  Future<void> _onPlaySong(
    PlaySongEvent event,
    Emitter<PlayerState> emit,
  ) async {
    if (_reliability.isCircuitOpen) {
      emit(
        state.copyWith(
          status: PlayerStatus.error,
          errorMessage: _reliability.cooldownHint(),
        ),
      );
      return;
    }

    // Quick check if this is the same song already playing - just update queue position
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

    // Reset scrobbling flags for new song
    _hasScrobbled = false;
    _hasUpdatedNowPlaying = false;

    try {
      _refreshRuntimeSettings();
      final playbackQuality = _startupQuality(state.audioQuality);

      // Kick off next-track pre-resolve immediately after queue is known.
      _prefetchAhead(initialQueue, initialQueueIndex, quality: playbackQuality);

      final focusGranted = await _audioFocus.activateForPlayback();
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
          await _mediaResolver.resolveForPlayback(
            event.song,
            preferredQuality: playbackQuality,
          );
      resolveStopwatch.stop();
      _log(
        'PlayerBloc: Resolve stage took ${resolveStopwatch.elapsedMilliseconds}ms '
        '(preResolved=$usedPreResolved)',
      );

      // Set up the queue
      int queueIndex = initialQueueIndex;

      if (event.queue == null) {
        // No queue provided — fetch recommendations in background
        // Use add() instead of emit() to properly route through the bloc
        // event system (emit() silently fails outside handler scope)
        final recommendationService = _recommendationService;
        if (recommendationService != null) {
          recommendationService
              .getRecommendations(currentSong: event.song, limit: 10)
              .then((recommendations) async {
                if (recommendations.isNotEmpty) {
                  add(_AddRecommendationsEvent(recommendations));
                  return;
                }

                _log(
                  'RecommendationService returned 0, trying repository fallback',
                );
                final fallback = await _musicRepository.getRecommendations(
                  limit: 10,
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
              })
              .catchError((e) {
                _log('Failed to fetch recommendations: $e');
              });
        }
      }

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
        final duration = shouldCrossfade
            ? await _audioPlayer.crossfadeTo(
                resolvedSource.uri,
                headers: resolvedSource.headers,
                videoId: resolvedSource.videoId,
                quality: _mapAudioQuality(state.audioQuality),
                title: event.song.title,
                artist: event.song.artist,
                album: event.song.album,
                artworkUrl: event.song.thumbnailUrl,
                duration: Duration(
                  milliseconds: (_crossfadeDurationSeconds * 1000)
                      .round()
                      .clamp(0, 6000),
                ),
              )
            : await _audioPlayer.setUrl(
                resolvedSource.uri,
                headers: resolvedSource.headers,
                videoId: resolvedSource.videoId,
                quality: _mapAudioQuality(state.audioQuality),
                title: event.song.title,
                artist: event.song.artist,
                album: event.song.album,
                artworkUrl: event.song.thumbnailUrl,
                allowYouTubeFallbackOnDirectFailure: false,
              );
        setSourceStopwatch.stop();

        _log(
          'PlayerBloc: Player source setup took '
          '${setSourceStopwatch.elapsedMilliseconds}ms '
          '(crossfade=$shouldCrossfade)',
        );

        if (!shouldCrossfade) {
          await _audioPlayer.play();
        }

        if (duration == null) {
          throw Exception('Unable to decode selected audio source');
        }

        _log('PlayerBloc: Playback started, duration: $duration');

        _prefetchAhead(state.queue, queueIndex, quality: playbackQuality);

        // Use state.queue (not local queue var) — recommendations may
        // already be in the queue via _AddRecommendationsEvent
        emit(
          state.copyWith(
            status: PlayerStatus.playing,
            currentSong: event.song,
            originalQueue: state.queue,
            queueIndex: queueIndex,
            position: Duration.zero,
          ),
        );

        await _libraryRepository.addToHistory(event.song);
        _recommendationService?.recordPlay(event.song);
        _reliability.registerSuccess(event.song.playableId);
        _updateNowPlaying(event.song);
      } catch (playbackError, stackTrace) {
        _reliability.registerFailure(event.song.playableId);

        final isVideoStream403 = _isVideoStream403(playbackError);
        if (isVideoStream403) {
          _log(
            'PlayerBloc: Non-audio stream 403 detected for ${event.song.title}; '
            'skipping retry.',
          );
        }

        final canRetry =
            !isVideoStream403 &&
            _reliability.shouldRetry(
              event.song.playableId,
              isOffline: resolvedSource.isOffline,
            );

        if (canRetry) {
          _reliability.registerRetry(event.song.playableId);
          final waitFor = _reliability.nextRetryDelay(event.song.playableId);
          _log(
            'PlayerBloc: Retry ${_reliability.attemptsForSong(event.song.playableId)} '
            'for ${event.song.title} in ${waitFor.inMilliseconds}ms',
          );
          emit(state.copyWith(status: PlayerStatus.loading));
          Future.delayed(waitFor, () {
            add(
              PlaySongEvent(
                song: event.song,
                queue: event.queue,
                queueIndex: event.queueIndex,
              ),
            );
          });
          return;
        }

        if (resolvedSource.isOffline) {
          try {
            await _downloadService.deleteSong(event.song.playableId);
            _log(
              'PlayerBloc: Removed invalid local download entry for ${event.song.playableId}',
            );
          } catch (_) {}
        }

        _log('!!! PlayerBloc: PLAYBACK ERROR !!!');
        _log('Error: $playbackError');
        _log('Stack trace: $stackTrace');
        emit(
          state.copyWith(
            status: PlayerStatus.error,
            errorMessage: 'Playback error: $playbackError',
          ),
        );
      }
    } catch (e, stackTrace) {
      _log('!!! PlayerBloc: STREAM LOADING ERROR !!!');
      _log('Error: $e');
      _log('Stack trace: $stackTrace');
      emit(
        state.copyWith(
          status: PlayerStatus.error,
          errorMessage: 'Failed to load stream: $e',
        ),
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
      // Repeat current song - seek and play without full event chain
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
      emit(
        state.copyWith(position: Duration.zero, status: PlayerStatus.playing),
      );
    } else if (state.hasNext) {
      // Use NextEvent which now has optimized prefetching
      add(const NextEvent());
    } else if (state.repeatMode == RepeatMode.all && state.queue.isNotEmpty) {
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
    final currentSong = state.currentSong;
    if (currentSong != null) {
      _reliability.registerFailure(currentSong.playableId);

      final isVideoStream403 = _isVideoStream403(event.message);
      if (isVideoStream403) {
        _log(
          'PlayerBloc: Non-audio stream 403 detected for ${currentSong.title}; '
          'skipping retry.',
        );
      }

      final offlineCandidate = _downloadService.isDownloaded(
        currentSong.playableId,
      );
      final canRetry =
          !isVideoStream403 &&
          _reliability.shouldRetry(
            currentSong.playableId,
            isOffline: offlineCandidate,
          );

      if (canRetry) {
        _reliability.registerRetry(currentSong.playableId);
        final retryAfter = _reliability.nextRetryDelay(currentSong.playableId);
        emit(
          state.copyWith(
            status: PlayerStatus.loading,
            errorMessage: 'Recovering playback...',
          ),
        );
        Future.delayed(retryAfter, () {
          add(
            PlaySongEvent(
              song: currentSong,
              queue: state.queue,
              queueIndex: state.queueIndex,
            ),
          );
        });
        return;
      }
    }

    emit(
      state.copyWith(status: PlayerStatus.error, errorMessage: event.message),
    );
  }

  bool _isFetchingRecommendations = false;
  String?
  _lastRecommendationSongId; // Track which song we last fetched recommendations for

  /// Check if queue is running low and add recommendations (BlackHole + BloomeeTunes approach)
  void _checkAndAddRecommendations() {
    if (_isFetchingRecommendations || _recommendationService == null) return;
    if (state.currentSong == null || state.queue.isEmpty) return;

    final currentSong = state.currentSong!;
    final int currentIndex = state.queueIndex;
    final int queueLength = state.queue.length;

    // Calculate songs remaining AFTER current song (not including current)
    final int songsRemaining = queueLength - currentIndex - 1;

    // Only fetch when less than 2 songs remaining AND we haven't already fetched for this song
    // BloomeeTunes uses < 2, BlackHole uses < 5
    if (songsRemaining < 2 &&
        _lastRecommendationSongId != currentSong.playableId) {
      _log(
        'Only $songsRemaining songs remaining after "${currentSong.title}", adding recommendations',
      );
      _isFetchingRecommendations = true;
      _lastRecommendationSongId =
          currentSong.playableId; // Mark this song as processed

      // Delay fetch by 1 second to avoid rapid calls (BlackHole approach)
      Future.delayed(const Duration(seconds: 1), () async {
        // Double-check we're still playing the same song
        if (state.currentSong?.playableId != currentSong.playableId) {
          _isFetchingRecommendations = false;
          return;
        }

        try {
          _log('Fetching recommendations for: ${currentSong.title}');
          final recommendations = await _recommendationService!
              .getRecommendations(currentSong: currentSong, limit: 10);

          _log('Got ${recommendations.length} recommendations');

          if (state.currentSong?.playableId == currentSong.playableId &&
              recommendations.isNotEmpty) {
            // Use batch event for single state emission
            add(_AddRecommendationsEvent(recommendations));
          }
        } catch (e) {
          _log('✗ Error adding recommendations: $e');
        } finally {
          _isFetchingRecommendations = false;
        }
      });
    }
  }

  /// Handle batch recommendation additions (single state emission)
  void _onAddRecommendations(
    _AddRecommendationsEvent event,
    Emitter<PlayerState> emit,
  ) {
    final uniqueSongs = <Song>[];
    final seenKeys = state.queue
        .map((s) => '${s.title.toLowerCase()}|${s.artist.toLowerCase()}')
        .toSet();

    for (final song in event.songs) {
      final key = '${song.title.toLowerCase()}|${song.artist.toLowerCase()}';
      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        uniqueSongs.add(song);
      }
    }

    if (uniqueSongs.isNotEmpty) {
      final updatedQueue = [...state.queue, ...uniqueSongs];
      emit(state.copyWith(queue: updatedQueue));
      _log(
        'Added ${uniqueSongs.length} recommendations to queue (total: ${updatedQueue.length})',
      );

      // Prefetch first new song
      final quality = _startupQuality(state.audioQuality);
      _mediaResolver.preResolveSong(
        uniqueSongs.first,
        preferredQuality: quality,
      );
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
    await _positionSubscription?.cancel();
    await _bufferedSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _playingSubscription?.cancel();
    await _bufferingSubscription?.cancel();
    await _completedSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _indexSubscription?.cancel();
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
