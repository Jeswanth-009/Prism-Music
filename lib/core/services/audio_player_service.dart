import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';
import 'package:just_audio/just_audio.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/stream_info.dart';
import 'media_resolver_service.dart';
import 'stream_cache_service.dart';
import 'youtube_audio_source.dart';
import 'equalizer_service.dart';
import 'audio_normalization_service.dart';
import 'desktop_audio_support.dart';
import 'offline_mode_service.dart';

/// Lazy stream source for non-YouTube tracks whose stream URL is resolved when played.
// ignore: experimental_member_use
class DeferredStreamAudioSource extends StreamAudioSource {
  final String songId;
  final String title;
  final String artist;
  final AudioQuality quality;
  final Future<ResolvedMediaSource?> Function(
    String songId,
    String title,
    String artist,
    AudioQuality quality,
  ) resolver;

  ResolvedMediaSource? _resolved;
  final Set<http.Client> _activeClients = {};

  DeferredStreamAudioSource({
    required this.songId,
    required this.title,
    required this.artist,
    required this.quality,
    required this.resolver,
    super.tag,
  });

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    _resolved ??= await resolver(songId, title, artist, quality);
    final source = _resolved;
    if (source == null || source.uri.isEmpty) {
      throw Exception('Failed to resolve deferred stream for $songId');
    }

    if (AudioPlayerService.isLocalPath(source.uri)) {
      final file = File(
        source.uri.startsWith('file://')
            ? Uri.parse(source.uri).toFilePath()
            : source.uri,
      );
      final total = await file.length();
      final actualEnd = end != null ? math.min(end, total) : total;
      return StreamAudioResponse(
        sourceLength: total,
        contentLength: math.max(0, actualEnd - start),
        offset: start,
        stream: file.openRead(start, actualEnd),
        contentType: 'audio/mp4',
      );
    }

    final info = source.streamInfo;
    return openHttpRangeAudioStream(
      streamUrl: source.uri,
      start: start,
      end: end,
      totalBytes: info?.contentLength ?? 0,
      fallbackContentType:
          info != null ? 'audio/${info.container}' : 'audio/mp4',
      headers: source.headers,
      activeClients: _activeClients,
    );
  }
}

/// Audio player service using just_audio with direct YouTube streaming
class AudioPlayerService {
  late AudioPlayer _player;
  late EqualizerService _equalizerService;
  double _rawVolume = 1.0;
  Song? _currentNormalizingSong;
  double _fadeScalar = 1.0;

  /// Whether player holds an active queue managed via [AudioPlayer.setAudioSources]
  bool _isQueueMode = false;
  final List<AudioSource> _queueSources = [];
  bool _initialized = false;

  /// Upper bound on how many upcoming queue entries are warmed at a time.
  static const int _maxQueuePrewarm = 3;

  /// How many upcoming lazily-resolved queue entries to keep warm (0 = off).
  /// Held at 0 while a queue is loading so the current track gets the
  /// network first; [loadQueue] raises it once that track is ready.
  int _queuePrewarmLookahead = 0;

  /// `videoId|quality` keys whose manifest warm-up is currently in flight.
  final Set<String> _prewarmInflight = <String>{};

  StreamCacheService? _streamCache;
  Future<ResolvedMediaSource?> Function(
    String songId,
    String title,
    String artist,
    AudioQuality quality,
  )? _deferredResolver;
  bool _completedEmittedForCurrentTrack = false;

  /// Wires optional shared cache and deferred resolver after DI registration.
  void configureQueueResolvers({
    StreamCacheService? streamCache,
    Future<ResolvedMediaSource?> Function(
      String songId,
      String title,
      String artist,
      AudioQuality quality,
    )? deferredResolver,
  }) {
    _streamCache = streamCache;
    _deferredResolver = deferredResolver;
  }

  /// Shape of a YouTube video id (11 URL-safe characters).
  static final RegExp _youtubeVideoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

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
  final _crossfadingController = StreamController<bool>.broadcast();
  bool _isCrossfading = false;

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
  Stream<bool> get isCrossfadingStream => _crossfadingController.stream;

