import 'dart:async';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/audio_player_service.dart';
import '../../../core/services/media_session_coordinator.dart';
import '../../../core/services/collaborative_queue_service.dart';
import '../../../core/services/recommendation_service.dart';
import '../../../core/services/audio_focus_orchestrator_service.dart';
import '../../../core/services/media_resolver_service.dart';
import '../../../core/services/playback_reliability_service.dart';
import '../../../core/services/stream_cache_service.dart';
import '../../../core/services/stream_loader_service.dart';
import '../../../core/services/download_service.dart';
import '../../../core/services/offline_mode_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/widget_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../core/services/artwork_prefetch_service.dart';
import '../../../core/services/verified_recording_verifier.dart';
import '../../../core/services/queue_persistence_service.dart';
import '../../../core/services/music_video_service.dart';
import '../../../core/di/injection.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/repositories.dart';
import '../library/library.dart' hide DownloadSongEvent;
import 'player_event.dart';
import 'player_state.dart';
import 'mixins/scrobble_mixin.dart';
import 'mixins/sleep_timer_mixin.dart';


/// BLoC for managing audio player state
class PlayerBloc extends Bloc<PlayerEvent, PlayerState>
    with WidgetsBindingObserver, SleepTimerMixin, ScrobbleMixin {
  final MusicRepository _musicRepository;
  final LibraryRepository _libraryRepository;
  final AudioPlayerService _audioPlayer;
  final AudioFocusOrchestratorService _audioFocus;
  final MediaResolverService _mediaResolver;
  final PlaybackReliabilityService _reliability;
  final StreamLoaderService _streamLoader;
  final DownloadService _downloadService;
  final SettingsService _settingsService;
  bool _fastStartEnabled = true;
  double _preSleepTimerVolume = 1.0;

  void _safeCancelSleepTimer() {
    cancelSleepTimer(onRestoreVolume: () {
      if (state.sleepTimerBedtimeMode) {
        _audioPlayer.setVolume(_preSleepTimerVolume);
      }
    });
  }

  void _safePrefetchUpcomingArtwork(List<Song> queue, int currentIndex) {
    try {
      unawaited(
        ArtworkPrefetchService.instance
            .prefetchUpcomingQueue(queue, currentIndex)
            .catchError((_) => 0),
      );
    } catch (_) {}
  }

  void _safePrefetchSongArtwork(Song song) {
    try {
      unawaited(
        ArtworkPrefetchService.instance
            .prefetchSongArtwork(song)
            .catchError((_) {}),
      );
    } catch (_) {}
  }
  int _prefetchLookahead = 1;
  double _crossfadeDurationSeconds = 0.0;
  int _lastNearEndPrefetchIndex = -1;

  /// Last known video position, used to resync audio when video mode ends.
  Duration? _videoPosition;

  /// Whether audio should resume after video mode ends.
  bool _resumeAudioAfterVideo = false;
  RecommendationService? _recommendationService;
  int _recommendationGeneration = 0;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _bufferedSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<bool>? _bufferingSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<bool>? _completedSubscription;
  StreamSubscription<int?>? _indexSubscription;
  StreamSubscription<bool>? _crossfadeSubscription;
  AppLifecycleState _lastLifecycleState = AppLifecycleState.resumed;
  int _consecutiveFailureSkips = 0;
  final Set<String> _attemptedFreshResolutions = {};
  final Map<String, String> _widgetArtworkPathCache = {};
  static const int _maxWidgetArtworkCacheSize = 50;
  String? _lastWidgetSongKey;
  bool? _lastWidgetIsPlaying;
  String? _lastWidgetArtworkPath;

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
    SettingsService? settingsService,
    // How long a natively advanced queue track may sit without starting to
    // play before it is treated as stuck. Overridable so tests need not wait.
    Duration trackStartWatchdogTimeout = const Duration(seconds: 15),
  }) : _musicRepository = musicRepository,
       _libraryRepository = libraryRepository,
       _audioPlayer = audioPlayerService,
       _audioFocus = audioFocus,
       _mediaResolver = mediaResolver,
       _reliability = reliability,
       _streamLoader = streamLoader,
       _downloadService = downloadService,
       _recommendationService = recommendationService,
       _settingsService = settingsService ?? SettingsService.instance,
       _trackStartWatchdogTimeout = trackStartWatchdogTimeout,
       super(PlayerState(autoPlay: (settingsService ?? SettingsService.instance).autoPlay)) {
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
      onToggleShuffle: () async {
        if (!isClosed) add(const ToggleShuffleEvent());
      },
      onCycleRepeat: () async {
        if (!isClosed) add(const CycleRepeatModeEvent());
      },
      onToggleLike: () async {
        final current = state.currentSong;
        if (current != null) {
          final isLiked = await _libraryRepository.isSongLiked(current.id);
          if (isLiked) {
            await _libraryRepository.unlikeSong(current.id);
            MediaSessionCoordinator.instance.updatePlaybackInfo(isLiked: false);
          } else {
            await _libraryRepository.likeSong(current);
            MediaSessionCoordinator.instance.updatePlaybackInfo(isLiked: true);
          }
          if (getIt.isRegistered<LibraryBloc>()) {
            getIt<LibraryBloc>().add(const LoadLibraryEvent());
          }
        }
      },
      onPlayMedia: (song, queue, index) {
        if (!isClosed) {
          add(PlaySongEvent(
            song: song,
            queue: queue,
            queueIndex: index,
            userInitiated: true,
          ));
        }
      },
      hasNext: () => !isClosed && state.canSkipNext,
      hasPrevious: () => !isClosed && state.canSkipPrevious,
    );

    CollaborativeQueueService.instance.configure(
      musicRepository: _musicRepository,
      onSongQueued: (song, guestName) {
        if (!isClosed) {
          add(AddToQueueEvent(song: song));
        }
      },
      nowPlayingProvider: () => state.currentSong,
      queueProvider: () => state.queue,
    );

    // Register event handlers
    on<PlaySongEvent>(_onPlaySong);
    on<StartSongRadioEvent>(_onStartSongRadio);
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
    on<AddRecommendationsEvent>(_onAddRecommendations);
    on<_IndexChangedEvent>(_onIndexChanged);
    on<_TrackStalledEvent>(_onTrackStalled);
    on<ToggleAutoPlayEvent>(_onToggleAutoPlay);
    on<MarkSongNotInterestedEvent>(_onMarkSongNotInterested);
    on<SwitchStreamSourceEvent>(_onSwitchStreamSource);
    on<RestoreQueueEvent>(_onRestoreQueue);
    on<ClearPersistedQueueEvent>(_onClearPersistedQueue);
    on<ToggleVideoModeEvent>(_onToggleVideoMode);
    on<VideoPositionChangedEvent>(_onVideoPositionChanged);
    on<SetVideoBufferingEvent>(_onSetVideoBuffering);
    on<CrossfadeStateChangedEvent>((event, emit) {
      emit(state.copyWith(isCrossfading: event.isCrossfading));
    });

    // Initialize audio player stream listeners
    _initAudioPlayerStreams();
    unawaited(_audioFocus.initialize());

    // Add app lifecycle observer to keep audio session active in background
    WidgetsBinding.instance.addObserver(this);

    // Load persisted performance-related settings
    _loadSettings();
  }

  @override
  void onChange(Change<PlayerState> change) {
    super.onChange(change);
    final songChanged =
        change.currentState.currentSong?.playableId != change.nextState.currentSong?.playableId;
    if (songChanged || change.currentState.isPlaying != change.nextState.isPlaying) {
      _syncWidgetState(change.nextState.currentSong, change.nextState.isPlaying);
    }
    if (songChanged && change.nextState.currentSong != null) {
      try {
        unawaited(_audioPlayer.equalizer.applyPresetForSong(change.nextState.currentSong!.playableId));
      } catch (_) {}
    }
  }

  void _syncWidgetState(Song? song, bool isPlaying) {
    if (song == null) {
      if (_lastWidgetSongKey == null && _lastWidgetIsPlaying == false) return;
      _lastWidgetSongKey = null;
      _lastWidgetIsPlaying = false;
      _lastWidgetArtworkPath = null;
      unawaited(WidgetService.instance.updateWidget(
        title: 'Prism Music',
        artist: 'No song playing',
        isPlaying: false,
      ));
      return;
    }

    final localPath = _downloadedPathFor(song);
    String? knownArtwork;

    // 1. Check in-memory cache
    if (song.thumbnailUrl.isNotEmpty) {
      final cached = _widgetArtworkPathCache[song.thumbnailUrl];
      if (cached != null) {
        if (File(cached).existsSync()) {
          knownArtwork = cached;
        } else {
          _widgetArtworkPathCache.remove(song.thumbnailUrl);
        }
      }
    }

    // 2. Check if local audio file directory has artwork or if local file exists
    if (knownArtwork == null && localPath != null && localPath.isNotEmpty) {
      final localArtwork = '$localPath.art';
      if (File(localArtwork).existsSync()) {
        knownArtwork = localArtwork;
      }
    }

    // 3. Skip update if exact state was already sent
    if (_lastWidgetSongKey == song.playableId &&
        _lastWidgetIsPlaying == isPlaying &&
        _lastWidgetArtworkPath == knownArtwork) {
      return;
    }

    _lastWidgetSongKey = song.playableId;
    _lastWidgetIsPlaying = isPlaying;
    _lastWidgetArtworkPath = knownArtwork;

    // Single-call dispatch if artwork is already known
    unawaited(WidgetService.instance.updateWidget(
      title: song.title,
      artist: song.artist,
      isPlaying: isPlaying,
      artworkPath: knownArtwork,
    ));

    // If artwork not yet in cache, fetch it asynchronously once
    if (knownArtwork == null && song.thumbnailUrl.isNotEmpty) {
      unawaited(_fetchAndSyncWidgetArtwork(song, isPlaying));
    }
  }

  Future<void> _fetchAndSyncWidgetArtwork(Song song, bool isPlaying) async {
    try {
      final fileInfo = await DefaultCacheManager().getFileFromCache(song.thumbnailUrl);
      if (fileInfo != null && await fileInfo.file.exists()) {
        final path = fileInfo.file.path;
        if (_widgetArtworkPathCache.length >= _maxWidgetArtworkCacheSize) {
          _widgetArtworkPathCache.remove(_widgetArtworkPathCache.keys.first);
        }
        _widgetArtworkPathCache[song.thumbnailUrl] = path;

        // If the same song is still current, push artwork update
        if (state.currentSong?.playableId == song.playableId) {
          _lastWidgetArtworkPath = path;
          await WidgetService.instance.updateWidget(
            title: song.title,
            artist: song.artist,
            isPlaying: state.isPlaying,
            artworkPath: path,
          );
        }
      }
    } catch (_) {
      // Best-effort artwork sync
    }
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

    _crossfadeSubscription = _audioPlayer.isCrossfadingStream.listen((isCrossfading) {
      if (!isClosed) add(CrossfadeStateChangedEvent(isCrossfading));
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

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _persistCurrentSession();
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

          if (_settingsService.restoreQueueOnLaunch) {
            QueuePersistenceService.instance.getSavedSession().then((session) {
              if (session != null &&
                  !isClosed &&
                  state.currentSong == null &&
                  _playbackGeneration == 0) {
                add(
                  RestoreQueueEvent(
                    currentSong: session.currentSong,
                    queue: session.queue,
                    queueIndex: session.queueIndex,
                    position: session.position,
                    autoPlay: false, // Strict no surprise auto-play
                  ),
                );
              }
            }).catchError((_) {});
          }
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
    // Respect requested user quality directly without permanent degradation (M08)
    if (!_fastStartEnabled) return requestedQuality;
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

    _safePrefetchUpcomingArtwork(queue, currentIndex);
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

  /// Watchdog for tracks the native queue advanced to on its own (auto-advance
  /// or skip). Unlike [_onPlaySong] they have no timeout of their own, so a
  /// track whose source never loads would leave the player silent forever.
  /// See [_armTrackStartWatchdog].
  final Duration _trackStartWatchdogTimeout;
  Timer? _trackStartWatchdog;

  /// A track counts as started once its position has moved past this.
  static const Duration _trackStartMinProgress = Duration(seconds: 1);

  Future<void> _onStartSongRadio(
    StartSongRadioEvent event,
    Emitter<PlayerState> emit,
  ) async {
    _log('Starting Song Radio for: ${event.seedSong.title}');
    var radioQueue = <Song>[event.seedSong];

    if (_recommendationService != null) {
      try {
        final generated = await _recommendationService!.generateSongRadio(
          event.seedSong,
          count: 25,
        );
        if (generated.isNotEmpty) {
          radioQueue = generated;
        }
      } catch (e) {
        _log('Failed to generate radio queue: $e');
      }
    }

    add(PlaySongEvent(
      song: event.seedSong,
      queue: radioQueue,
      queueIndex: 0,
      userInitiated: true,
    ));
  }
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
    // This attempt has its own timeouts and error handling; a watchdog armed
    // for an earlier native auto-advance no longer applies.
    _cancelTrackStartWatchdog();

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
    Song songToPlay = event.song;

    // Offline check & fallback to downloaded tracks
    if (OfflineModeService.instance.isOffline &&
        !_downloadService.isDownloaded(songToPlay.playableId)) {
      _log(
        'PlayerBloc: Offline mode active and "${songToPlay.title}" is not downloaded. Searching for offline fallback.',
      );

      // 1. Try to find a downloaded song within the initial queue
      int fallbackIndex = -1;
      for (int i = 0; i < initialQueue.length; i++) {
        if (_downloadService.isDownloaded(initialQueue[i].playableId)) {
          fallbackIndex = i;
          break;
        }
      }

      if (fallbackIndex != -1) {
        songToPlay = initialQueue[fallbackIndex];
        initialQueueIndex = fallbackIndex;
        _log('PlayerBloc: Found downloaded song in queue: "${songToPlay.title}"');
      } else {
        // 2. Queue has no downloaded songs; fall back to library downloads
        final downloadedSongs = _downloadService.getDownloadedSongsList();
        if (downloadedSongs.isNotEmpty) {
          songToPlay = downloadedSongs.first;
          initialQueue = List<Song>.from(downloadedSongs);
          initialQueueIndex = 0;
          _log(
            'PlayerBloc: Falling back to downloaded library track: "${songToPlay.title}"',
          );
        } else {
          // 3. No downloaded songs exist anywhere
          emit(
            state.copyWith(
              status: PlayerStatus.error,
              errorMessage:
                  'Offline mode: No downloaded songs available. Connect to internet or download tracks.',
            ),
          );
          return;
        }
      }
    }

    // Honor the persisted Auto Shuffle preference: on a user-initiated play
    // of a multi-song queue, shuffle the remaining songs behind the picked
    // track. (The toggle used to persist a value nothing ever read.)
    if (event.userInitiated &&
        event.queue != null &&
        initialQueue.length > 1 &&
        _settingsService.autoShuffle) {
      final shuffled = [...initialQueue];
      final picked = shuffled.removeAt(initialQueueIndex);
      shuffled.shuffle();
      initialQueue = [picked, ...shuffled];
      initialQueueIndex = 0;
    }

    if (event.userInitiated) {
      _attemptedFreshResolutions.remove(songToPlay.playableId);
    }

    final Song? previousSong = state.currentSong;

    // Update UI immediately with the song info (before loading)
    emit(
      state.copyWith(
        status: PlayerStatus.loading,
        loadingStage: PlayerLoadingStage.resolving,
        currentSong: songToPlay,
        position: Duration.zero,
        duration: Duration.zero,
        queue: initialQueue,
        originalQueue: List<Song>.from(initialQueue),
        queueIndex: initialQueueIndex,
        clearVideoStreamInfo: true,
        clearPlaybackNotification: true,
      ),
    );
    _lastNearEndPrefetchIndex = -1; // reset for new track
    _lastRecommendationSongId =
        null; // allow fresh recommendations for new track or queue

    // Reset scrobbling and history recording flags for new song
    resetScrobbleState();

    try {
      _refreshRuntimeSettings();
      _audioFocus.notifyUserPaused(false);
      // JIT permission: ask for notification permission on initial playback so
      // media playback controls work on Android 13+ lock screen / status bar.
      unawaited(PermissionService.requestNotificationPermissionOnce());
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
      final preResolved = event.preferredResolver != null
          ? null
          : _mediaResolver.takePreResolved(songToPlay.playableId);
      final usedPreResolved = preResolved != null;
      final resolvedSource =
          preResolved ??
          await (_mediaResolver
              .resolveForPlayback(
                songToPlay,
                preferredQuality: playbackQuality,
                preferredResolverName: event.preferredResolver,
              )
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
          'PlayerBloc: Starting playback for: ${songToPlay.title} '
          '(offline=${resolvedSource.isOffline})',
        );

        final shouldCrossfade =
            _crossfadeDurationSeconds > 0 &&
            previousSong != null &&
            _audioPlayer.playing &&
            previousSong.playableId != songToPlay.playableId;

        final setSourceStopwatch = Stopwatch()..start();
        // Notification artwork prefers the medium thumbnail: YouTube's
        // maxres URLs frequently 404, which leaves the media card art-less.
        final notificationArtwork =
            songToPlay.thumbnails.medium ?? songToPlay.thumbnailUrl;
        final isYouTubeSong = (songToPlay.source == MusicSource.youtube ||
                songToPlay.source == MusicSource.youtubeMusic ||
                songToPlay.youtubeId != null) &&
            songToPlay.playableId.isNotEmpty;

        emit(
          state.copyWith(
            loadingStage: PlayerLoadingStage.buffering,
          ),
        );

        final duration = shouldCrossfade
            ? await _audioPlayer
                  .crossfadeTo(
                    resolvedSource.uri,
                    headers: resolvedSource.headers,
                    videoId: resolvedSource.videoId,
                    quality: _mapAudioQuality(state.audioQuality),
                    title: songToPlay.title,
                    artist: songToPlay.artist,
                    album: songToPlay.album,
                    artworkUrl: notificationArtwork,
                    mediaDuration: songToPlay.duration,
                    duration: Duration(
                      milliseconds: (_crossfadeDurationSeconds * 1000)
                          .round()
                          .clamp(0, 10000),
                    ),
                    allowYouTubeFallbackOnDirectFailure: isYouTubeSong,
                  )
                  .timeout(_setSourceTimeout)
            : (initialQueue.length > 1)
                ? await _loadAudioQueueSafe(
                    initialQueue,
                    queueIndex,
                    songToPlay,
                    resolvedSource,
                    notificationArtwork,
                    isYouTubeSong,
                  )
                : await _audioPlayer
                      .setUrl(
                        resolvedSource.uri,
                        headers: resolvedSource.headers,
                        videoId: resolvedSource.videoId,
                        quality: _mapAudioQuality(state.audioQuality),
                        title: songToPlay.title,
                        artist: songToPlay.artist,
                        album: songToPlay.album,
                        artworkUrl: notificationArtwork,
                        mediaDuration: songToPlay.duration,
                        allowYouTubeFallbackOnDirectFailure: isYouTubeSong,
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

        _log('PlayerBloc: Playback started, duration: $duration');

        // F01: Treat playback startup and lifetime completion as separate operations.
        // Commit playing status, metadata, and history immediately without awaiting
        // the entire playback lifetime of the song.
        final resumePos = event.initialPosition ?? Duration.zero;
        if (resumePos > Duration.zero) {
          try {
            await _audioPlayer.seek(resumePos);
          } catch (_) {}
        }

        emit(
          state.copyWith(
            status: PlayerStatus.playing,
            loadingStage: PlayerLoadingStage.none,
            currentSong: songToPlay,
            currentStreamInfo: resolvedSource.streamInfo,
            originalQueue: state.originalQueue.isNotEmpty
                ? state.originalQueue
                : state.queue,
            queueIndex: queueIndex,
            position: resumePos,
          ),
        );

        _libraryRepository.addToHistory(songToPlay);
        _recommendationService?.recordPlay(songToPlay);
        _reliability.registerSuccess(songToPlay.playableId);
        _attemptedFreshResolutions.remove(songToPlay.playableId);
        _consecutiveFailureSkips = 0;
        updateNowPlaying(songToPlay);
        try {
          _libraryRepository.isSongLiked(songToPlay.id).then((liked) {
            final isDown = _downloadService.isDownloaded(songToPlay.playableId);
            final qLabel = isDown ? 'Offline • Downloaded' : state.audioQuality.displayName;
            MediaSessionCoordinator.instance.updatePlaybackInfo(
              isLiked: liked,
              qualityLabel: qLabel,
            );
          }).catchError((_) {});
        } catch (_) {
          final isDown = _downloadService.isDownloaded(songToPlay.playableId);
          final qLabel = isDown ? 'Offline • Downloaded' : state.audioQuality.displayName;
          MediaSessionCoordinator.instance.updatePlaybackInfo(
            isLiked: songToPlay.isLiked,
            qualityLabel: qLabel,
          );
        }
        _persistCurrentSession(customPosition: resumePos);
        // Position in the queue changed → notification skip buttons may
        // have become usable/unusable.
        MediaSessionCoordinator.instance.notifyQueueChanged();
        try {
          _audioPlayer.applySongNormalization(songToPlay);
        } catch (_) {}
        _safePrefetchUpcomingArtwork(state.queue, queueIndex);

        if (!shouldCrossfade) {
          unawaited(
            _audioPlayer.play().catchError((playError, st) {
              _log('PlayerBloc: Async play execution error: $playError');
              if (generation == _playbackGeneration && !isClosed) {
                _handlePlaybackError(
                  emit,
                  failedSong: songToPlay,
                  error: playError,
                  queue: state.queue,
                  queueIndex: queueIndex,
                  stackTrace: st,
                  generation: generation,
                );
              }
            }),
          );
        }

        if (generation != _playbackGeneration) return; // user moved on

        _prefetchAhead(state.queue, queueIndex, quality: playbackQuality);
      } catch (playbackError, stackTrace) {
        if (generation != _playbackGeneration) return; // user moved on
        _handlePlaybackError(
          emit,
          failedSong: songToPlay,
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
        failedSong: songToPlay,
        error: e,
        queue: event.queue ?? state.queue,
        queueIndex: event.queueIndex ?? state.queueIndex,
        isOffline: false,
        stackTrace: stackTrace,
        generation: generation,
      );
    }
  }



  Future<void> _onResume(ResumeEvent event, Emitter<PlayerState> emit) async {
    _log('PlayerBloc: _onResume called');
    _log('  - currentSong: ${state.currentSong?.title}');
    _log('  - current status: ${state.status}');

    // If session was restored paused from previous app run, user tapping play resumes playback
    if (state.isRestoredSession && state.currentSong != null) {
      _log('  - Restored session resuming playback');
      emit(state.copyWith(isRestoredSession: false));
      add(
        PlaySongEvent(
          song: state.currentSong!,
          queue: state.queue,
          queueIndex: state.queueIndex,
          userInitiated: true,
        ),
      );
      return;
    }

    // If player is in error state, user tapping play/resume initiates clean recovery
    if (state.currentSong != null && state.status == PlayerStatus.error) {
      _log('  - In error state, initiating fresh PlaySongEvent recovery');
      add(
        PlaySongEvent(
          song: state.currentSong!,
          queue: state.queue,
          queueIndex: state.queueIndex,
          userInitiated: true,
        ),
      );
      return;
    }

    // If player reached end of queue, user tapping play restarts queue from track 0
    if (state.currentSong != null && state.status == PlayerStatus.completed) {
      _log('  - In completed state, restarting queue from track 0');
      final firstSong =
          state.queue.isNotEmpty ? state.queue.first : state.currentSong!;
      add(
        PlaySongEvent(
          song: firstSong,
          queue: state.queue,
          queueIndex: 0,
          userInitiated: true,
        ),
      );
      return;
    }

    // Proactively check stream URL freshness before playback resume.
    // If stream URL is expired or cache is stale (e.g. paused for hours), invalidate cache and re-resolve.
    if (state.currentSong != null &&
        !_downloadService.isDownloaded(state.currentSong!.playableId)) {
      final currentUrl = state.currentStreamInfo?.url ?? state.currentSong!.streamUrl;
      final isUrlExpired = currentUrl != null && StreamCacheService.isUrlExpired(currentUrl);
      final isCacheStale = state.currentStreamInfo != null &&
          !_streamLoader.isStreamFresh(state.currentSong!, preferredQuality: state.audioQuality);

      if (isUrlExpired || isCacheStale) {
        _log(
          'PlayerBloc: Stream URL for "${state.currentSong!.title}" is expired/stale on resume. '
          'Proactively invalidating cache and re-resolving stream.',
        );
        _mediaResolver.invalidate(state.currentSong!.playableId);
        _attemptedFreshResolutions.remove(state.currentSong!.playableId);
        add(
          PlaySongEvent(
            song: state.currentSong!,
            queue: state.queue,
            queueIndex: state.queueIndex,
            userInitiated: true,
            initialPosition: state.position,
          ),
        );
        return;
      }
    }

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
      _audioFocus.notifyUserPaused(false);
      await _audioPlayer.play();
      emit(state.copyWith(status: PlayerStatus.playing));
    } else {
      _log(
        '  - Cannot resume: status is ${state.status}, need paused/ready state',
      );
    }
  }

  Future<void> _onPause(PauseEvent event, Emitter<PlayerState> emit) async {
    _playbackGeneration++;
    _audioFocus.notifyUserPaused(true);
    await _audioPlayer.pause();
    await _audioFocus.deactivate();
    emit(state.copyWith(status: PlayerStatus.paused));
    _persistCurrentSession();
  }

  Future<void> _onTogglePlayPause(
    TogglePlayPauseEvent event,
    Emitter<PlayerState> emit,
  ) async {
    // In video mode the video surface owns playback and its widget already
    // toggled itself. Forwarding here would resume the paused audio track and
    // bring back the double-audio echo.
    if (state.isVideoMode) {
      emit(
        state.copyWith(
          status: state.isPlaying ? PlayerStatus.paused : PlayerStatus.playing,
        ),
      );
      return;
    }

    if (state.isPlaying) {
      add(const PauseEvent());
    } else {
      add(const ResumeEvent());
    }
  }

  /// Track changes end video mode: the audio engine owns the next track, so
  /// keeping the video surface alive would play both engines at once.
  void _releaseVideoModeForTrackChange(Emitter<PlayerState> emit) {
    if (!state.isVideoMode) return;
    _videoPosition = null;
    _resumeAudioAfterVideo = false;
    emit(state.copyWith(isVideoMode: false, isVideoBuffering: false));
  }

  Future<void> _onNext(NextEvent event, Emitter<PlayerState> emit) async {
    _releaseVideoModeForTrackChange(emit);

    if (state.sleepTimerEndOfTrack) {
      cancelSleepTimer();
      emit(state.copyWith(clearSleepTimer: true, sleepTimerEndOfTrack: false));
    }

    if (_audioPlayer.isQueueMode && _audioPlayer.hasNext) {
      _reliability.resetCircuitBreaker();
      _lastNearEndPrefetchIndex = -1;
      await _audioPlayer.skipToNext();
      return;
    }

    if (state.hasNext) {
      // A manual skip is explicit user intent: clear any open circuit and
      // per-song retry budgets so the target song always gets a real attempt.
      _reliability.resetCircuitBreaker();
      int nextIndex = state.queueIndex + 1;
      if (OfflineModeService.instance.isOffline) {
        int found = -1;
        for (int i = state.queueIndex + 1; i < state.queue.length; i++) {
          if (_downloadService.isDownloaded(state.queue[i].playableId)) {
            found = i;
            break;
          }
        }
        if (found != -1) {
          nextIndex = found;
        } else if (state.repeatMode == RepeatMode.all) {
          for (int i = 0; i < state.queue.length; i++) {
            if (_downloadService.isDownloaded(state.queue[i].playableId)) {
              found = i;
              break;
            }
          }
          if (found != -1) nextIndex = found;
        }
      }
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
    _releaseVideoModeForTrackChange(emit);

    if (state.sleepTimerEndOfTrack) {
      cancelSleepTimer();
      emit(state.copyWith(clearSleepTimer: true, sleepTimerEndOfTrack: false));
    }

    if (_audioPlayer.isQueueMode && _audioPlayer.hasPrevious) {
      _reliability.resetCircuitBreaker();
      _lastNearEndPrefetchIndex = -1;
      await _audioPlayer.skipToPrevious();
      return;
    }

    if (state.hasPrevious) {
      // Same as _onNext: user intent overrides the circuit breaker.
      _reliability.resetCircuitBreaker();
      int prevIndex = state.queueIndex - 1;
      if (OfflineModeService.instance.isOffline) {
        int found = -1;
        for (int i = state.queueIndex - 1; i >= 0; i--) {
          if (_downloadService.isDownloaded(state.queue[i].playableId)) {
            found = i;
            break;
          }
        }
        if (found != -1) prevIndex = found;
      }
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
    _persistCurrentSession(customPosition: event.position);
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
      // Enable shuffle - preserve the active track pointer
      final current = state.currentSong;
      final currentIdx = state.queueIndex;
      final original = List<Song>.from(
        state.originalQueue.isNotEmpty ? state.originalQueue : state.queue,
      );

      final shuffled = List<Song>.from(state.queue);
      if (current != null && currentIdx >= 0 && currentIdx < shuffled.length) {
        final activeSong = shuffled.removeAt(currentIdx);
        shuffled.shuffle();
        shuffled.insert(0, activeSong);
        emit(state.copyWith(
          isShuffleEnabled: true,
          queue: shuffled,
          originalQueue: original,
          queueIndex: 0,
        ));
      } else {
        shuffled.shuffle();
        emit(state.copyWith(
          isShuffleEnabled: true,
          queue: shuffled,
          originalQueue: original,
        ));
      }
      MediaSessionCoordinator.instance.notifyQueueChanged();
    } else if (!event.enabled && state.isShuffleEnabled) {
      // Disable shuffle - restore original queue while preserving active track
      final restored = List<Song>.from(
        state.originalQueue.isNotEmpty ? state.originalQueue : state.queue,
      );
      int originalIndex = -1;
      if (state.currentSong != null) {
        originalIndex = restored.indexWhere(
          (s) => s.playableId == state.currentSong!.playableId,
        );
      }
      if (originalIndex == -1) {
        originalIndex = state.queueIndex.clamp(
          0,
          (restored.length - 1).clamp(0, 999999),
        );
      }

      emit(state.copyWith(
        isShuffleEnabled: false,
        queue: restored,
        queueIndex: originalIndex,
      ));
      MediaSessionCoordinator.instance.notifyQueueChanged();
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
    final updatedOriginal = List<Song>.from(
      state.originalQueue.isNotEmpty ? state.originalQueue : state.queue,
    );
    if (event.playNext) {
      final insertIndex = (state.queueIndex + 1).clamp(0, updatedQueue.length);
      updatedQueue.insert(insertIndex, event.song);
      updatedOriginal.add(event.song);
    } else {
      updatedQueue.add(event.song);
      updatedOriginal.add(event.song);
    }

    emit(state.copyWith(queue: updatedQueue, originalQueue: updatedOriginal));
    MediaSessionCoordinator.instance.notifyQueueChanged();
    _persistCurrentSession();

    _safePrefetchSongArtwork(event.song);
    final preferredQuality = _startupQuality(state.audioQuality);
    _streamLoader.prefetch(event.song, preferredQuality: preferredQuality);
    _prefetchAhead(updatedQueue, state.queueIndex, quality: preferredQuality);
  }

  Future<void> _onRemoveFromQueue(
    RemoveFromQueueEvent event,
    Emitter<PlayerState> emit,
  ) async {
    if (event.index < 0 || event.index >= state.queue.length) return;

    final removedSong = state.queue[event.index];
    final updatedQueue = List<Song>.from(state.queue)..removeAt(event.index);

    final updatedOriginal = List<Song>.from(
      state.originalQueue.isNotEmpty ? state.originalQueue : state.queue,
    );
    final origIdx = updatedOriginal.indexWhere(
      (s) => s.playableId == removedSong.playableId,
    );
    if (origIdx != -1) {
      updatedOriginal.removeAt(origIdx);
    }

    int newIndex = state.queueIndex;
    if (event.index < state.queueIndex) {
      newIndex--;
    } else if (event.index == state.queueIndex) {
      // Removing the currently active track
      if (updatedQueue.isEmpty) {
        add(const StopEvent());
        emit(state.copyWith(
          queue: const [],
          originalQueue: const [],
          queueIndex: 0,
          currentSong: null,
        ));
        MediaSessionCoordinator.instance.notifyQueueChanged();
        return;
      } else {
        if (newIndex >= updatedQueue.length) {
          newIndex = updatedQueue.length - 1;
        }
        final nextSong = updatedQueue[newIndex];
        add(PlaySongEvent(
          song: nextSong,
          queue: updatedQueue,
          queueIndex: newIndex,
        ));
        return;
      }
    }

    if (updatedQueue.isNotEmpty && newIndex >= updatedQueue.length) {
      newIndex = updatedQueue.length - 1;
    }

    emit(state.copyWith(
      queue: updatedQueue,
      originalQueue: updatedOriginal,
      queueIndex: newIndex,
    ));
    MediaSessionCoordinator.instance.notifyQueueChanged();
    _persistCurrentSession();
  }

  Future<void> _onReorderQueue(
    ReorderQueueEvent event,
    Emitter<PlayerState> emit,
  ) async {
    if (event.oldIndex < 0 ||
        event.oldIndex >= state.queue.length ||
        event.newIndex < 0 ||
        event.newIndex >= state.queue.length ||
        event.oldIndex == event.newIndex) {
      return;
    }

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
    MediaSessionCoordinator.instance.notifyQueueChanged();
    _persistCurrentSession();
    _safePrefetchUpcomingArtwork(updatedQueue, newIndex);
  }

  Future<void> _onClearQueue(
    ClearQueueEvent event,
    Emitter<PlayerState> emit,
  ) async {
    final preserved = state.currentSong != null
        ? [state.currentSong!]
        : <Song>[];
    emit(
      state.copyWith(
        queue: preserved,
        originalQueue: preserved,
        queueIndex: 0,
      ),
    );
    MediaSessionCoordinator.instance.notifyQueueChanged();
    _persistCurrentSession();
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
    _safeCancelSleepTimer();

    if (event.endOfTrack) {
      emit(
        state.copyWith(
          sleepTimerEndOfTrack: true,
          sleepTimerBedtimeMode: event.bedtimeMode,
          clearSleepTimer: true,
        ),
      );
      return;
    }

    final duration = event.duration;
    if (duration == null || duration <= Duration.zero) {
      emit(state.copyWith(
        clearSleepTimer: true,
        sleepTimerEndOfTrack: false,
        sleepTimerBedtimeMode: false,
      ));
      return;
    }

    final isBedtime = event.bedtimeMode || _settingsService.sleepTimerBedtimeMode;
    if (isBedtime) {
      _preSleepTimerVolume = _audioPlayer.volume;
    }

    emit(
      state.copyWith(
        sleepTimerEnd: DateTime.now().add(duration),
        sleepTimerEndOfTrack: false,
        sleepTimerBedtimeMode: isBedtime,
      ),
    );
    startSleepTimer(
      duration,
      bedtimeMode: isBedtime,
      onVolumeFade: (factor) {
        final target = (_preSleepTimerVolume * factor).clamp(0.0, 1.0);
        _audioPlayer.setVolume(target);
      },
      onRestoreVolume: () {
        if (isBedtime) {
          _audioPlayer.setVolume(_preSleepTimerVolume);
        }
      },
      onElapsed: () {
        // Two events: pause playback first, then surface the cleared timer.
        add(const PauseEvent());
        add(const _SleepTimerClearedEvent());
      },
    );
  }

  void _onSleepTimerCleared(
    _SleepTimerClearedEvent event,
    Emitter<PlayerState> emit,
  ) {
    emit(state.copyWith(
      clearSleepTimer: true,
      sleepTimerEndOfTrack: false,
      sleepTimerBedtimeMode: false,
    ));
  }

  Future<void> _onStop(StopEvent event, Emitter<PlayerState> emit) async {
    _playbackGeneration++;
    _cancelTrackStartWatchdog();
    cancelSleepTimer();
    await _audioPlayer.stop();
    await _audioFocus.deactivate();
    _reliability.resetCircuitBreaker();
    emit(const PlayerState());
    MediaSessionCoordinator.instance.notifyQueueChanged();
  }

  void _onPositionUpdate(PositionUpdateEvent event, Emitter<PlayerState> emit) {
    emit(state.copyWith(position: event.position));

    if (state.sleepTimerEndOfTrack &&
        state.duration > Duration.zero &&
        event.position >= state.duration) {
      _log('PlayerBloc: End-of-track sleep timer reached track duration limit');
      cancelSleepTimer();
      unawaited(_audioPlayer.pause());
      emit(state.copyWith(
        clearSleepTimer: true,
        sleepTimerEndOfTrack: false,
        status: PlayerStatus.paused,
      ));
      return;
    }

    // Attempt scrobbling and record listening session when duration thresholds are met
    final currentSong = state.currentSong;
    if (currentSong != null) {
      if (state.duration.inSeconds > 0) {
        attemptScrobble(currentSong, event.position, state.duration);
      }
      attemptRecordListeningSession(
        song: currentSong,
        position: event.position,
        duration: state.duration,
        libraryRepository: _libraryRepository,
        recommendationService: _recommendationService,
      );
    }

    // Check if we need to add recommendations (when less than 5 songs remaining)
    _checkAndAddRecommendations();

    // Ensure next track is prefetched when nearing end of current song
    _maybePrefetchUpcomingNearEnd(event.position);

    final now = DateTime.now();
    if (now.difference(_lastPositionPersistTime).inSeconds >= 5) {
      _lastPositionPersistTime = now;
      _persistCurrentSession(customPosition: event.position);
    }
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

    // While video mode is active the video surface is the playback source; the
    // paused audio engine must not overwrite the shown play/pause state.
    if (state.isVideoMode) return;
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
    handleTrackCompleted(
      currentSong: state.currentSong,
      libraryRepository: _libraryRepository,
      recommendationService: _recommendationService,
    );

    if (state.sleepTimerEndOfTrack) {
      _log('PlayerBloc: End-of-track sleep timer triggered on track completed');
      cancelSleepTimer();
      await _audioPlayer.pause();
      emit(state.copyWith(
        clearSleepTimer: true,
        sleepTimerEndOfTrack: false,
        status: PlayerStatus.paused,
      ));
      return;
    }

    // Auto-play next song if available
    if (state.repeatMode == RepeatMode.one) {
      if (state.currentSong != null) {
        if (_consecutiveFailureSkips >= 3) {
          _consecutiveFailureSkips = 0;
          emit(
            state.copyWith(status: PlayerStatus.paused, position: Duration.zero),
          );
          return;
        }
        emit(
          state.copyWith(status: PlayerStatus.loading, position: Duration.zero),
        );
        add(
          PlaySongEvent(
            song: state.currentSong!,
            queue: state.queue,
            queueIndex: state.queueIndex,
          ),
        );
        return;
      }
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
        state.copyWith(
          status: PlayerStatus.completed,
          position: Duration.zero,
        ),
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

    final songId = failedSong.playableId;
    final is403 = _is403OrForbidden(error);
    final hasAttemptedFresh = _attemptedFreshResolutions.contains(songId);

    // Stale/expired stream recovery: if a cached or pre-resolved stream URL returns 403 Forbidden,
    // invalidate the cache and attempt exactly one fresh URL resolution before giving up.
    if (is403 && !isOffline && !hasAttemptedFresh && !isStale()) {
      _attemptedFreshResolutions.add(songId);
      _log(
        'PlayerBloc: Stale/Expired stream (403 Forbidden) detected for "${failedSong.title}". '
        'Invalidating cache and attempting fresh URL resolution.',
      );
      emit(
        state.copyWith(
          status: PlayerStatus.loading,
          errorMessage: 'Refreshing expired stream...',
        ),
      );
      Future.delayed(const Duration(milliseconds: 100), () {
        if (isClosed || isStale()) return;
        add(
          PlaySongEvent(
            song: failedSong,
            queue: queue,
            queueIndex: queueIndex,
            userInitiated: false,
          ),
        );
      });
      return;
    }

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
          loadingStage: PlayerLoadingStage.resolving,
          currentSong: nextSong,
          queue: effectiveQueue,
          queueIndex: nextIndex,
          position: Duration.zero,
          duration: Duration.zero,
          errorMessage: 'Skipping unplayable track: "${failedSong.title}"',
          playbackNotification: "Couldn't play '${failedSong.title}' — skipped",
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
    final errorMsg = effectiveQueue.length > 1 && consecutiveSkips >= 3
        ? 'Multiple songs failed to play. Please check your connection and try again.'
        : 'Playback error: $error';
    emit(
      state.copyWith(
        status: PlayerStatus.error,
        loadingStage: PlayerLoadingStage.none,
        errorMessage: errorMsg,
        playbackNotification: "Couldn't play '${failedSong.title}'",
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
    if (!state.autoPlay || !_settingsService.autoPlay) return;
    // Do not append recommendations when looping track or full queue
    if (state.repeatMode != RepeatMode.off) return;
    if (state.queue.length >= 50) return;

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

    final requestGen = ++_recommendationGeneration;

    // If queue is empty after current song, fetch immediately so Up Next is ready.
    // Otherwise use a short delay to avoid rapid calls.
    final delay = songsRemaining == 0
        ? Duration.zero
        : const Duration(milliseconds: 500);

    Future.delayed(delay, () async {
      // Skip if the user has already moved on to a different song or generation changed
      if (requestGen != _recommendationGeneration ||
          state.currentSong?.playableId != currentSong.playableId) {
        return;
      }

      _log('Fetching recommendations for: ${currentSong.title}');
      await _fetchAndAppendRecommendations(currentSong, requestGen);
    });
  }

  /// Fetch recommendations for [seedSong] and append them to the queue.
  /// Falls back to the repository's own recommendation feed when the
  /// recommendation service returns nothing (e.g. algorithmic sources down).
  Future<void> _fetchAndAppendRecommendations(Song seedSong, int requestGen) async {
    final recommendationService = _recommendationService;
    if (recommendationService == null || _isFetchingRecommendations) return;

    _isFetchingRecommendations = true;
    try {
      final recommendations = await recommendationService.getRecommendations(
        currentSong: seedSong,
        limit: _recommendationBatchSize,
      );

      if (requestGen != _recommendationGeneration) return;

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

      if (requestGen != _recommendationGeneration) return;

      fallback.fold(
        (failure) => _log(
          'Repository recommendation fallback failed: ${failure.message}',
        ),
        (songs) {
          if (songs.isNotEmpty && requestGen == _recommendationGeneration) {
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
    final availableCapacity = 50 - state.queue.length;
    if (availableCapacity <= 0) return;

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
      if (uniqueSongs.length >= availableCapacity) break;
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
      // Keep the native ConcatenatingAudioSource in lock-step with the bloc
      // queue. Without this the native queue ends early, completion handling
      // has to rebuild the whole queue from scratch, and playback stalls or
      // jumps instead of simply advancing to the next track.
      if (_audioPlayer.isQueueMode) {
        final quality = _mapAudioQuality(state.audioQuality);
        final payload = uniqueSongs
            .map(
              (s) => <String, dynamic>{
                'videoId': s.playableId,
                'url': _downloadedPathFor(s) ?? s.streamUrl ?? '',
                'headers': null,
                'quality': quality,
                'title': s.title,
                'artist': s.artist,
                'artUri': s.thumbnails.medium ?? s.thumbnailUrl,
                'album': s.album,
              },
            )
            .toList();
        unawaited(_audioPlayer.appendToQueue(payload));
      }
      // Next button in the media notification may now be usable.
      MediaSessionCoordinator.instance.notifyQueueChanged();
    }
  }

  /// Toggle autoplay on or off
  Future<void> _onToggleAutoPlay(
    ToggleAutoPlayEvent event,
    Emitter<PlayerState> emit,
  ) async {
    final next = !state.autoPlay;
    await _settingsService.setAutoPlay(next);
    emit(state.copyWith(autoPlay: next));
    if (next) {
      _checkAndAddRecommendations();
    }
  }

  /// Mark song as not interested: blacklist from recommendation service and remove from queue
  Future<void> _onMarkSongNotInterested(
    MarkSongNotInterestedEvent event,
    Emitter<PlayerState> emit,
  ) async {
    final song = event.song;
    await _settingsService.markSongNotInterested(song.playableId);
    if (song.id.isNotEmpty && song.id != song.playableId) {
      await _settingsService.markSongNotInterested(song.id);
    }
    await _recommendationService?.markSongNotInterested(song);
    final targetIndex = state.queue.indexWhere((s) => s.playableId == song.playableId);
    if (targetIndex != -1) {
      add(RemoveFromQueueEvent(targetIndex));
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

    if (indexChanged && state.sleepTimerEndOfTrack) {
      _log(
        'PlayerBloc: End-of-track sleep timer triggered on queue track advance - pausing playback',
      );
      cancelSleepTimer();
      unawaited(_audioPlayer.pause());
      emit(
        state.copyWith(
          clearSleepTimer: true,
          sleepTimerEndOfTrack: false,
          status: PlayerStatus.paused,
        ),
      );
      return;
    }

    _log('PlayerBloc: Synced active queue item to: ${newSong.title}');

    // Reset scrobbling flags for new song
    resetScrobbleState();
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

    // The native queue moved on by itself: make sure this track really starts.
    _armTrackStartWatchdog(newSong, newIndex);

    // Update now playing and prefetch ahead.
    resetScrobbleState();
    updateNowPlaying(newSong);
    _safePrefetchUpcomingArtwork(state.queue, newIndex);
    _prefetchAhead(state.queue, newIndex);
    MediaSessionCoordinator.instance.notifyQueueChanged();
    // Add to history in background.
    _libraryRepository.addToHistory(newSong);
    _recommendationService?.recordPlay(newSong);

    // Check if we need more recommendations.
    _checkAndAddRecommendations();
  }

  /// Arms a one-shot timer for a track the native queue advanced to on its
  /// own. If, when it fires, the player claims to be playing but the track has
  /// made no progress, [_onTrackStalled] recovers it through the normal
  /// playback-error policy (fresh re-resolve, then skip).
  ///
  /// Without this such a track just sits in `loading`: [_onPlayerError]
  /// deliberately ignores errors while loading (it assumes [_onPlaySong] is
  /// handling them), but nothing is handling a native auto-advance.
  void _armTrackStartWatchdog(Song song, int index) {
    _trackStartWatchdog?.cancel();
    final generation = _playbackGeneration;
    _trackStartWatchdog = Timer(_trackStartWatchdogTimeout, () {
      if (isClosed) return;
      add(_TrackStalledEvent(song: song, index: index, generation: generation));
    });
  }

  void _cancelTrackStartWatchdog() {
    _trackStartWatchdog?.cancel();
    _trackStartWatchdog = null;
  }

  void _onTrackStalled(_TrackStalledEvent event, Emitter<PlayerState> emit) {
    try {
      // A newer playback attempt (or a stop) owns the player now.
      if (event.generation != _playbackGeneration) return;
      if (state.status == PlayerStatus.error) return;

      // The user moved on, or the track changed again, since the timer was set.
      final current = state.currentSong;
      if (current == null ||
          current.playableId != event.song.playableId ||
          state.queueIndex != event.index) {
        return;
      }

      // Paused (by the user, a sleep timer or video mode): nothing is stuck.
      if (!_audioPlayer.playing) return;

      // Audio is flowing: the track started fine.
      if (state.position >= _trackStartMinProgress) return;

      _log(
        'PlayerBloc: "${current.title}" made no progress within '
        '${_trackStartWatchdogTimeout.inSeconds}s of becoming the active queue '
        'track; recovering',
      );
      _handlePlaybackError(
        emit,
        failedSong: current,
        error: 'Track failed to start (stalled while loading)',
        queue: state.queue,
        queueIndex: state.queueIndex,
        // A timing heuristic must never delete a user's local download.
        isOffline: false,
        generation: event.generation,
      );
    } catch (e) {
      // The watchdog is a safety net; it must never take playback down itself.
      _log('PlayerBloc: Track watchdog failed: $e');
    }
  }

  /// Local file path of [song] when it has been downloaded, otherwise null.
  String? _downloadedPathFor(Song song) {
    try {
      final id = song.playableId;
      if (!_downloadService.isDownloaded(id)) return null;
      final path = _downloadService.getLocalPath(id);
      return (path != null && path.isNotEmpty) ? path : null;
    } catch (_) {
      return null;
    }
  }

  Future<Duration?> _loadAudioQueueSafe(
    List<Song> queue,
    int index,
    Song songToPlay,
    ResolvedMediaSource resolvedSource,
    String? notificationArtwork,
    bool isYouTubeSong,
  ) async {
    try {
      final songsPayload = queue.map((s) {
        final isCurrent = s.playableId == songToPlay.playableId;
        // Downloaded entries carry their local file path so the player loads
        // them from disk instead of resolving a network stream (which cannot
        // work offline). Other entries keep their stream URL, or are
        // resolved lazily when their turn comes.
        final url = isCurrent
            ? resolvedSource.uri
            : (_downloadedPathFor(s) ?? s.streamUrl ?? '');
        return <String, dynamic>{
          'videoId': s.playableId,
          'url': url,
          'headers': isCurrent ? resolvedSource.headers : null,
          'quality': _mapAudioQuality(state.audioQuality),
          'title': s.title,
          'artist': s.artist,
          'artUri': s.thumbnails.medium ?? s.thumbnailUrl,
          'album': s.album,
        };
      }).toList();

      // The user's prefetch setting also controls how many upcoming tracks
      // get their stream manifests warmed while the current one plays.
      final dur = await _audioPlayer
          .loadQueue(
            songsPayload,
            initialIndex: index,
            prewarmLookahead: _prefetchLookahead,
          )
          .timeout(_setSourceTimeout);
      if (dur != null) return dur;
    } catch (e) {
      _log('PlayerBloc: loadQueue failed ($e), falling back to single setUrl');
    }

    return await _audioPlayer
        .setUrl(
          resolvedSource.uri,
          headers: resolvedSource.headers,
          videoId: resolvedSource.videoId,
          quality: _mapAudioQuality(state.audioQuality),
          title: songToPlay.title,
          artist: songToPlay.artist,
          album: songToPlay.album,
          artworkUrl: notificationArtwork,
          mediaDuration: songToPlay.duration,
          allowYouTubeFallbackOnDirectFailure: isYouTubeSong,
        )
        .timeout(_setSourceTimeout);
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

  bool _is403OrForbidden(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('403') || message.contains('forbidden');
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

  Future<void> _onSwitchStreamSource(
    SwitchStreamSourceEvent event,
    Emitter<PlayerState> emit,
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
      emit(state.copyWith(
        errorMessage: 'Source switch error: $e',
      ));
    }
  }

  DateTime _lastPositionPersistTime = DateTime.fromMillisecondsSinceEpoch(0);

  void _onRestoreQueue(RestoreQueueEvent event, Emitter<PlayerState> emit) {
    if (state.currentSong != null || _playbackGeneration > 0) return;
    emit(
      state.copyWith(
        status: PlayerStatus.paused,
        currentSong: event.currentSong,
        queue: event.queue,
        originalQueue: event.queue,
        queueIndex: event.queueIndex,
        position: event.position,
        duration: event.currentSong.duration,
        isRestoredSession: true,
      ),
    );

    _syncWidgetState(event.currentSong, false);

    if (event.autoPlay) {
      add(
        PlaySongEvent(
          song: event.currentSong,
          queue: event.queue,
          queueIndex: event.queueIndex,
          userInitiated: true,
        ),
      );
    }
  }

  void _onClearPersistedQueue(
    ClearPersistedQueueEvent event,
    Emitter<PlayerState> emit,
  ) {
    unawaited(QueuePersistenceService.instance.clearSession());
    emit(state.copyWith(isRestoredSession: false));
  }

  Future<void> _onToggleVideoMode(
    ToggleVideoModeEvent event,
    Emitter<PlayerState> emit,
  ) async {
    final nextMode = event.enable ?? !state.isVideoMode;
    if (nextMode == state.isVideoMode) return;

    if (nextMode) {
      if (!state.hasVideoAvailable) {
        emit(state.copyWith(isVideoMode: false));
        return;
      }

      // The video stream carries its own muxed audio, so the just_audio engine
      // must stop before the video starts. Remember whether it was playing and
      // where, so exiting video mode can hand playback back seamlessly.
      final wasPlaying = state.isPlaying || _audioPlayer.playing;
      final startPosition = _audioPlayer.position;
      _resumeAudioAfterVideo = wasPlaying;
      _videoPosition = startPosition;
      await _audioPlayer.pause();

      emit(
        state.copyWith(
          isVideoMode: true,
          isVideoBuffering: state.videoStreamInfo == null,
          status:
              wasPlaying ? PlayerStatus.playing : PlayerStatus.paused,
          position: startPosition,
        ),
      );

      if (state.videoStreamInfo == null && state.currentSong != null) {
        try {
          final videoService = getIt.isRegistered<MusicVideoService>()
              ? getIt<MusicVideoService>()
              : MusicVideoService();
          final videoId = state.currentSong!.youtubeId ??
              (state.currentSong!.source == MusicSource.youtube
                  ? state.currentSong!.id
                  : null);
          if (videoId != null && videoId.isNotEmpty) {
            final videoStream = await videoService.getVideoStream(videoId);
            if (videoStream != null && !isClosed) {
              emit(
                state.copyWith(
                  videoStreamInfo: videoStream,
                  isVideoBuffering: false,
                ),
              );
              return;
            }
          }
        } catch (_) {}
        if (!isClosed) {
          emit(state.copyWith(isVideoBuffering: false));
        }
      }
    } else {
      emit(state.copyWith(isVideoMode: false, isVideoBuffering: false));

      // Hand playback back to the audio engine at the video's position, and
      // only resume if audio was playing when video mode took over.
      final resumePosition = _videoPosition;
      final shouldResume = _resumeAudioAfterVideo;
      _videoPosition = null;
      _resumeAudioAfterVideo = false;

      if (resumePosition != null && resumePosition > Duration.zero) {
        try {
          await _audioPlayer.seek(resumePosition);
        } catch (_) {}
      }

      if (shouldResume) {
        await _audioPlayer.play();
        if (!isClosed) {
          emit(state.copyWith(status: PlayerStatus.playing));
        }
      }
    }
  }

  void _onVideoPositionChanged(
    VideoPositionChangedEvent event,
    Emitter<PlayerState> emit,
  ) {
    _videoPosition = event.position;
    if (!isClosed) {
      emit(state.copyWith(position: event.position));
    }
  }

  void _onSetVideoBuffering(
    SetVideoBufferingEvent event,
    Emitter<PlayerState> emit,
  ) {
    emit(state.copyWith(isVideoBuffering: event.isBuffering));
  }

  void _persistCurrentSession({Duration? customPosition}) {
    final song = state.currentSong;
    if (song != null && state.queue.isNotEmpty) {
      unawaited(
        QueuePersistenceService.instance.saveSession(
          currentSong: song,
          queue: state.queue,
          queueIndex: state.queueIndex,
          position: customPosition ?? state.position,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    WidgetsBinding.instance.removeObserver(this);
    cancelSleepTimer();
    _cancelTrackStartWatchdog();
    await _positionSubscription?.cancel();
    await _bufferedSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _playingSubscription?.cancel();
    await _bufferingSubscription?.cancel();
    await _completedSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _indexSubscription?.cancel();
    await _crossfadeSubscription?.cancel();
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

/// Alias for backwards compatibility with internal calls
typedef _AddRecommendationsEvent = AddRecommendationsEvent;

/// Internal event for track index changes (from auto-advance in background)
class _IndexChangedEvent extends PlayerEvent {
  final int? index;

  const _IndexChangedEvent(this.index);

  @override
  List<Object?> get props => [index];
}

/// Internal event fired by the track-start watchdog when a track that the
/// native queue advanced to has not started playing in time.
class _TrackStalledEvent extends PlayerEvent {
  final Song song;
  final int index;

  /// Value of the bloc's playback generation when the watchdog was armed.
  final int generation;

  const _TrackStalledEvent({
    required this.song,
    required this.index,
    required this.generation,
  });

  @override
  List<Object?> get props => [song, index, generation];
}

/// Internal event fired when the sleep timer elapses and playback was
/// paused; clears the timer state.
class _SleepTimerClearedEvent extends PlayerEvent {
  const _SleepTimerClearedEvent();

  @override
  List<Object?> get props => [];
}
