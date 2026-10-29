import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/services/lastfm_service.dart';
import '../../../../core/services/recommendation_service.dart';
import '../../../../domain/entities/entities.dart';
import '../../../../domain/repositories/repositories.dart';

/// Mixin encapsulating Last.fm now playing, scrobbling, and history persistence.
mixin ScrobbleMixin {
  LastFmService _lastFmService = LastFmService();

  bool _hasScrobbled = false;
  bool _hasUpdatedNowPlaying = false;
  bool _hasRecordedHistory = false;
  String? _lastRecordedSongId;
  DateTime? _lastRecordedTime;

  @visibleForTesting
  void setLastFmServiceForTesting(LastFmService service) {
    _lastFmService = service;
  }

  /// Reset all scrobbling and history deduplication flags on new track transition.
  void resetScrobbleState() {
    _hasScrobbled = false;
    _hasUpdatedNowPlaying = false;
    _hasRecordedHistory = false;
  }

  /// Update Now Playing status on Last.fm once per track if authenticated.
  Future<void> updateNowPlaying(Song song) async {
    if (!_hasUpdatedNowPlaying && _lastFmService.isAuthenticated) {
      _hasUpdatedNowPlaying = true;
      await _lastFmService.updateNowPlaying(
        track: song.title,
        artist: song.artist,
        album: song.album ?? '',
      );
    }
  }

  /// Submit scrobble to Last.fm once track exceeds 4 minutes or 50% completion.
  Future<void> attemptScrobble(
    Song song,
    Duration position,
    Duration duration,
  ) async {
    if (_hasScrobbled || !_lastFmService.isAuthenticated) return;

    final shouldScrobble = position.inSeconds > 240 ||
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

  /// Record listening session in history and recommendation services once duration threshold is met.
  void attemptRecordListeningSession({
    required Song song,
    required Duration position,
    required Duration duration,
    required LibraryRepository libraryRepository,
    RecommendationService? recommendationService,
  }) {
    if (_hasRecordedHistory) return;

    final meetsThreshold = position.inSeconds >= 30 ||
        (duration.inSeconds > 0 &&
            position.inSeconds >= duration.inSeconds * 0.5) ||
        position.inSeconds >= 240;

    if (meetsThreshold) {
      final now = DateTime.now();
      if (_lastRecordedSongId == song.playableId &&
          _lastRecordedTime != null &&
          now.difference(_lastRecordedTime!).inSeconds < 30) {
        _hasRecordedHistory = true;
        return;
      }

      _hasRecordedHistory = true;
      _lastRecordedSongId = song.playableId;
      _lastRecordedTime = now;
      unawaited(libraryRepository.addToHistory(song));
      recommendationService?.recordPlay(song);
    }
  }

  /// Finalize track history recording when playback completes.
  void handleTrackCompleted({
    required Song? currentSong,
    required LibraryRepository libraryRepository,
    RecommendationService? recommendationService,
  }) {
    if (!_hasRecordedHistory && currentSong != null) {
      _hasRecordedHistory = true;
      _lastRecordedSongId = currentSong.playableId;
      _lastRecordedTime = DateTime.now();
      unawaited(libraryRepository.addToHistory(currentSong));
      recommendationService?.recordPlay(currentSong);
    }
  }
}
