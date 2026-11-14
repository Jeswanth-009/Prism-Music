import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/song.dart';
import 'audio_player_service.dart';
import 'media_session_coordinator.dart';
import 'settings_service.dart';

/// Service for managing bi-directional communication with Wear OS smartwatches.
/// Enables playback control, track progress tracking, and metadata updates
/// directly on smartwatch companions.
class WearOsService {
  static const MethodChannel _defaultChannel =
      MethodChannel('com.prismmusic/wear_os');

  final MethodChannel _channel;
  static WearOsService? _instance;

  AudioPlayerService? _playerService;
  Future<void> Function()? onSkipNext;
  Future<void> Function()? onSkipPrevious;

  StreamSubscription? _playerSub;
  StreamSubscription? _songSub;
  Song? _currentSong;
  bool _initialized = false;

  WearOsService._({MethodChannel? channel})
      : _channel = channel ?? _defaultChannel;

  static WearOsService get instance {
    _instance ??= WearOsService._();
    return _instance!;
  }

  @visibleForTesting
  static WearOsService createForTesting({
    MethodChannel? channel,
    Future<void> Function()? onSkipNext,
    Future<void> Function()? onSkipPrevious,
  }) {
    final service = WearOsService._(channel: channel);
    service.onSkipNext = onSkipNext;
    service.onSkipPrevious = onSkipPrevious;
    return service;
  }

  @visibleForTesting
  static void setInstance(WearOsService service) {
    _instance = service;
  }

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  bool get isEnabled {
    if (!isSupported) return false;
    return SettingsService.instance.isWearOsCompanionEnabled;
  }

  /// Initialize the Wear OS companion bridge
  void initialize({
    AudioPlayerService? playerService,
    Stream<Song?>? songStream,
    Future<void> Function()? onSkipNextCallback,
    Future<void> Function()? onSkipPreviousCallback,
  }) {
    if (_initialized) return;
    _playerService = playerService;
    if (onSkipNextCallback != null) onSkipNext = onSkipNextCallback;
    if (onSkipPreviousCallback != null) onSkipPrevious = onSkipPreviousCallback;
    _channel.setMethodCallHandler(_handleMethodCall);
    _initialized = true;

    if (playerService != null) {
      _listenToPlayer(playerService, songStream);
    }
  }

  void _listenToPlayer(
    AudioPlayerService playerService,
    Stream<Song?>? songStream,
  ) {
    _songSub?.cancel();
    if (songStream != null) {
      _songSub = songStream.listen((song) {
        _currentSong = song;
        _syncCurrentState();
      });
    }

    _playerSub?.cancel();
    _playerSub = playerService.playingStream.listen((playing) {
      _syncCurrentState();
    });
  }

  void setCurrentSong(Song? song) {
    _currentSong = song;
    _syncCurrentState();
  }

  void _syncCurrentState() {
    if (!isEnabled || _playerService == null) return;
    updatePlaybackState(
      song: _currentSong,
      isPlaying: _playerService!.playing,
      position: _playerService!.position,
      duration: _playerService!.duration ?? Duration.zero,
    );
  }

  /// Push current playback status to the smartwatch
  Future<bool> updatePlaybackState({
    required Song? song,
    required bool isPlaying,
    required Duration position,
    required Duration duration,
  }) async {
    if (!isSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('updatePlaybackState', {
        'title': song?.title ?? '',
        'artist': song?.artist ?? '',
        'durationMs': duration.inMilliseconds,
        'positionMs': position.inMilliseconds,
        'isPlaying': isPlaying,
        'artworkUrl': song?.thumbnailUrl ?? '',
      });
      return result ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('WearOsService: Error updating playback state: $e');
      return false;
    }
  }

  /// Handles method calls from the smartwatch via native Android bridge
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'play':
        if (_playerService != null && !_playerService!.playing) {
          await _playerService!.play();
        }
        return true;
      case 'pause':
        if (_playerService != null && _playerService!.playing) {
          await _playerService!.pause();
        }
        return true;
      case 'togglePlay':
        if (_playerService != null) {
          if (_playerService!.playing) {
            await _playerService!.pause();
          } else {
            await _playerService!.play();
          }
        }
        return true;
      case 'next':
        if (onSkipNext != null) {
          await onSkipNext!();
        } else {
          await MediaSessionCoordinator.instance.skipNext();
        }
        return true;
      case 'previous':
        if (onSkipPrevious != null) {
          await onSkipPrevious!();
        } else {
          await MediaSessionCoordinator.instance.skipPrevious();
        }
        return true;
      case 'seek':
        final args = call.arguments as Map?;
        final positionMs = (args?['positionMs'] as num?)?.toInt() ?? 0;
        if (_playerService != null) {
          await _playerService!.seek(Duration(milliseconds: positionMs));
        }
        return true;
      case 'setVolume':
        final args = call.arguments as Map?;
        final vol =
            ((args?['volume'] as num?)?.toDouble() ?? 1.0).clamp(0.0, 1.0);
        if (_playerService != null) {
          await _playerService!.setVolume(vol);
        }
        return true;
      case 'getPlaybackState':
        return {
          'title': _currentSong?.title ?? '',
          'artist': _currentSong?.artist ?? '',
          'durationMs': _playerService?.duration?.inMilliseconds ?? 0,
          'positionMs': _playerService?.position.inMilliseconds ?? 0,
          'isPlaying': _playerService?.playing ?? false,
          'artworkUrl': _currentSong?.thumbnailUrl ?? '',
        };
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'Method ${call.method} not implemented',
        );
    }
  }

  void dispose() {
    _playerSub?.cancel();
    _songSub?.cancel();
    _channel.setMethodCallHandler(null);
    _initialized = false;
  }
}