  // Current values
  Duration get position => _initialized ? _player.position : Duration.zero;
  Duration get bufferedPosition =>
      _initialized ? _player.bufferedPosition : Duration.zero;
  Duration? get duration => _initialized ? _player.duration : null;
  bool get playing => _initialized ? _player.playing : false;
  double get volume => _rawVolume;
  bool get isCrossfading => _isCrossfading;
  bool get buffering => _initialized
      ? (_player.processingState == ProcessingState.buffering ||
            _player.processingState == ProcessingState.loading)
      : false;
  bool get completed => _initialized
      ? _player.processingState == ProcessingState.completed
      : false;
  bool get isQueueMode => _isQueueMode;
  @visibleForTesting
  int get queueSourcesLength => _queueSources.length;
  @visibleForTesting
  List<AudioSource> get queueSources => List.unmodifiable(_queueSources);

  /// Song identity of the native queue entry at [index], or null when the
  /// entry carries no tag id or [index] is out of range. The player bloc uses
  /// this to map a native queue position back to the right bloc queue entry
  /// when the two queues have drifted apart (skipped entries, add/remove/
  /// reorder while playing).
  String? mediaIdAt(int index) {
    if (index < 0 || index >= _queueSources.length) return null;
    return _mediaIdOf(_queueSources[index]);
  }

  /// Ids of every native queue entry, in native order (null for untagged
  /// entries). Compared against the bloc queue before trusting native
  /// auto-advance order for manual skips.
  List<String?> get queueMediaIds =>
      _queueSources.map(_mediaIdOf).toList();

  String? _mediaIdOf(AudioSource source) {
    final tag = source is IndexedAudioSource ? source.tag : null;
    return tag is MediaItem ? tag.id : null;
  }

  // Equalizer access
  EqualizerService get equalizer => _equalizerService;

  AudioPlayerService() {
    _init();
  }

