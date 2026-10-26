import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/stream_info.dart';
import 'youtube_audio_source.dart';
import 'equalizer_service.dart';

/// Audio player service using just_audio with direct YouTube streaming
class AudioPlayerService {
  late AudioPlayer _player;
  late EqualizerService _equalizerService;

  /// Concatenating audio source for queue management
  ConcatenatingAudioSource? _playlist;
  final List<AudioSource> _queueSources = [];
  bool _initialized = false;

  AudioPlayer get player => _player; 
  // Stream controllers for player events
  final _positionController = StreamController<Duration>.broadcast();
  final _bufferedPositionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _bufferingController = StreamController<bool>.broadcast();
  final _completedController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _currentIndexController = StreamController<int?>.broadcast();

  // Streams
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get bufferedPositionStream =>
      _bufferedPositionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<bool> get playingStream => _playingController.stream;
  Stream<bool> get bufferingStream => _bufferingController.stream;
  Stream<bool> get completedStream => _completedController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<int?> get currentIndexStream => _currentIndexController.stream;

  // Current values
  Duration get position => _initialized ? _player.position : Duration.zero;
  Duration get bufferedPosition =>
      _initialized ? _player.bufferedPosition : Duration.zero;
  Duration? get duration => _initialized ? _player.duration : null;
  bool get playing => _initialized ? _player.playing : false;
  double get volume => _initialized ? _player.volume : 1.0;
  bool get buffering => _initialized
      ? (_player.processingState == ProcessingState.buffering ||
            _player.processingState == ProcessingState.loading)
      : false;
  bool get completed => _initialized
      ? _player.processingState == ProcessingState.completed
      : false;
  bool get isQueueMode => _playlist != null;
  @visibleForTesting
  int get queueSourcesLength => _queueSources.length;

  // Equalizer access
  EqualizerService get equalizer => _equalizerService;

  AudioPlayerService() {
    _init();
  }

  void _init() {
    _player = AudioPlayer(
      audioLoadConfiguration: AudioLoadConfiguration(
        androidLoadControl: AndroidLoadControl(
          minBufferDuration: const Duration(seconds: 30),
          maxBufferDuration: const Duration(seconds: 120),
          bufferForPlaybackDuration: const Duration(seconds: 2),
          bufferForPlaybackAfterRebufferDuration: const Duration(seconds: 3),
        ),
      ),
      // AudioFocusOrchestratorService handles interruptions and focus exclusively
      handleInterruptions: false,
    );
    _equalizerService = EqualizerService();
    _initialized = true;
    _initStreams();
  }

  final List<StreamSubscription> _subscriptions = [];

  void _handleNativeError(String source, Object error) {
    if (kDebugMode) {
      debugPrint('AudioPlayerService: Native error from $source: $error');
    }
    final message = _mapPlayerExceptionToMessage(error.toString());
    if (!_errorController.isClosed) {
      _errorController.add(message);
    }
  }

