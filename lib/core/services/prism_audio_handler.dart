import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/artist.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/library_repository.dart';
import '../di/injection.dart';
import '../utils/logger.dart';
import 'download_service.dart';
import 'media_session_coordinator.dart';
import 'wear_os_service.dart';

/// audio_service handler producing the system media notification.
///
/// The underlying player is always in single-track mode (the PlayerBloc starts
/// a new source per song), so next/previous/stop are routed through
/// [MediaSessionCoordinator] into the bloc's queue logic instead of the
/// player's own (no-op) seekToNext/seekToPrevious.
class PrismAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player;
  final DownloadService? _downloadService;
  final LibraryRepository? _libraryRepository;

  PrismAudioHandler(
    this.player, {
    DownloadService? downloadService,
    LibraryRepository? libraryRepository,
  })  : _downloadService = downloadService,
        _libraryRepository = libraryRepository {
    // Broadcast player state to the system notification
    player.playbackEventStream.listen(
      _broadcastState,
      onError: (e, st) => logError('PrismAudioHandler: playbackEventStream error', e, st),
    );

    // Duration listener to enrich mediaItem with exact player duration for seekbar
    player.durationStream.listen(
      (duration) {
        try {
          if (duration != null &&
              mediaItem.value != null &&
              mediaItem.value!.duration != duration) {
            mediaItem.add(mediaItem.value!.copyWith(duration: duration));
          }
        } catch (e, st) {
          logError('PrismAudioHandler: durationStream error', e, st);
        }
      },
      onError: (e, st) => logError('PrismAudioHandler: durationStream error', e, st),
    );

    // Update notification metadata (title, artist, artwork, quality)
    player.sequenceStateStream.listen(
      (sequenceState) {
        try {
          if (sequenceState.currentSource != null) {
            final tag = sequenceState.currentSource!.tag;
            if (tag is MediaItem) {
              final quality = MediaSessionCoordinator.instance.currentQualityLabel;
              final enriched = tag.copyWith(
                displayDescription: quality.isNotEmpty ? quality : null,
              );
              mediaItem.add(enriched);
              // Re-broadcast so the control buttons re-render for the new
              // track's position in the queue (e.g. previous becomes usable).
              _broadcastState(player.playbackEvent);
            }
          }
        } catch (e, st) {
          logError('PrismAudioHandler: sequenceStateStream error', e, st);
        }
      },
      onError: (e, st) => logError('PrismAudioHandler: sequenceStateStream error', e, st),
    );

    // Update queue metadata
    player.sequenceStream.listen(
      (sequence) {
        try {
          final items = sequence
              .where((s) => s.tag is MediaItem)
              .map((s) => s.tag as MediaItem)
              .toList();
          queue.add(items);
        } catch (e, st) {
          logError('PrismAudioHandler: sequenceStream error', e, st);
        }
      },
      onError: (e, st) => logError('PrismAudioHandler: sequenceStream error', e, st),
    );
  }

  static const MediaControl likedControl = MediaControl(
    androidIcon: 'drawable/ic_heart',
    label: 'Unlike',
    action: MediaAction.custom,
  );

  static const MediaControl unlikedControl = MediaControl(
    androidIcon: 'drawable/ic_heart_outline',
    label: 'Like',
    action: MediaAction.custom,
  );

  /// Backwards-compatibility alias for tests
  static const MediaControl favoriteControl = unlikedControl;

  void _broadcastState(PlaybackEvent event) {
    try {
      final playing = player.playing;
      final coordinator = MediaSessionCoordinator.instance;
      final favControl = coordinator.isCurrentSongLiked ? likedControl : unlikedControl;
      final controls = <MediaControl>[
        if (coordinator.canSkipPrevious) MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        if (coordinator.canSkipNext) MediaControl.skipToNext,
        favControl,
        MediaControl.fastForward,
        MediaControl.rewind,
        MediaControl.stop,
      ];

      // Compute compact action indices for lock screen: center on playback & skips.
      final compactActionIndices = <int>[];
      final prevIdx = controls.indexOf(MediaControl.skipToPrevious);
      final playIdx = controls.indexOf(playing ? MediaControl.pause : MediaControl.play);
      final nextIdx = controls.indexOf(MediaControl.skipToNext);
      final favIdx = controls.indexOf(favControl);
      if (prevIdx != -1) {
        compactActionIndices.add(prevIdx);
      } else if (favIdx != -1) {
        compactActionIndices.add(favIdx);
      }
      if (playIdx != -1) compactActionIndices.add(playIdx);
      if (nextIdx != -1) compactActionIndices.add(nextIdx);

      playbackState.add(
        playbackState.value.copyWith(
          controls: controls,
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
            MediaAction.fastForward,
            MediaAction.rewind,
            MediaAction.setRepeatMode,
            MediaAction.setShuffleMode,
            MediaAction.custom,
            MediaAction.stop,
          },
          androidCompactActionIndices: compactActionIndices,
          processingState: const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[player.processingState]!,
          playing: playing,
          updatePosition: player.position,
          bufferedPosition: player.bufferedPosition,
          speed: player.speed,
          queueIndex: event.currentIndex,
        ),
      );

      final currentItem = mediaItem.value;
      if (currentItem != null) {
        try {
          WearOsService.instance.updatePlaybackState(
            song: Song(
              id: currentItem.id,
              title: currentItem.title,
              artist: currentItem.artist ?? '',
              thumbnails: Thumbnails(high: currentItem.artUri?.toString()),
              duration: currentItem.duration ?? Duration.zero,
            ),
            isPlaying: playing,
            position: player.position,
            duration: currentItem.duration ?? Duration.zero,
          );
        } catch (we, wst) {
          logError('PrismAudioHandler: WearOs update error', we, wst);
        }
      }
    } catch (e, st) {
      logError('PrismAudioHandler: _broadcastState error', e, st);
    }
  }

  /// Re-render the notification's controls after queue enablement changed.
  void refreshNotificationState() {
    try {
      _broadcastState(player.playbackEvent);
    } catch (e, st) {
      logError('PrismAudioHandler: refreshNotificationState error', e, st);
    }
  }

  /// Re-render the notification's metadata (e.g. quality, like status)
  void refreshNotificationMetadata() {
    try {
      if (mediaItem.value != null) {
        final quality = MediaSessionCoordinator.instance.currentQualityLabel;
        mediaItem.add(mediaItem.value!.copyWith(
          displayDescription: quality.isNotEmpty ? quality : null,
        ));
      }
      _broadcastState(player.playbackEvent);
    } catch (e, st) {
      logError('PrismAudioHandler: refreshNotificationMetadata error', e, st);
    }
  }

  @override
  Future<void> play() async {
    try {
      await player.play();
    } catch (e, st) {
      logError('PrismAudioHandler: play error', e, st);
    }
  }

  @override
  Future<void> pause() async {
    try {
      await player.pause();
    } catch (e, st) {
      logError('PrismAudioHandler: pause error', e, st);
    }
  }

  @override
  Future<void> stop() async {
    try {
      // The X on the notification means "close playback": let the bloc reset
      // its state (history, queue UI) instead of only stopping raw audio.
      await MediaSessionCoordinator.instance.stopFromNotification();
      await super.stop();
    } catch (e, st) {
      logError('PrismAudioHandler: stop error', e, st);
    }
  }

  @override
  Future<void> skipToNext() async {
    try {
      await MediaSessionCoordinator.instance.skipNext();
    } catch (e, st) {
      logError('PrismAudioHandler: skipToNext error', e, st);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      await MediaSessionCoordinator.instance.skipPrevious();
    } catch (e, st) {
      logError('PrismAudioHandler: skipToPrevious error', e, st);
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await player.seek(position);
    } catch (e, st) {
      logError('PrismAudioHandler: seek error', e, st);
    }
  }

  @override
  Future<void> fastForward() async {
    try {
      final current = player.position;
      final total = player.duration;
      final target = current + const Duration(seconds: 10);
      if (total != null && target > total) {
        await player.seek(total);
      } else {
        await player.seek(target);
      }
    } catch (e, st) {
      logError('PrismAudioHandler: fastForward error', e, st);
    }
  }

  @override
  Future<void> rewind() async {
    try {
      final current = player.position;
      final target = current - const Duration(seconds: 10);
      await player.seek(target < Duration.zero ? Duration.zero : target);
    } catch (e, st) {
      logError('PrismAudioHandler: rewind error', e, st);
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    try {
      await MediaSessionCoordinator.instance.cycleRepeatMode();
    } catch (e, st) {
      logError('PrismAudioHandler: setRepeatMode error', e, st);
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    try {
      await MediaSessionCoordinator.instance.toggleShuffle();
    } catch (e, st) {
      logError('PrismAudioHandler: setShuffleMode error', e, st);
    }
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    try {
      if (name == 'toggleLike' || name == 'favorite' || name == 'like') {
        await MediaSessionCoordinator.instance.toggleCurrentSongLike();
        return true;
      }
      return await super.customAction(name, extras);
    } catch (e, st) {
      logError('PrismAudioHandler: customAction error for $name', e, st);
      return false;
    }
  }

  // ==========================================
  // Android Auto / Car Mode MediaBrowser APIs
  // ==========================================

  DownloadService? get _downloads =>
      _downloadService ??
      (getIt.isRegistered<DownloadService>() ? getIt<DownloadService>() : null);

  LibraryRepository? get _library =>
      _libraryRepository ??
      (getIt.isRegistered<LibraryRepository>() ? getIt<LibraryRepository>() : null);

  MediaItem _songToMediaItem(Song song, {String prefix = ''}) {
    return MediaItem(
      id: '$prefix${song.id}',
      title: song.title,
      artist: song.artist,
      album: song.album ?? 'Prism Music',
      duration: song.duration,
      artUri: song.thumbnailUrl.isNotEmpty ? Uri.tryParse(song.thumbnailUrl) : null,
      playable: true,
      extras: {
        'songId': song.id,
        'durationMs': song.duration.inMilliseconds,
      },
    );
  }

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    try {
      if (parentMediaId == AudioService.MEDIA_ROOT_ID ||
          parentMediaId == 'root' ||
          parentMediaId.isEmpty) {
        return const [
          MediaItem(
            id: 'downloads',
            title: 'Downloads',
            album: 'Prism Music',
            playable: false,
            extras: {'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1},
          ),
          MediaItem(
            id: 'favorites',
            title: 'Liked Songs',
            album: 'Prism Music',
            playable: false,
            extras: {'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1},
          ),
          MediaItem(
            id: 'playlists',
            title: 'Playlists',
            album: 'Prism Music',
            playable: false,
            extras: {'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1},
          ),
          MediaItem(
            id: 'recent',
            title: 'Recently Played',
            album: 'Prism Music',
            playable: false,
            extras: {'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1},
          ),
          MediaItem(
            id: 'artists',
            title: 'Favorite Artists',
            album: 'Prism Music',
            playable: false,
            extras: {'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1},
          ),
        ];
      }

      if (parentMediaId == 'downloads') {
        final songs = _downloads?.getDownloadedSongsList() ?? [];
        return songs.map((s) => _songToMediaItem(s, prefix: 'download_')).toList();
      }

      if (parentMediaId == 'favorites') {
        final res = await _library?.getLikedSongs();
        final songs = res?.fold((l) => <Song>[], (r) => r) ?? [];
        return songs.map((s) => _songToMediaItem(s, prefix: 'fav_')).toList();
      }

      if (parentMediaId == 'playlists') {
        final res = await _library?.getUserPlaylists();
        final playlists = res?.fold((l) => <Playlist>[], (r) => r) ?? [];
        return playlists
            .map(
              (p) => MediaItem(
                id: 'playlist_${p.id}',
                title: p.name,
                album: '${p.trackCount} songs',
                playable: false,
                artUri: p.thumbnailUrl != null && p.thumbnailUrl!.isNotEmpty
                    ? Uri.tryParse(p.thumbnailUrl!)
                    : null,
                extras: {'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 2},
              ),
            )
            .toList();
      }

      if (parentMediaId.startsWith('playlist_')) {
        final playlistId = parentMediaId.substring('playlist_'.length);
        final res = await _library?.getUserPlaylists();
        final playlists = res?.fold((l) => <Playlist>[], (r) => r) ?? [];
        final playlist = playlists.where((p) => p.id == playlistId).firstOrNull;
        final songs = playlist?.songs ?? [];
        return songs
            .map((s) => _songToMediaItem(s, prefix: 'pl_${playlistId}_'))
            .toList();
      }

      if (parentMediaId == 'recent') {
        final res = await _library?.getListeningHistory(limit: 30);
        final songs = res?.fold((l) => <Song>[], (r) => r) ?? [];
        return songs.map((s) => _songToMediaItem(s, prefix: 'rec_')).toList();
      }

      if (parentMediaId == 'artists') {
        final res = await _library?.getFavoriteArtists();
        final artists = res?.fold((l) => <Artist>[], (r) => r) ?? [];
        return artists
            .map(
              (a) => MediaItem(
                id: 'artist_${a.id}',
                title: a.name,
                album: 'Artist',
                playable: false,
                artUri: a.thumbnailUrl != null && a.thumbnailUrl!.isNotEmpty
                    ? Uri.tryParse(a.thumbnailUrl!)
                    : null,
                extras: {'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1},
              ),
            )
            .toList();
      }

      if (parentMediaId.startsWith('artist_')) {
        final artistId = parentMediaId.substring('artist_'.length);
        final allSongs = <Song>[
          ...(_downloads?.getDownloadedSongsList() ?? []),
          ...((await _library?.getLikedSongs())?.fold((l) => <Song>[], (r) => r) ?? []),
        ];
        final artistSongs = allSongs
            .where((s) => s.artist.toLowerCase().contains(artistId.toLowerCase()) ||
                          s.artists.any((a) => a.toLowerCase().contains(artistId.toLowerCase())))
            .toList();
        return artistSongs
            .map((s) => _songToMediaItem(s, prefix: 'artist_${artistId}_'))
            .toList();
      }

      return const [];
    } catch (e, st) {
      logError('PrismAudioHandler: getChildren error for $parentMediaId', e, st);
      return const [];
    }
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    try {
      if (mediaId == AudioService.MEDIA_ROOT_ID || mediaId == 'root') {
        return const MediaItem(
          id: 'root',
          title: 'Prism Music',
          album: 'Prism Music',
          playable: false,
        );
      }
      final rootItems = await getChildren(AudioService.MEDIA_ROOT_ID);
      for (final item in rootItems) {
        if (item.id == mediaId) return item;
      }

      if (mediaId.startsWith('playlist_')) {
        final plId = mediaId.substring('playlist_'.length);
        final res = await _library?.getUserPlaylists();
        final playlists = res?.fold((l) => <Playlist>[], (r) => r) ?? [];
        final pl = playlists.where((p) => p.id == plId).firstOrNull;
        if (pl != null) {
          return MediaItem(
            id: mediaId,
            title: pl.name,
            album: '${pl.trackCount} songs',
            playable: false,
            artUri: pl.thumbnailUrl != null && pl.thumbnailUrl!.isNotEmpty
                ? Uri.tryParse(pl.thumbnailUrl!)
                : null,
          );
        }
      }

      if (mediaId.startsWith('artist_') && !mediaId.substring('artist_'.length).contains('_')) {
        final artistId = mediaId.substring('artist_'.length);
        final res = await _library?.getFavoriteArtists();
        final artists = res?.fold((l) => <Artist>[], (r) => r) ?? [];
        final artist = artists.where((a) => a.id == artistId).firstOrNull;
        if (artist != null) {
          return MediaItem(
            id: mediaId,
            title: artist.name,
            album: 'Artist',
            playable: false,
            artUri: artist.thumbnailUrl != null && artist.thumbnailUrl!.isNotEmpty
                ? Uri.tryParse(artist.thumbnailUrl!)
                : null,
          );
        }
      }

      final allSongs = <Song>[
        ...(_downloads?.getDownloadedSongsList() ?? []),
        ...((await _library?.getLikedSongs())?.fold((l) => <Song>[], (r) => r) ?? []),
        ...((await _library?.getListeningHistory(limit: 30))?.fold((l) => <Song>[], (r) => r) ?? []),
      ];

      for (final s in allSongs) {
        if (s.id == mediaId ||
            'download_${s.id}' == mediaId ||
            'fav_${s.id}' == mediaId ||
            'rec_${s.id}' == mediaId ||
            mediaId.endsWith('_${s.id}')) {
          return _songToMediaItem(s);
        }
      }

      return null;
    } catch (e, st) {
      logError('PrismAudioHandler: getMediaItem error for $mediaId', e, st);
      return null;
    }
  }

  /// Convenience alias for [getMediaItem]
  Future<MediaItem?> getItem(String mediaId) => getMediaItem(mediaId);

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    try {
      // 1. Play full playlist
      if (mediaId.startsWith('playlist_')) {
        final plId = mediaId.substring('playlist_'.length);
        final res = await _library?.getUserPlaylists();
        final playlists = res?.fold((l) => <Playlist>[], (r) => r) ?? [];
        final pl = playlists.where((p) => p.id == plId).firstOrNull;
        final songs = pl?.songs ?? [];
        if (songs.isNotEmpty) {
          MediaSessionCoordinator.instance.playFromMedia(songs.first, songs, 0);
        }
        return;
      }

      // 2. Play downloads folder
      if (mediaId == 'downloads') {
        final songs = _downloads?.getDownloadedSongsList() ?? [];
        if (songs.isNotEmpty) {
          MediaSessionCoordinator.instance.playFromMedia(songs.first, songs, 0);
        }
        return;
      }

      // 3. Play favorites folder
      if (mediaId == 'favorites') {
        final res = await _library?.getLikedSongs();
        final songs = res?.fold((l) => <Song>[], (r) => r) ?? [];
        if (songs.isNotEmpty) {
          MediaSessionCoordinator.instance.playFromMedia(songs.first, songs, 0);
        }
        return;
      }

      // 4. Play song inside downloads
      if (mediaId.startsWith('download_')) {
        final songId = mediaId.substring('download_'.length);
        final songs = _downloads?.getDownloadedSongsList() ?? [];
        final idx = songs.indexWhere((s) => s.id == songId);
        if (idx != -1) {
          MediaSessionCoordinator.instance.playFromMedia(songs[idx], songs, idx);
          return;
        }
      }

      // 5. Play song inside favorites
      if (mediaId.startsWith('fav_')) {
        final songId = mediaId.substring('fav_'.length);
        final res = await _library?.getLikedSongs();
        final songs = res?.fold((l) => <Song>[], (r) => r) ?? [];
        final idx = songs.indexWhere((s) => s.id == songId);
        if (idx != -1) {
          MediaSessionCoordinator.instance.playFromMedia(songs[idx], songs, idx);
          return;
        }
      }

      // 6. Play song inside playlist (pl_<playlistId>_<songId>)
      if (mediaId.startsWith('pl_')) {
        final parts = mediaId.split('_');
        if (parts.length >= 3) {
          final plId = parts[1];
          final songId = parts.sublist(2).join('_');
          final res = await _library?.getUserPlaylists();
          final playlists = res?.fold((l) => <Playlist>[], (r) => r) ?? [];
          final pl = playlists.where((p) => p.id == plId).firstOrNull;
          final songs = pl?.songs ?? [];
          final idx = songs.indexWhere((s) => s.id == songId);
          if (idx != -1) {
            MediaSessionCoordinator.instance.playFromMedia(songs[idx], songs, idx);
            return;
          }
        }
      }

      // 7. Play song inside recent
      if (mediaId.startsWith('rec_')) {
        final songId = mediaId.substring('rec_'.length);
        final res = await _library?.getListeningHistory(limit: 30);
        final songs = res?.fold((l) => <Song>[], (r) => r) ?? [];
        final idx = songs.indexWhere((s) => s.id == songId);
        if (idx != -1) {
          MediaSessionCoordinator.instance.playFromMedia(songs[idx], songs, idx);
          return;
        }
      }

      // 8. Play artist (or song inside artist)
      if (mediaId.startsWith('artist_')) {
        final remaining = mediaId.substring('artist_'.length);
        final allSongs = <Song>[
          ...(_downloads?.getDownloadedSongsList() ?? []),
          ...((await _library?.getLikedSongs())?.fold((l) => <Song>[], (r) => r) ?? []),
        ];
        if (remaining.contains('_')) {
          final parts = remaining.split('_');
          final songId = parts.sublist(1).join('_');
          final idx = allSongs.indexWhere((s) => s.id == songId);
          if (idx != -1) {
            MediaSessionCoordinator.instance.playFromMedia(allSongs[idx], allSongs, idx);
            return;
          }
        } else {
          final artistId = remaining;
          final artistSongs = allSongs
              .where((s) => s.artist.toLowerCase().contains(artistId.toLowerCase()) ||
                            s.artists.any((a) => a.toLowerCase().contains(artistId.toLowerCase())))
              .toList();
          if (artistSongs.isNotEmpty) {
            MediaSessionCoordinator.instance.playFromMedia(artistSongs.first, artistSongs, 0);
            return;
          }
        }
      }

      // Fallback: look for song by bare mediaId
      final allSongs = <Song>[
        ...(_downloads?.getDownloadedSongsList() ?? []),
        ...((await _library?.getLikedSongs())?.fold((l) => <Song>[], (r) => r) ?? []),
        ...((await _library?.getListeningHistory(limit: 30))?.fold((l) => <Song>[], (r) => r) ?? []),
      ];
      final matchIdx = allSongs.indexWhere((s) => s.id == mediaId);
      if (matchIdx != -1) {
        MediaSessionCoordinator.instance.playFromMedia(
          allSongs[matchIdx],
          [allSongs[matchIdx]],
          0,
        );
      }
    } catch (e, st) {
      logError('PrismAudioHandler: playFromMediaId error for $mediaId', e, st);
    }
  }

  @override
  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    try {
      final trimmed = query.trim().toLowerCase();
      if (trimmed.isEmpty) return const [];

      final downloadMatches = _downloads?.searchDownloadedSongs(trimmed) ?? [];
      if (downloadMatches.isNotEmpty) {
        return downloadMatches.map((s) => _songToMediaItem(s, prefix: 'download_')).toList();
      }

      final likedRes = await _library?.getLikedSongs();
      final liked = likedRes?.fold((l) => <Song>[], (r) => r) ?? [];
      final matchedLiked = liked
          .where(
            (s) =>
                s.title.toLowerCase().contains(trimmed) ||
                s.artist.toLowerCase().contains(trimmed),
          )
          .toList();
      if (matchedLiked.isNotEmpty) {
        return matchedLiked.map((s) => _songToMediaItem(s, prefix: 'fav_')).toList();
      }

      return const [];
    } catch (e, st) {
      logError('PrismAudioHandler: search error for "$query"', e, st);
      return const [];
    }
  }

  @override
  Future<void> playFromSearch(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    try {
      final results = await search(query, extras);
      if (results.isNotEmpty) {
        await playFromMediaId(results.first.id, extras);
      }
    } catch (e, st) {
      logError('PrismAudioHandler: playFromSearch error for "$query"', e, st);
    }
  }
}
