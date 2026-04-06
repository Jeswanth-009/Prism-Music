import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'youtube_audio_source.dart';
import 'equalizer_service.dart';

/// Audio player service using just_audio with direct YouTube streaming
/// No external proxy server needed - streams directly from YouTube in Flutter
class AudioPlayerService {
  late AudioPlayer _player;
  late EqualizerService _equalizerService;

  /// Concatenating audio source for queue management - handles auto-advance in background
  ConcatenatingAudioSource? _playlist;
  final List<AudioSource> _queueSources = [];
  bool _initialized = false;
  static const _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36';

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

  // Equalizer access
  EqualizerService get equalizer => _equalizerService;

  AudioPlayerService() {
    _init();
  }

  void _init() {
    _player = AudioPlayer();
    _equalizerService = EqualizerService();
    _initialized = true;
    _initStreams();
  }

  void _initStreams() {
    // Position updates
    _player.positionStream.listen((position) {
      _positionController.add(position);
    });

    // Buffered position updates
    _player.bufferedPositionStream.listen((buffered) {
      _bufferedPositionController.add(buffered);
    });

    // Duration updates
    _player.durationStream.listen((duration) {
      _durationController.add(duration);
    });

    // Playing state updates
    _player.playingStream.listen((isPlaying) {
      _playingController.add(isPlaying);
    });

    // Processing state updates for buffering
    _player.processingStateStream.listen((state) {
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
    });

    // Track changes in queue mode - emit completed when reaching end of queue
    _player.currentIndexStream.listen((index) {
      if (_playlist == null) {
        return;
      }
      _currentIndexController.add(index);
      debugPrint('AudioPlayerService: Current index changed to $index');
    });

    // Player state stream for comprehensive error handling
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        debugPrint('AudioPlayerService: Playback completed');
        // In queue mode, check if we're at the last song
        if (_playlist != null && !_player.hasNext) {
          _completedController.add(true);
        }
      }
    });
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
    bool allowYouTubeFallbackOnDirectFailure = false,
  }) async {
    debugPrint(
      'AudioPlayerService: Setting up audio (videoId: $videoId, directUrl: ${url.isNotEmpty})',
    );

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
    PlayerException? lastDirectException;
    Object? lastDirectError;

    Future<Duration?> setSource(AudioSource source, String label) async {
      await _player.setAudioSource(source);
      debugPrint(
        'AudioPlayerService: $label source ready, duration: ${_player.duration}',
      );
      return _player.duration;
    }

    // Prefer using the already resolved stream URL first for faster startup.
    if (hasDirectUrl) {
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
          ),
        );

        return await setSource(directSource, 'Direct URL');
      } on PlayerException catch (e, st) {
        lastDirectException = e;
        debugPrint('AudioPlayerService: Direct URL failed: $e');
        if (kDebugMode) debugPrint('Stack trace: $st');

        if (isLikelyLocalPath) {
          final errorMessage = _mapPlayerExceptionToMessage(e.message);
          _errorController.add(errorMessage);
          return null;
        }
      } catch (e, st) {
        lastDirectError = e;
        debugPrint('AudioPlayerService: Direct URL threw: $e');
        if (kDebugMode) debugPrint('Stack trace: $st');

        if (isLikelyLocalPath) {
          _errorController.add('Failed to load local audio file: $e');
          return null;
        }
      }
    }

    // Resolver should own stream resolution. Only use player-side YouTube
    // resolution when no URL was supplied, or when explicitly allowed.
    final canTryYouTubeFallback =
        videoId != null &&
        videoId.isNotEmpty &&
        (!hasDirectUrl || allowYouTubeFallbackOnDirectFailure);
    if (canTryYouTubeFallback) {
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
          ),
        );

        return await setSource(ytSource, 'YouTube');
      } on PlayerException catch (e, st) {
        debugPrint(
          'AudioPlayerService: PlayerException while loading YouTube source: $e',
        );
        debugPrint('Stack trace: $st');
        final errorMessage = _mapPlayerExceptionToMessage(e.message);
        _errorController.add(errorMessage);
        return null;
      } catch (e, st) {
        debugPrint(
          'AudioPlayerService: Failed to load audio via YouTube source: $e',
        );
        debugPrint('Stack trace: $st');
        _errorController.add('Failed to load audio: $e');
        return null;
      }
    }

    if (hasDirectUrl &&
        videoId != null &&
        videoId.isNotEmpty &&
        !allowYouTubeFallbackOnDirectFailure) {
      debugPrint(
        'AudioPlayerService: Skipping YouTube fallback after direct URL failure',
      );
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

  /// Play audio
  Future<void> play() async {
    if (!_initialized) return;
    await _player.play();
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

  /// Crossfade transition to a new source by fading out current playback,
  /// switching source, then fading back in.
  Future<Duration?> crossfadeTo(
    String url, {
    Map<String, String>? headers,
    String? videoId,
    String quality = 'high',
    String? title,
    String? artist,
    String? album,
    String? artworkUrl,
    Duration duration = const Duration(seconds: 2),
  }) async {
    if (!_initialized) return null;

    final initialVolume = _player.volume;
    final fadeMs = duration.inMilliseconds.clamp(0, 6000);
    final steps = math.max(1, math.min(16, fadeMs ~/ 100));
    final stepDuration = Duration(
      milliseconds: steps == 0 ? 0 : fadeMs ~/ steps,
    );

    if (_player.playing && fadeMs > 0) {
      for (int i = steps; i >= 1; i--) {
        await _player.setVolume((initialVolume * i / steps).clamp(0.0, 1.0));
        await Future<void>.delayed(stepDuration);
      }
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
    );

    if (d == null) {
      await _player.setVolume(initialVolume);
      return null;
    }

    await play();

    if (fadeMs > 0) {
      for (int i = 1; i <= steps; i++) {
        await _player.setVolume((initialVolume * i / steps).clamp(0.0, 1.0));
        await Future<void>.delayed(stepDuration);
      }
    } else {
      await _player.setVolume(initialVolume);
    }

    return d;
  }

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

      if (videoId != null && videoId.isNotEmpty) {
        debugPrint(
          'AudioPlayerService: Adding YouTube song to queue: $videoId',
        );
        source = YouTubeAudioSource(
          videoId: videoId,
          quality: quality,
          tag: MediaItem(
            id: videoId,
            title: 'Loading...',
            album: 'Prism Music',
          ),
        );
      } else {
        debugPrint('AudioPlayerService: Adding regular URL to queue');
        source = AudioSource.uri(
          Uri.parse(url),
          headers: sanitizedHeaders,
          tag: MediaItem(id: url, title: 'Loading...', album: 'Prism Music'),
        );
      }

      _queueSources.add(source);

      final currentIndex = _player.currentIndex;
      final currentPosition = _player.position;

      await _player.setAudioSources(
        _queueSources,
        initialIndex: currentIndex ?? (_queueSources.length - 1),
        initialPosition: currentIndex != null ? currentPosition : null,
      );

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

        // PRIORITY: Use YouTubeAudioSource if videoId is available (more reliable)
        if (videoId != null && videoId.isNotEmpty) {
          debugPrint(
            'AudioPlayerService: Using YouTubeAudioSource for videoId: $videoId',
          );
          source = YouTubeAudioSource(
            videoId: videoId,
            quality: quality,
            tag: mediaItem,
          );
        } else if (url != null && url.isNotEmpty) {
          // Fallback: Use pre-loaded URL directly
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
        if (videoId != null && videoId.isNotEmpty) {
          source = YouTubeAudioSource(
            videoId: videoId,
            quality: quality,
            tag: mediaItem,
          );
        } else if (url != null && url.isNotEmpty) {
          source = AudioSource.uri(
            Uri.parse(url),
            headers: sanitizedHeaders,
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
  Map<String, String> _prepareHeaders(Map<String, String>? headers) {
    final sanitized = <String, String>{};
    if (headers != null) {
      headers.forEach((key, value) {
        final lower = key.toLowerCase();
        if (lower == 'range' || lower == 'connection') {
          return;
        }
        sanitized[key] = value;
      });
    }
    sanitized.putIfAbsent('User-Agent', () => _defaultUserAgent);
    sanitized.putIfAbsent('Accept', () => '*/*');
    sanitized.putIfAbsent('Accept-Language', () => 'en-US,en;q=0.9');
    sanitized.putIfAbsent('Referer', () => 'https://www.youtube.com/');
    sanitized.putIfAbsent('Origin', () => 'https://www.youtube.com');
    return sanitized;
  }
}