  void _initStreams() {
    // Android audio session ID updates for native equalizer effects binding
    _subscriptions.add(
      _player.androidAudioSessionIdStream.listen(
        (sessionId) {
          if (sessionId != null && sessionId > 0) {
            _equalizerService.bindAudioSession(sessionId);
          }
        },
        onError: (e) => _handleNativeError('androidAudioSessionIdStream', e),
      ),
    );
    final initialSessionId = _player.androidAudioSessionId;
    if (initialSessionId != null && initialSessionId > 0) {
      _equalizerService.bindAudioSession(initialSessionId);
    }

    // Position updates
    _subscriptions.add(
      _player.positionStream.listen(
        _positionController.add,
        onError: (e) => _handleNativeError('positionStream', e),
      ),
    );

    // Buffered position updates
    _subscriptions.add(
      _player.bufferedPositionStream.listen(
        _bufferedPositionController.add,
        onError: (e) => _handleNativeError('bufferedPositionStream', e),
      ),
    );

    // Duration updates
    _subscriptions.add(
      _player.durationStream.listen(
        _durationController.add,
        onError: (e) => _handleNativeError('durationStream', e),
      ),
    );

    // Playing state updates
    _subscriptions.add(
      _player.playingStream.listen(
        _playingController.add,
        onError: (e) => _handleNativeError('playingStream', e),
      ),
    );

    // Processing state updates for buffering
    _subscriptions.add(
      _player.processingStateStream.listen(
        (state) {
          final isBuffering =
              state == ProcessingState.buffering ||
              state == ProcessingState.loading;
          _bufferingController.add(isBuffering);

          // Emit completed state - but only for single-track mode
          // When using queue (ConcatenatingAudioSource), auto-advance handles this
          final isCompleted = state == ProcessingState.completed;
          if (isCompleted && _playlist == null) {
            _completedController.add(true);
          }
        },
        onError: (e) => _handleNativeError('processingStateStream', e),
      ),
    );

    // Track changes in queue mode - emit completed when reaching end of queue
    _subscriptions.add(
      _player.currentIndexStream.listen(
        (index) {
          if (_playlist == null) {
            return;
          }
          _currentIndexController.add(index);
          if (kDebugMode) {
            debugPrint('AudioPlayerService: Current index changed to $index');
          }
        },
        onError: (e) => _handleNativeError('currentIndexStream', e),
      ),
    );

    // Player state stream for comprehensive error handling
    _subscriptions.add(
      _player.playerStateStream.listen(
        (state) {
          if (state.processingState == ProcessingState.completed) {
            if (kDebugMode) debugPrint('AudioPlayerService: Playback completed');
            // In queue mode, check if we're at the last song
            if (_playlist != null && !_player.hasNext) {
              _completedController.add(true);
            }
          }
        },
        onError: (e) => _handleNativeError('playerStateStream', e),
      ),
    );

    // Monitor playback event stream for native pipeline events and decoder errors
    _subscriptions.add(
      _player.playbackEventStream.listen(
        (_) {},
        onError: (e) => _handleNativeError('playbackEventStream', e),
      ),
    );
  }

