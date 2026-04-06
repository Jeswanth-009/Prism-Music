import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

import 'audio_player_service.dart';

/// Centralized audio focus and interruption orchestration.
class AudioFocusOrchestratorService {
  final AudioPlayerService _audioPlayer;
  final Future<void> Function() _pausePlayback;

  AudioSession? _session;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _noisySub;

  bool _configured = false;
  DateTime? _lastConfiguredAt;
  bool _resumeAfterInterruption = false;
  double? _volumeBeforeDuck;

  AudioFocusOrchestratorService({
    required AudioPlayerService audioPlayer,
    required Future<void> Function() pausePlayback,
  })  : _audioPlayer = audioPlayer,
        _pausePlayback = pausePlayback;

  Future<void> initialize() async {
    final session = _session ?? await AudioSession.instance;
    _session = session;

    await _configure(session, force: true);

    await _interruptionSub?.cancel();
    _interruptionSub = session.interruptionEventStream.listen(_onInterruptionEvent);

    await _noisySub?.cancel();
    _noisySub = session.becomingNoisyEventStream.listen((_) async {
      if (_audioPlayer.playing) {
        await _pausePlayback();
      }
    });

    debugPrint('AudioFocus: Initialized');
  }

  Future<void> _configure(AudioSession session, {bool force = false}) async {
    final lastConfiguredAt = _lastConfiguredAt;
    if (!force && _configured && lastConfiguredAt != null) {
      if (DateTime.now().difference(lastConfiguredAt) < const Duration(seconds: 10)) {
        return;
      }
    }

    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
        flags: AndroidAudioFlags.none,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));

    _configured = true;
    _lastConfiguredAt = DateTime.now();
  }

  Future<bool> activateForPlayback() async {
    try {
      final session = _session ?? await AudioSession.instance;
      _session = session;
      await _configure(session);
      return await session.setActive(true);
    } catch (e) {
      debugPrint('AudioFocus: Failed to activate: $e');
      return false;
    }
  }

  Future<void> deactivate() async {
    try {
      final session = _session;
      if (session != null) {
        await session.setActive(false);
      }
    } catch (e) {
      debugPrint('AudioFocus: Failed to deactivate: $e');
    }
  }

  Future<void> _onInterruptionEvent(AudioInterruptionEvent event) async {
    if (event.begin) {
      switch (event.type) {
        case AudioInterruptionType.duck:
          _volumeBeforeDuck ??= _audioPlayer.volume;
          await _audioPlayer.setVolume((_audioPlayer.volume * 0.35).clamp(0.0, 1.0));
          break;
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          _resumeAfterInterruption = _audioPlayer.playing;
          if (_audioPlayer.playing) {
            await _pausePlayback();
          }
          break;
      }
      return;
    }

    switch (event.type) {
      case AudioInterruptionType.duck:
        final previous = _volumeBeforeDuck;
        _volumeBeforeDuck = null;
        if (previous != null) {
          await _audioPlayer.setVolume(previous.clamp(0.0, 1.0));
        }
        break;
      case AudioInterruptionType.pause:
        if (_resumeAfterInterruption) {
          final granted = await activateForPlayback();
          if (granted) {
            await _audioPlayer.play();
          }
        }
        _resumeAfterInterruption = false;
        break;
      case AudioInterruptionType.unknown:
        _resumeAfterInterruption = false;
        break;
    }
  }

  Future<void> dispose() async {
    await _interruptionSub?.cancel();
    await _noisySub?.cancel();
    await deactivate();
  }
}
