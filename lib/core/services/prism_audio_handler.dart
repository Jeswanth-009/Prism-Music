import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/library_repository.dart';
import '../di/injection.dart';
import 'download_service.dart';
import 'media_session_coordinator.dart';

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
    player.playbackEventStream.listen(_broadcastState);

    // Update notification metadata (title, artist, artwork)
    player.sequenceStateStream.listen((sequenceState) {
      if (sequenceState.currentSource != null) {
        final tag = sequenceState.currentSource!.tag;
        if (tag is MediaItem) {
          mediaItem.add(tag);
          // Re-broadcast so the control buttons re-render for the new
          // track's position in the queue (e.g. previous becomes usable).
          _broadcastState(player.playbackEvent);
        }
      }
    });

    // Update queue metadata
    player.sequenceStream.listen((sequence) {
      final items = sequence
          .where((s) => s.tag is MediaItem)
          .map((s) => s.tag as MediaItem)
          .toList();
      queue.add(items);
    });
  }

  static const MediaControl favoriteControl = MediaControl(
    androidIcon: 'drawable/ic_heart',
    label: 'Favorite',
    action: MediaAction.custom,
  );

  void _broadcastState(PlaybackEvent event) {
    final playing = player.playing;
    final coordinator = MediaSessionCoordinator.instance;
    final controls = <MediaControl>[
      if (coordinator.canSkipPrevious) MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      if (coordinator.canSkipNext) MediaControl.skipToNext,
      favoriteControl,
      MediaControl.fastForward,
      MediaControl.rewind,
      MediaControl.stop,
    ];

    // Compute compact action indices for lock screen: center on playback & skips.
    final compactActionIndices = <int>[];
    final prevIdx = controls.indexOf(MediaControl.skipToPrevious);
    final playIdx = controls.indexOf(playing ? MediaControl.pause : MediaControl.play);
    final nextIdx = controls.indexOf(MediaControl.skipToNext);
    if (prevIdx != -1) {
      compactActionIndices.add(prevIdx);
    } else {
      final favIdx = controls.indexOf(favoriteControl);
      if (favIdx != -1) compactActionIndices.add(favIdx);
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
  }

  /// Re-render the notification's controls after queue enablement changed.
  void refreshNotificationState() {
    _broadcastState(player.playbackEvent);
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() async {
    // The X on the notification means "close playback": let the bloc reset
    // its state (history, queue UI) instead of only stopping raw audio.
    await MediaSessionCoordinator.instance.stopFromNotification();
    return super.stop();
  }

  @override
  Future<void> skipToNext() => MediaSessionCoordinator.instance.skipNext();

  @override
  Future<void> skipToPrevious() =>
      MediaSessionCoordinator.instance.skipPrevious();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> fastForward() async {
    final current = player.position;
    final total = player.duration;
    final target = current + const Duration(seconds: 10);
    if (total != null && target > total) {
      await player.seek(total);
    } else {
      await player.seek(target);
    }
  }

  @override
  Future<void> rewind() async {
    final current = player.position;
    final target = current - const Duration(seconds: 10);
    await player.seek(target < Duration.zero ? Duration.zero : target);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    await MediaSessionCoordinator.instance.cycleRepeatMode();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    await MediaSessionCoordinator.instance.toggleShuffle();
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'toggleLike' || name == 'favorite' || name == 'like') {
      await MediaSessionCoordinator.instance.toggleCurrentSongLike();
      return true;
    }
    return super.customAction(name, extras);
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

    return const [];
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
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
  }

  /// Convenience alias for [getMediaItem]
  Future<MediaItem?> getItem(String mediaId) => getMediaItem(mediaId);

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
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
  }

  @override
  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
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
  }

  @override
  Future<void> playFromSearch(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    final results = await search(query, extras);
    if (results.isNotEmpty) {
      await playFromMediaId(results.first.id, extras);
    }
  }
}