  /// Set and prepare audio from URL or YouTube video ID
  ///
  /// For YouTube videos, pass the videoId parameter to use direct streaming.
  /// This eliminates the need for external proxy servers and provides faster, more reliable playback.
  Future<Duration?> setUrl(
    String url, {
    Map<String, String>? headers,
    String? videoId,
    String quality = 'high',
    String? title,
    String? artist,
    String? album,
    String? artworkUrl,
    Duration? mediaDuration,
    bool allowYouTubeFallbackOnDirectFailure = false,
  }) async {
    if (kDebugMode) {
      debugPrint(
        'AudioPlayerService: Setting up audio (videoId: $videoId, directUrl: ${url.isNotEmpty})',
      );
    }

    // Single-track mode should not keep stale queue metadata from older sessions.
    _playlist = null;
    _queueSources.clear();

    final sanitizedHeaders = _prepareHeaders(headers);
    final hasDirectUrl = url.isNotEmpty;
    final isLikelyLocalPath =
        url.startsWith('file://') ||
        (!url.startsWith('http://') &&
            !url.startsWith('https://') &&
            File(url).existsSync());
    final isGoogleVideo = url.contains('googlevideo.com');
    final isYouTubeUrl =
        url.contains('youtube.com') || url.contains('youtu.be') || isGoogleVideo;
    final isYouTube = (videoId != null && videoId.isNotEmpty) || isYouTubeUrl;

    PlayerException? lastDirectException;
    Object? lastDirectError;

    Future<Duration?> setSource(AudioSource source, String label) async {
      await _player.setAudioSource(source);
      if (kDebugMode) {
        debugPrint(
          'AudioPlayerService: $label source ready, duration: ${_player.duration}',
        );
      }
      return _player.duration ?? mediaDuration;
    }

    // 1. For YouTube-family tracks, always use YouTubeAudioSource (StreamAudioSource).
    // Raw googlevideo.com URLs fail in Android ExoPlayer due to IP binding, SSL handshakes,
    // and missing range proxies. YouTubeAudioSource streams via localhost, providing bulletproof
    // native playback without skipping.
    if (isYouTube && !isLikelyLocalPath) {
      try {
        final ytSource = YouTubeAudioSource(
          videoId: (videoId != null && videoId.isNotEmpty)
              ? videoId
              : (isGoogleVideo ? 'direct' : ''),
          quality: quality,
          initialStreamUrl: hasDirectUrl ? url : null,
          tag: MediaItem(
            id: videoId ?? url,
            title: title ?? 'Unknown Title',
            artist: artist ?? 'Unknown Artist',
            album: album ?? 'Prism Music',
            artUri: artworkUrl != null ? Uri.tryParse(artworkUrl) : null,
            duration: mediaDuration,
          ),
        );

        final dur = await setSource(ytSource, 'YouTube');
        if (dur != null) return dur;
      } on PlayerException catch (e, st) {
        lastDirectException = e;
        if (kDebugMode) {
          debugPrint('AudioPlayerService: YouTube source failed: $e\n$st');
        }
      } catch (e, st) {
        lastDirectError = e;
        if (kDebugMode) {
          debugPrint('AudioPlayerService: YouTube source threw: $e\n$st');
        }
      }
    }

    // 2. For non-YouTube direct streams (e.g., JioSaavn CDN saavncdn.com) or local files:
    if (!isYouTube || (lastDirectException != null || lastDirectError != null)) {
      if (hasDirectUrl && !isGoogleVideo) {
        try {
          final sourceUri = url.startsWith('file://')
              ? Uri.parse(url)
              : (isLikelyLocalPath ? Uri.file(url) : Uri.parse(url));
          final directSource = AudioSource.uri(
            sourceUri,
            headers: isLikelyLocalPath ? null : sanitizedHeaders,
            tag: MediaItem(
              id: videoId ?? url,
              title: title ?? 'Unknown Title',
              artist: artist ?? 'Unknown Artist',
              album: album ?? 'Prism Music',
              artUri: artworkUrl != null ? Uri.tryParse(artworkUrl) : null,
              duration: mediaDuration,
            ),
          );

          final dur = await setSource(directSource, 'Direct URL');
          if (dur != null) return dur;
        } on PlayerException catch (e, st) {
          lastDirectException = e;
          if (kDebugMode) {
            debugPrint('AudioPlayerService: Direct URL failed: $e\n$st');
          }

          if (isLikelyLocalPath) {
            final errorMessage = _mapPlayerExceptionToMessage(e.message);
            _errorController.add(errorMessage);
            return null;
          }
        } catch (e, st) {
          lastDirectError = e;
          if (kDebugMode) {
            debugPrint('AudioPlayerService: Direct URL threw: $e\n$st');
          }

          if (isLikelyLocalPath) {
            _errorController.add('Failed to load local audio file: $e');
            return null;
          }
        }
      }
    }

    // 3. Fallback: try YouTubeAudioSource with fresh manifest resolution if not yet attempted
    final canTryYouTubeFallback =
        videoId != null &&
        videoId.isNotEmpty &&
        (!hasDirectUrl || allowYouTubeFallbackOnDirectFailure);
    if (canTryYouTubeFallback && (lastDirectException != null || lastDirectError != null)) {
      try {
        final ytSource = YouTubeAudioSource(
          videoId: videoId,
          quality: quality,
          tag: MediaItem(
            id: videoId,
            title: title ?? 'Unknown Title',
            artist: artist ?? 'Unknown Artist',
            album: album ?? 'Prism Music',
            artUri: artworkUrl != null ? Uri.tryParse(artworkUrl) : null,
            duration: mediaDuration,
          ),
        );

        final dur = await setSource(ytSource, 'YouTube (Fallback)');
        if (dur != null) return dur;
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('AudioPlayerService: Fallback YouTube source failed: $e\n$st');
        }
        _errorController.add('Failed to load audio: $e');
        return null;
      }
    }

    if (hasDirectUrl &&
        videoId != null &&
        videoId.isNotEmpty &&
        !allowYouTubeFallbackOnDirectFailure) {
      if (kDebugMode) {
        debugPrint(
          'AudioPlayerService: Skipping YouTube fallback after direct URL failure',
        );
      }
    }

    // No source succeeded; report the most helpful error.
    if (lastDirectException != null) {
      final message = _mapPlayerExceptionToMessage(lastDirectException.message);
      _errorController.add(message);
    } else if (lastDirectError != null) {
      _errorController.add('Failed to load audio: $lastDirectError');
    } else {
      _errorController.add('No valid audio source available');
    }