  void _init() {
    _player = AudioPlayer(
      audioLoadConfiguration:
          DesktopAudioSupport.instance.getPlatformAudioLoadConfiguration(),
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

          final isCompleted = state == ProcessingState.completed;
          if (!isCompleted) {
            _completedEmittedForCurrentTrack = false;
          } else if (!_isQueueMode && !_completedEmittedForCurrentTrack) {
            _completedEmittedForCurrentTrack = true;
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
          if (!_isQueueMode) {
            return;
          }
          _completedEmittedForCurrentTrack = false;
          _currentIndexController.add(index);
          // Keep the next few tracks' stream manifests warm as playback
          // moves through the queue.
          _prewarmUpcomingQueue(fromIndex: index);
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
            if (_isQueueMode &&
                !_player.hasNext &&
                !_completedEmittedForCurrentTrack) {
              _completedEmittedForCurrentTrack = true;
              _completedController.add(true);
            }
          } else {
            _completedEmittedForCurrentTrack = false;
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

    // Single-track mode initializes a flat 1-item source list via setAudioSources
    // so late recommendations or Add-to-Queue actions can append seamlessly via
    // addAudioSources without nesting ConcatenatingAudioSource. Clear prior state.
    _isQueueMode = false;
    _queueSources.clear();

    final sanitizedHeaders = _prepareHeaders(headers);
    final hasDirectUrl = url.isNotEmpty;
    final isLocal = isLocalPath(url);
    final isGoogleVideo = url.contains('googlevideo.com');
    final isYouTube = !isLocal && isYouTubeTrack(url: url, videoId: videoId);
    final cachedStream = (videoId != null && videoId.isNotEmpty)
        ? _streamCache?.getCached(videoId, _parseAudioQuality(quality))
        : null;
    final effectiveHeaders = sanitizedHeaders ?? cachedStream?.headers;
    final effectiveContentLength = cachedStream?.contentLength;
    final effectiveContentType =
        cachedStream != null ? 'audio/${cachedStream.container}' : null;

    PlayerException? lastDirectException;
    Object? lastDirectError;

    Future<Duration?> setSource(AudioSource source, String label) async {
      _queueSources
        ..clear()
        ..add(source);
      _isQueueMode = true;
      _completedEmittedForCurrentTrack = false;
      final loadedDuration = await _player.setAudioSources(
        [source],
        initialIndex: 0,
        preload: true,
      );
      if (_player.processingState == ProcessingState.idle && loadedDuration == null) {
        _isQueueMode = false;
        _queueSources.clear();
        return null;
      }
      if (kDebugMode) {
        debugPrint(
          'AudioPlayerService: $label source ready, duration: ${_player.duration}',
        );
      }
      return loadedDuration ?? _player.duration ?? mediaDuration;
    }

    // 1. For YouTube-family tracks, always use YouTubeAudioSource (StreamAudioSource).
    // Raw googlevideo.com URLs fail in Android ExoPlayer due to IP binding, SSL handshakes,
    // and missing range proxies. YouTubeAudioSource streams via localhost, providing bulletproof
    // native playback without skipping.
    if (isYouTube && !isLocal) {
      try {
        final ytSource = YouTubeAudioSource(
          videoId: (videoId != null && videoId.isNotEmpty)
              ? videoId
              : (isGoogleVideo ? 'direct' : ''),
          quality: quality,
          initialStreamUrl: hasDirectUrl ? url : null,
          initialContentLength: effectiveContentLength,
          initialContentType: effectiveContentType,
          initialHeaders: effectiveHeaders,
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
        _isQueueMode = false;
        _queueSources.clear();
        lastDirectException = e;
        if (kDebugMode) {
          debugPrint('AudioPlayerService: YouTube source failed: $e\n$st');
        }
      } catch (e, st) {
        _isQueueMode = false;
        _queueSources.clear();
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
          final sourceUri = uriForUrl(url);
          final directSource = AudioSource.uri(
            sourceUri,
            headers: isLocal ? null : effectiveHeaders,
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
          _isQueueMode = false;
          _queueSources.clear();
          lastDirectException = e;
          if (kDebugMode) {
            debugPrint('AudioPlayerService: Direct URL failed: $e\n$st');
          }

          if (isLocal) {
            final errorMessage = _mapPlayerExceptionToMessage(e.message);
            _errorController.add(errorMessage);
            return null;
          }
        } catch (e, st) {
          _isQueueMode = false;
          _queueSources.clear();
          lastDirectError = e;
          if (kDebugMode) {
            debugPrint('AudioPlayerService: Direct URL threw: $e\n$st');
          }

          if (isLocal) {
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
        _isQueueMode = false;
        _queueSources.clear();
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
          if (kDebugMode) debugPrint('AudioPlayerService: Asynchronous play() failed: $error');
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
          initialHeaders: targetStream.headers,
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

      _queueSources
        ..clear()
        ..add(source);
      _isQueueMode = true;
      _completedEmittedForCurrentTrack = false;
      await _player.setAudioSources(
        [source],
        initialIndex: 0,
        initialPosition: currentPos,
        preload: true,
      );
      if (wasPlaying) {
        unawaited(play());
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AudioPlayerService: Safe switchStreamSource failed: $e');
      }
      return false;
    }
  }

  /// Set volume (0.0 to 1.0) with loudness normalization applied
  Future<void> setVolume(double volume) async {
    if (!_initialized) return;
    _rawVolume = volume.clamp(0.0, 1.0);
    await _applyNormalizedVolume();
  }

  /// Update the current song for loudness normalization
  Future<void> applySongNormalization(Song? song) async {
    _currentNormalizingSong = song;
    await _applyNormalizedVolume();
  }

  Future<void> _applyNormalizedVolume() async {
    if (!_initialized) return;
    var scalar = 1.0;
    if (_currentNormalizingSong != null) {
      scalar = AudioNormalizationService.instance.computeGainFactor(_currentNormalizingSong!);
    }
    final effective = (_rawVolume * scalar * _fadeScalar).clamp(0.0, 1.0);
    await _player.setVolume(effective);
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

    final totalFadeMs = duration.inMilliseconds.clamp(0, 10000);
    // Split fade duration equally between fade out and fade in
    final halfFadeMs = totalFadeMs ~/ 2;
    final steps = math.max(1, math.min(16, halfFadeMs ~/ 50));
    _isCrossfading = true;
    if (!_crossfadingController.isClosed) {
      _crossfadingController.add(true);
    }
    final stepDuration = Duration(
      milliseconds: steps == 0 ? 0 : halfFadeMs ~/ steps,
    );

    try {
      if (_player.playing && halfFadeMs > 0) {
        for (int i = steps; i >= 1; i--) {
          final factor = i / steps;
          // Perceptually smooth quadratic loudness curve
          _fadeScalar = (factor * factor).clamp(0.0, 1.0);
          await _applyNormalizedVolume();
          await Future<void>.delayed(stepDuration);
        }
        _fadeScalar = 0.0;
        await _applyNormalizedVolume();
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
        _fadeScalar = 1.0;
        await _applyNormalizedVolume();
        return null;
      }

      unawaited(play());

      if (halfFadeMs > 0) {
        for (int i = 1; i <= steps; i++) {
          final factor = i / steps;
          _fadeScalar = (factor * factor).clamp(0.0, 1.0);
          await _applyNormalizedVolume();
          await Future<void>.delayed(stepDuration);
        }
      }
      _fadeScalar = 1.0;
      await _applyNormalizedVolume();
      return d;
    } catch (_) {
      _fadeScalar = 1.0;
      await _applyNormalizedVolume();
      rethrow;
    } finally {
      _isCrossfading = false;
      if (!_crossfadingController.isClosed) {
        _crossfadingController.add(false);
      }
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

  /// Whether [url] points at a local audio file (downloaded track) rather
  /// than a remote stream. Local files must never be routed through the
  /// YouTube streaming path — doing so makes offline playback fail silently.
  static bool isLocalPath(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url.startsWith('file://')) return true;
    if (url.startsWith('http://') || url.startsWith('https://')) return false;
    if (url.startsWith('/')) return true;
    if (url.length >= 3 && url[1] == ':' && (url[2] == '\\' || url[2] == '/')) return true;
    try {
      return File(url).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Whether a track should be routed through [YouTubeAudioSource].
  ///
  /// Evaluates strictly:
  /// 1. Local files are NEVER YouTube tracks.
  /// 2. Direct non-YouTube URLs (such as JioSaavn CDN saavncdn.com) are NEVER YouTube tracks,
  ///    even if a videoId identifier was provided.
  /// 3. Returns true if the URL is an explicit YouTube or GoogleVideo URL, OR if there is a
  ///    valid YouTube videoId and no direct non-YouTube URL overriding it.
  static bool isYouTubeTrack({String? url, String? videoId}) {
    if (isLocalPath(url)) return false;

    final hasUrl = url != null && url.isNotEmpty;
    final isGoogleVideo = hasUrl && url.contains('googlevideo.com');
    final isExplicitYouTubeUrl = hasUrl &&
        (url.contains('youtube.com') || url.contains('youtu.be') || isGoogleVideo);

    if (isExplicitYouTubeUrl) return true;

    final isNonYouTubeDirectUrl = hasUrl &&
        (url.startsWith('http://') || url.startsWith('https://')) &&
        (url.contains('saavn') || !isGoogleVideo);

    // If a direct non-YouTube HTTP/HTTPS stream URL is already resolved, don't route to YouTube
    if (hasUrl && isNonYouTubeDirectUrl) {
      return false;
    }

    // Has a shape-valid YouTube videoId (11 URL-safe chars) and no conflicting
    // non-YouTube direct URL. A bare non-YouTube id (e.g. a JioSaavn track id)
    // must never enter the YouTube manifest chain: the whole client fallback
    // walk would burn its timeout budget and fail the track.
    return videoId != null &&
        videoId.isNotEmpty &&
        _youtubeVideoIdPattern.hasMatch(videoId);
  }

  /// Builds the correct [Uri] for [url]: [Uri.file] for local paths,
  /// [Uri.parse] for remote streams.
  static Uri uriForUrl(String url) {
    if (url.startsWith('file://')) return Uri.parse(url);
    if (isLocalPath(url)) return Uri.file(url);
    return Uri.parse(url);
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

      final isLocal = isLocalPath(url);
      final isYouTube = !isLocal && isYouTubeTrack(url: url, videoId: videoId);

      if (isLocal) {
        logDebug('AudioPlayerService: Adding local file to queue');
        source = AudioSource.uri(
          uriForUrl(url),
          tag: MediaItem(id: url, title: 'Loading...', album: 'Prism Music'),
        );
      } else if (isYouTube) {
        logDebug('AudioPlayerService: Adding YouTube song to queue');
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
        logDebug('AudioPlayerService: Adding regular URL to queue');
        source = AudioSource.uri(
          uriForUrl(url),
          headers: sanitizedHeaders,
          tag: MediaItem(id: url, title: 'Loading...', album: 'Prism Music'),
        );
      } else {
        throw Exception('No URL or videoId provided');
      }

      _queueSources.add(source);

      final currentIndex = _player.currentIndex;
      final currentPosition = _player.position;

      if (_isQueueMode) {
        await _player.addAudioSource(source);
      } else {
        _isQueueMode = true;
        _completedEmittedForCurrentTrack = false;
        await _player.setAudioSources(
          List<AudioSource>.from(_queueSources),
          initialIndex: currentIndex ?? (_queueSources.length - 1),
          initialPosition: currentIndex != null ? currentPosition : null,
          preload: true,
        );
      }

      logDebug('AudioPlayerService: ✓ Added song to queue (Queue length: ${_queueSources.length})');
    } catch (e) {
      logError('AudioPlayerService: ✗ Failed to add to queue', e);
      _errorController.add('Failed to add to queue: $e');
    }
  }

  AudioQuality _parseAudioQuality(String quality) {
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

  /// Builds an [AudioSource] from a serialized queue entry without dropping tracks.
  AudioSource? _buildQueueAudioSource(Map<String, dynamic> songData) {
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
    final parsedQuality = _parseAudioQuality(quality);

    final title = songData['title'] as String? ?? 'Unknown Title';
    final artist = songData['artist'] as String? ?? 'Unknown Artist';
    final artUri = songData['artUri'] as String?;
    final album = songData['album'] as String? ?? 'Prism Music';
    final durationMs = songData['durationMs'] as int?;
    final mediaDuration =
        (durationMs != null && durationMs > 0) ? Duration(milliseconds: durationMs) : null;

    final cached = (videoId != null && videoId.isNotEmpty)
        ? _streamCache?.getCached(videoId, parsedQuality)
        : null;
    final effectiveHeaders = sanitizedHeaders ?? cached?.headers;
    final effectiveLength =
        (songData['contentLength'] as int?) ?? cached?.contentLength;
    final effectiveContentType = (songData['contentType'] as String?) ??
        (cached != null ? 'audio/${cached.container}' : null);
    final effectiveUrl =
        (url != null && url.isNotEmpty) ? url : cached?.url;

    final mediaItem = MediaItem(
      id: (videoId != null && videoId.isNotEmpty)
          ? videoId
          : (effectiveUrl ?? DateTime.now().toString()),
      title: title,
      artist: artist,
      album: album,
      artUri: artUri != null ? Uri.tryParse(artUri) : null,
      duration: mediaDuration,
    );

    final isLocal = effectiveUrl != null && isLocalPath(effectiveUrl);
    final isYouTube = !isLocal && isYouTubeTrack(url: effectiveUrl, videoId: videoId);

    if (isLocal) {
      return AudioSource.uri(uriForUrl(effectiveUrl), tag: mediaItem);
    }
    if (isYouTube) {
      return YouTubeAudioSource(
        videoId: (videoId != null && videoId.isNotEmpty) ? videoId : 'direct',
        quality: quality,
        initialStreamUrl: effectiveUrl,
        initialContentLength: effectiveLength,
        initialContentType: effectiveContentType,
        initialHeaders: effectiveHeaders,
        tag: mediaItem,
      );
    }
    if (effectiveUrl != null && effectiveUrl.isNotEmpty) {
      return AudioSource.uri(
        uriForUrl(effectiveUrl),
        headers: effectiveHeaders,
        tag: mediaItem,
      );
    }
    if (_deferredResolver != null && videoId != null && videoId.isNotEmpty) {
      return DeferredStreamAudioSource(
        songId: videoId,
        title: title,
        artist: artist,
        quality: parsedQuality,
        resolver: _deferredResolver!,
        tag: mediaItem,
      );
    }

    logDebug('AudioPlayerService: ERROR - No URL or videoId provided!');
    return null;
  }

  /// Load and start playing a queue of songs using ConcatenatingAudioSource
  /// This enables auto-advance between songs even when app is in background
  ///
  /// [prewarmLookahead] is how many of the tracks after the current one get
  /// their stream manifests fetched in the background while the current
  /// track plays (0 disables it; capped at [_maxQueuePrewarm]).
  Future<Duration?> loadQueue(
    List<Map<String, dynamic>> songs, {
    int initialIndex = 0,
    int prewarmLookahead = _maxQueuePrewarm,
  }) async {
    if (!_initialized) return null;

    try {
      logDebug('AudioPlayerService: Loading queue with ${songs.length} songs, starting at index $initialIndex');

      _queueSources.clear();
      // Warm upcoming tracks only once the current one is ready (below).
      _queuePrewarmLookahead = 0;
      final sources = <AudioSource>[];

      for (final songData in songs) {
        final source = _buildQueueAudioSource(songData);
        if (source != null) {
          sources.add(source);
        }
      }

      if (sources.isEmpty) {
        logDebug('AudioPlayerService: ERROR - No valid sources to play!');
        _errorController.add('No valid audio sources');
        return null;
      }

      _queueSources.addAll(sources);

      final startIndex = initialIndex < 0
          ? 0
          : (initialIndex >= _queueSources.length
                ? _queueSources.length - 1
                : initialIndex);

      // Use flat AudioPlayer.setAudioSources so ExoPlayer receives the real track
      // list directly with exact windowIndex mapping (no nested ConcatenatingAudioSource).
      _isQueueMode = true;
      _completedEmittedForCurrentTrack = false;

      logDebug('AudioPlayerService: Setting queue with ${sources.length} items at index $startIndex...');
      final loadedDuration = await _player.setAudioSources(
        sources,
        initialIndex: startIndex,
        preload: true,
      );

      if (_player.processingState == ProcessingState.idle && loadedDuration == null) {
        _isQueueMode = false;
        _queueSources.clear();
        return null;
      }

      logDebug('AudioPlayerService: ✓ Queue loaded successfully, duration: ${_player.duration}');
      // The current track is ready, so the network is free to warm the stream
      // manifests of the tracks that follow it.
      _queuePrewarmLookahead = math.min(
        math.max(prewarmLookahead, 0),
        _maxQueuePrewarm,
      );
      _prewarmUpcomingQueue(fromIndex: startIndex);

      final fallbackDurationMs =
          (startIndex >= 0 && startIndex < songs.length)
              ? songs[startIndex]['durationMs'] as int?
              : null;
      final fallbackDuration = (fallbackDurationMs != null && fallbackDurationMs > 0)
          ? Duration(milliseconds: fallbackDurationMs)
          : Duration.zero;
      return loadedDuration ?? _player.duration ?? fallbackDuration;
    } catch (e, st) {
      _isQueueMode = false;
      _queueSources.clear();
      logError('AudioPlayerService: ✗ Failed to load queue', e, st);
      _errorController.add('Failed to load queue: $e');
      return null;
    }
  }

  /// Warms the stream manifests of the next few queue entries.
  void _prewarmUpcomingQueue({int? fromIndex}) {
    final lookahead = _queuePrewarmLookahead;
    if (lookahead <= 0 || !_isQueueMode) return;
    final current = fromIndex ?? _player.currentIndex;
    if (current == null || current < 0) return;
    if (OfflineModeService.instance.isOffline) return;

    final end = math.min(_queueSources.length, current + 1 + lookahead);
    for (var i = current + 1; i < end; i++) {
      final source = _queueSources[i];
      if (source is! YouTubeAudioSource) continue;
      final initialUrl = source.initialStreamUrl;
      if (initialUrl != null && initialUrl.isNotEmpty) continue;
      final id = source.videoId;
      // Only real YouTube video ids have a manifest to warm; anything else
      // (e.g. a JioSaavn id) would just burn a full client fallback walk.
      if (!_youtubeVideoIdPattern.hasMatch(id)) continue;
      final quality = source.quality;
      if (_streamCache?.isCached(id, _parseAudioQuality(quality)) == true ||
          YouTubeAudioSource.isStreamCached(id, quality: quality)) {
        continue;
      }
      final key = '$id|$quality';
      if (!_prewarmInflight.add(key)) continue;
      unawaited(
        YouTubeAudioSource.prewarmCache(id, quality: quality)
            .catchError((_) {})
            .whenComplete(() {
              _prewarmInflight.remove(key);
            }),
      );
    }
  }

  /// Add songs to the existing playlist (for endless queue/recommendations)
  Future<void> appendToQueue(List<Map<String, dynamic>> songs) async {
    if (!_initialized || !_isQueueMode) return;

    try {
      final sources = <AudioSource>[];
      for (final songData in songs) {
        final source = _buildQueueAudioSource(songData);
        if (source != null) {
          sources.add(source);
        }
      }

      if (sources.isNotEmpty) {
        await _player.addAudioSources(sources);
        _queueSources.addAll(sources);
        if (_queuePrewarmLookahead == 0) {
          _queuePrewarmLookahead = _maxQueuePrewarm;
        }
        _prewarmUpcomingQueue(fromIndex: _player.currentIndex ?? 0);
        logDebug('AudioPlayerService: Appended ${sources.length} songs to queue (total: ${_queueSources.length})');
      }
    } catch (e) {
      logError('AudioPlayerService: Failed to append to queue', e);
    }
  }

  /// Clear the current playlist
  void clearPlaylist() {
    _isQueueMode = false;
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

  /// Seek to a specific song index in the queue
  Future<void> seekToIndex(int index, {Duration? position}) async {
    if (!_initialized) return;
    await _player.seek(position ?? Duration.zero, index: index);
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
    _crossfadingController.close();
    _isQueueMode = false;
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