    return null;
  }

  /// Play audio. Decouples startup from lifetime completion so callers are not suspended.
  Future<void> play() async {
    if (!_initialized) return;
    try {
      final sessionId = _player.androidAudioSessionId;
      if (sessionId != null &&
          sessionId > 0 &&
          _equalizerService.audioSessionId != sessionId) {
        _equalizerService.bindAudioSession(sessionId);
      }
      unawaited(
        _player.play().catchError((error, stackTrace) {
          debugPrint('AudioPlayerService: Asynchronous play() failed: $error');
          _handleNativeError('play', error);
        }),
      );
    } catch (e) {
      _handleNativeError('play', e);
    }
  }

  /// Pause audio
  Future<void> pause() async {
    if (!_initialized) return;
    await _player.pause();
  }

  /// Stop audio and reset position
  Future<void> stop() async {
    if (!_initialized) return;
    await _player.stop();
  }

  /// Seek to a specific position
  Future<void> seek(Duration position) async {
    if (!_initialized) return;
    await _player.seek(position);
  }

  /// Safely hot-swaps the underlying audio source while preserving the exact playback position.
  Future<bool> switchStreamSource(StreamInfo targetStream, {required Song song}) async {
    if (!_initialized) return false;
    final currentPos = _player.position;
    final wasPlaying = _player.playing;

    try {
      final isGoogleVideo = targetStream.url.contains('googlevideo.com');
      final isYouTube = song.source == MusicSource.youtube ||
          song.source == MusicSource.youtubeMusic ||
          isGoogleVideo;

      AudioSource source;
      if (isYouTube) {
        source = YouTubeAudioSource(
          videoId: song.playableId,
          initialStreamUrl: targetStream.url,
          initialContentLength: targetStream.contentLength,
          initialContentType: 'audio/${targetStream.container}',
          tag: MediaItem(
            id: song.playableId,
            title: song.title,
            artist: song.artist,
            album: song.album ?? 'Prism Music',
            artUri: song.thumbnailUrl.isNotEmpty ? Uri.tryParse(song.thumbnailUrl) : null,
            duration: song.duration,
          ),
        );
      } else {
        final sanitizedHeaders = _prepareHeaders(targetStream.headers);
        source = AudioSource.uri(
          Uri.parse(targetStream.url),
          headers: sanitizedHeaders,
          tag: MediaItem(
            id: song.playableId,
            title: song.title,
            artist: song.artist,
            album: song.album ?? 'Prism Music',
            artUri: song.thumbnailUrl.isNotEmpty ? Uri.tryParse(song.thumbnailUrl) : null,
            duration: song.duration,
          ),
        );
      }

      await _player.setAudioSource(source, initialPosition: currentPos);
      if (wasPlaying) {
        await _player.play();
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AudioPlayerService: Safe switchStreamSource failed: $e');
      }
      return false;
    }
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    if (!_initialized) return;
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    if (!_initialized) return;
    await _player.setSpeed(speed.clamp(0.25, 2.0));
  }

  /// Track transition to a new source by smoothly fading out current playback,
  /// switching source, then fading back in.
  Future<Duration?> fadeTransitionTo(
    String url, {
    Map<String, String>? headers,
    String? videoId,
    String quality = 'high',
    String? title,
    String? artist,
    String? album,
    String? artworkUrl,
    Duration? mediaDuration,
    Duration duration = const Duration(seconds: 2),
    bool allowYouTubeFallbackOnDirectFailure = false,
  }) async {
    if (!_initialized) return null;

    final initialVolume = _player.volume;
    final totalFadeMs = duration.inMilliseconds.clamp(0, 10000);
    // Split fade duration equally between fade out and fade in
    final halfFadeMs = totalFadeMs ~/ 2;
    final steps = math.max(1, math.min(16, halfFadeMs ~/ 50));
    final stepDuration = Duration(
      milliseconds: steps == 0 ? 0 : halfFadeMs ~/ steps,
    );

    try {
      if (_player.playing && halfFadeMs > 0) {
        for (int i = steps; i >= 1; i--) {
          final factor = i / steps;
          // Perceptually smooth quadratic loudness curve
          final v = (initialVolume * factor * factor).clamp(0.0, 1.0);
          await _player.setVolume(v);
          await Future<void>.delayed(stepDuration);
        }
        await _player.setVolume(0.0);
      }

      final d = await setUrl(
        url,
        headers: headers,
        videoId: videoId,
        quality: quality,
        title: title,
        artist: artist,
        album: album,
        artworkUrl: artworkUrl,
        mediaDuration: mediaDuration,
        allowYouTubeFallbackOnDirectFailure: allowYouTubeFallbackOnDirectFailure,
      );

      if (d == null) {
        await _player.setVolume(initialVolume);
        return null;
      }

      unawaited(play());

      if (halfFadeMs > 0) {
        for (int i = 1; i <= steps; i++) {
          final factor = i / steps;
          final v = (initialVolume * factor * factor).clamp(0.0, 1.0);
          await _player.setVolume(v);
          await Future<void>.delayed(stepDuration);
        }
      }
      await _player.setVolume(initialVolume);
      return d;
    } catch (_) {
      await _player.setVolume(initialVolume);
      rethrow;
    }
  }

  /// Alias for [fadeTransitionTo] for backward compatibility.
  Future<Duration?> crossfadeTo(
    String url, {
    Map<String, String>? headers,
    String? videoId,
    String quality = 'high',
    String? title,
    String? artist,
    String? album,
    String? artworkUrl,
    Duration? mediaDuration,
    Duration duration = const Duration(seconds: 2),
    bool allowYouTubeFallbackOnDirectFailure = false,
  }) => fadeTransitionTo(
    url,
    headers: headers,
    videoId: videoId,
    quality: quality,
    title: title,
    artist: artist,
    album: album,
    artworkUrl: artworkUrl,
    mediaDuration: mediaDuration,
    duration: duration,
    allowYouTubeFallbackOnDirectFailure: allowYouTubeFallbackOnDirectFailure,
  );

  /// Add a song to the end of the playlist queue
  Future<void> addToQueue(
    String url, {
    Map<String, String>? headers,
    String? videoId,
    String quality = 'high',
  }) async {
    if (!_initialized) return;
    final sanitizedHeaders = _prepareHeaders(headers);

    try {
      AudioSource source;

      final isGoogleVideo = url.contains('googlevideo.com');
      final isYouTube = (videoId != null && videoId.isNotEmpty) ||
          url.contains('youtube.com') ||
          url.contains('youtu.be') ||
          isGoogleVideo;

      if (isYouTube) {
        debugPrint('AudioPlayerService: Adding YouTube song to queue');
        source = YouTubeAudioSource(
          videoId: (videoId != null && videoId.isNotEmpty) ? videoId : 'direct',
          quality: quality,
          initialStreamUrl: url.isNotEmpty ? url : null,
          tag: MediaItem(
            id: videoId ?? url,
            title: 'Loading...',
            album: 'Prism Music',
          ),
        );
      } else if (url.isNotEmpty) {
        debugPrint('AudioPlayerService: Adding regular URL to queue');
        source = AudioSource.uri(
          Uri.parse(url),
          headers: sanitizedHeaders,
          tag: MediaItem(id: url, title: 'Loading...', album: 'Prism Music'),
        );
      } else {
        throw Exception('No URL or videoId provided');
      }

      _queueSources.add(source);

      final currentIndex = _player.currentIndex;
      final currentPosition = _player.position;

      if (_playlist != null) {
        await _playlist!.add(source);
      } else {
        _playlist = ConcatenatingAudioSource(
          useLazyPreparation: true,
          shuffleOrder: DefaultShuffleOrder(),
          children: List<AudioSource>.from(_queueSources),
        );

        await _player.setAudioSource(
          _playlist!,
          initialIndex: currentIndex ?? (_queueSources.length - 1),
          initialPosition: currentIndex != null ? currentPosition : null,
        );
      }

      debugPrint(
        'AudioPlayerService: ✓ Added song to queue (Queue length: ${_queueSources.length})',
      );
    } catch (e) {
      debugPrint('AudioPlayerService: ✗ Failed to add to queue: $e');
      _errorController.add('Failed to add to queue: $e');
    }
  }

  /// Load and start playing a queue of songs using ConcatenatingAudioSource
  /// This enables auto-advance between songs even when app is in background
  Future<Duration?> loadQueue(
    List<Map<String, dynamic>> songs, {
    int initialIndex = 0,
  }) async {
    if (!_initialized) return null;

    try {
      debugPrint(
        'AudioPlayerService: Loading queue with ${songs.length} songs, starting at index $initialIndex',
      );

      _queueSources.clear();
      final sources = <AudioSource>[];

      for (final songData in songs) {
        final videoId = songData['videoId'] as String?;
        final url = songData['url'] as String?;
        // Handle headers - could be Map<String, String>, Map<String, dynamic>, or null
        Map<String, String> headers = {};
        final rawHeaders = songData['headers'];
        if (rawHeaders != null && rawHeaders is Map) {
          headers = rawHeaders.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          );
        }
        final sanitizedHeaders = _prepareHeaders(headers);
        final quality = songData['quality'] as String? ?? 'high';

        // Extract metadata for MediaItem
        final title = songData['title'] as String? ?? 'Unknown Title';
        final artist = songData['artist'] as String? ?? 'Unknown Artist';
        final artUri = songData['artUri'] as String?;
        final album = songData['album'] as String? ?? 'Prism Music';

        final mediaItem = MediaItem(
          id: videoId ?? url ?? DateTime.now().toString(),
          title: title,
          artist: artist,
          album: album,
          artUri: artUri != null ? Uri.tryParse(artUri) : null,
        );

        debugPrint(
          'AudioPlayerService: Processing song - videoId: $videoId, hasUrl: ${url != null}, urlLength: ${url?.length ?? 0}',
        );

        AudioSource source;

        final isGoogleVideo = url != null && url.contains('googlevideo.com');
        final isYouTube = (videoId != null && videoId.isNotEmpty) ||
            (url != null &&
                (url.contains('youtube.com') ||
                    url.contains('youtu.be') ||
                    isGoogleVideo));

        if (isYouTube) {
          debugPrint('AudioPlayerService: Using YouTubeAudioSource for queued track');
          source = YouTubeAudioSource(
            videoId: (videoId != null && videoId.isNotEmpty) ? videoId : 'direct',
            quality: quality,
            initialStreamUrl: (url != null && url.isNotEmpty) ? url : null,
            tag: mediaItem,
          );
        } else if (url != null && url.isNotEmpty) {
          debugPrint('AudioPlayerService: Using pre-loaded URL directly');
          source = AudioSource.uri(
            Uri.parse(url),
            headers: sanitizedHeaders,
            tag: mediaItem,
          );
        } else {
          debugPrint('AudioPlayerService: ERROR - No URL or videoId provided!');
          continue; // Skip this song
        }
        sources.add(source);
      }

      if (sources.isEmpty) {
        debugPrint('AudioPlayerService: ERROR - No valid sources to play!');
        _errorController.add('No valid audio sources');
        return null;
      }

      _queueSources.addAll(sources);

      final startIndex = initialIndex < 0
          ? 0
          : (initialIndex >= _queueSources.length
                ? _queueSources.length - 1
                : initialIndex);

      // Use ConcatenatingAudioSource for proper queue management
      // This is KEY for background playback - just_audio handles auto-advance internally
      _playlist = ConcatenatingAudioSource(
        useLazyPreparation: true, // Don't load all songs upfront
        shuffleOrder: DefaultShuffleOrder(),
        children: sources,
      );

      debugPrint(
        'AudioPlayerService: Setting ConcatenatingAudioSource with ${sources.length} items...',
      );
      await _player.setAudioSource(
        _playlist!,
        initialIndex: startIndex,
        preload: false, // Lazy load for better performance
      );

      debugPrint(
        'AudioPlayerService: ✓ Queue loaded successfully, duration: ${_player.duration}',
      );
      return _player.duration;
    } catch (e, st) {
      debugPrint('AudioPlayerService: ✗ Failed to load queue: $e');
      debugPrint('Stack trace: $st');
      _errorController.add('Failed to load queue: $e');
      return null;
    }
  }

  /// Add songs to the existing playlist (for endless queue/recommendations)
  Future<void> appendToQueue(List<Map<String, dynamic>> songs) async {
    if (!_initialized || _playlist == null) return;

    try {
      final sources = <AudioSource>[];
      for (final songData in songs) {
        final videoId = songData['videoId'] as String?;
        final url = songData['url'] as String?;
        Map<String, String> headers = {};
        final rawHeaders = songData['headers'];
        if (rawHeaders != null && rawHeaders is Map) {
          headers = rawHeaders.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          );
        }
        final sanitizedHeaders = _prepareHeaders(headers);
        final quality = songData['quality'] as String? ?? 'high';

        final title = songData['title'] as String? ?? 'Unknown Title';
        final artist = songData['artist'] as String? ?? 'Unknown Artist';
        final artUri = songData['artUri'] as String?;
        final album = songData['album'] as String? ?? 'Prism Music';

        final mediaItem = MediaItem(
          id: videoId ?? url ?? DateTime.now().toString(),
          title: title,
          artist: artist,
          album: album,
          artUri: artUri != null ? Uri.tryParse(artUri) : null,
        );

        AudioSource source;
        if (url != null && url.isNotEmpty) {
          source = AudioSource.uri(
            Uri.parse(url),
            headers: sanitizedHeaders,
            tag: mediaItem,
          );
        } else if (videoId != null && videoId.isNotEmpty) {
          source = YouTubeAudioSource(
            videoId: videoId,
            quality: quality,
            tag: mediaItem,
          );
        } else {
          continue;
        }
        sources.add(source);
      }

      if (sources.isNotEmpty) {
        await _playlist!.addAll(sources);
        _queueSources.addAll(sources);
        debugPrint(
          'AudioPlayerService: Appended ${sources.length} songs to queue (total: ${_queueSources.length})',
        );
      }
    } catch (e) {
      debugPrint('AudioPlayerService: Failed to append to queue: $e');
    }
  }

  /// Clear the current playlist
  void clearPlaylist() {
    _playlist = null;
    _queueSources.clear();
  }

  /// Skip to next song in queue
  Future<void> skipToNext() async {
    if (!_initialized) return;
    if (_player.hasNext) {
      await _player.seekToNext();
    }
  }

  /// Skip to previous song in queue
  Future<void> skipToPrevious() async {
    if (!_initialized) return;
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    }
  }

  /// Get current index in queue
  int? get currentIndex => _player.currentIndex;

  /// Check if there's a next song
  bool get hasNext => _player.hasNext;

  /// Check if there's a previous song
  bool get hasPrevious => _player.hasPrevious;

  /// Map player exceptions to user-friendly messages
  String _mapPlayerExceptionToMessage(String? errorMessage) {
    if (errorMessage == null) return 'An unknown error occurred';

    if (errorMessage.contains('Unable to connect')) {
      return 'Network connection error. Please check your internet connection.';
    } else if (errorMessage.contains('timeout')) {
      return 'Connection timeout. Please try again.';
    } else if (errorMessage.contains('format')) {
      return 'Unsupported audio format.';
    } else if (errorMessage.contains('codec')) {
      return 'Audio codec not supported.';
    }

    return 'Playback error: $errorMessage';
  }

  /// Dispose resources
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _player.dispose();
    _positionController.close();
    _bufferedPositionController.close();
    _durationController.close();
    _playingController.close();
    _bufferingController.close();
    _completedController.close();
    _errorController.close();
    _currentIndexController.close();
    _playlist = null;
  }

  /// Prepare headers for ExoPlayer-friendly requests
  Map<String, String>? _prepareHeaders(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) {
      return null;
    }
    final sanitized = <String, String>{};
    headers.forEach((key, value) {
      final lower = key.toLowerCase();
      if (lower == 'range' ||
          lower == 'connection' ||
          lower == 'referer' ||
          lower == 'origin') {
        return;
      }
      sanitized[key] = value;
    });
    return sanitized.isEmpty ? null : sanitized;
  }
}
