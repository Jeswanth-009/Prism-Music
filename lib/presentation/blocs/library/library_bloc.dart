import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/error/failures.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/repositories.dart';
import 'library_event.dart';
import 'library_state.dart';

/// BLoC for managing user's local library
class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  final LibraryRepository _libraryRepository;
  final MusicRepository _musicRepository;
  static const int _libraryHistoryLimit = 500;

  LibraryBloc({
    required LibraryRepository libraryRepository,
    required MusicRepository musicRepository,
  })  : _libraryRepository = libraryRepository,
        _musicRepository = musicRepository,
        super(const LibraryState()) {
    on<LoadLibraryEvent>(_onLoadLibrary);
    on<ToggleLikeSongEvent>(_onToggleLikeSong);
    on<CreatePlaylistEvent>(_onCreatePlaylist);
    on<DeletePlaylistEvent>(_onDeletePlaylist);
    on<AddToPlaylistEvent>(_onAddToPlaylist);
    on<RemoveFromPlaylistEvent>(_onRemoveFromPlaylist);
    on<ImportSpotifyPlaylistEvent>(_onImportSpotifyPlaylist);
    on<ImportYouTubePlaylistEvent>(_onImportYouTubePlaylist);
    on<LoadHistoryEvent>(_onLoadHistory);
    on<ClearHistoryEvent>(_onClearHistory);
    on<DownloadSongEvent>(_onDownloadSong);
    on<DeleteDownloadEvent>(_onDeleteDownload);
    on<RenamePlaylistEvent>(_onRenamePlaylist);
    on<ReorderPlaylistSongsEvent>(_onReorderPlaylistSongs);
    on<SavePlaylistEvent>(_onSavePlaylist);
  }

  Future<void> _onLoadLibrary(
    LoadLibraryEvent event,
    Emitter<LibraryState> emit,
  ) async {
    emit(state.copyWith(status: LibraryStatus.loading));

    try {
      final results = await Future.wait([
        _libraryRepository.getLikedSongs(),
        _libraryRepository.getUserPlaylists(),
        _libraryRepository.getListeningHistory(limit: _libraryHistoryLimit),
        _libraryRepository.getRecentlyPlayed(limit: _libraryHistoryLimit),
        _libraryRepository.getDownloadedSongs(),
        _libraryRepository.getListeningStats(),
      ]);

      final likedResult = results[0] as Either<Failure, List<Song>>;
      final playlistsResult = results[1] as Either<Failure, List<Playlist>>;
      final historyResult = results[2] as Either<Failure, List<Song>>;
      final recentResult = results[3] as Either<Failure, List<Song>>;
      final downloadsResult = results[4] as Either<Failure, List<Song>>;
      final statsResult = results[5] as Either<Failure, ListeningStats>;

      final errors = <String>[];

      final likedSongs = likedResult.fold(
        (f) {
          errors.add('Liked songs: ${f.message}');
          return state.likedSongs;
        },
        (s) => s,
      );
      final likedIds = likedSongs.map((s) => s.id).toSet();

      final playlists = playlistsResult.fold(
        (f) {
          errors.add('Playlists: ${f.message}');
          return state.playlists;
        },
        (p) => p,
      );

      final history = historyResult.fold(
        (f) {
          errors.add('History: ${f.message}');
          return state.history;
        },
        (h) => h,
      );

      final recent = recentResult.fold(
        (f) {
          errors.add('Recent: ${f.message}');
          return state.recentlyPlayed;
        },
        (r) => r,
      );

      final downloads = downloadsResult.fold(
        (f) {
          errors.add('Downloads: ${f.message}');
          return state.downloads;
        },
        (d) => d,
      );
      final downloadIds = downloads.map((s) => s.id).toSet();

      final stats = statsResult.fold(
        (f) => state.stats,
        (s) => s,
      );

      final allFailed = likedResult.isLeft() &&
          playlistsResult.isLeft() &&
          historyResult.isLeft() &&
          recentResult.isLeft() &&
          downloadsResult.isLeft();

      if (allFailed) {
        emit(state.copyWith(
          status: LibraryStatus.error,
          errorMessage: errors.isNotEmpty ? errors.join('; ') : 'Failed to load library',
        ));
      } else {
        emit(state.copyWith(
          status: LibraryStatus.success,
          likedSongs: likedSongs,
          likedSongIds: likedIds,
          playlists: playlists,
          history: history,
          recentlyPlayed: recent,
          stats: stats,
          downloads: downloads,
          downloadedSongIds: downloadIds,
          errorMessage: errors.isNotEmpty ? errors.join('; ') : null,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: LibraryStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onToggleLikeSong(
    ToggleLikeSongEvent event,
    Emitter<LibraryState> emit,
  ) async {
    final isCurrentlyLiked = state.isSongLiked(event.song.id);
    final previousLiked = state.likedSongs;
    final previousIds = state.likedSongIds;

    if (isCurrentlyLiked) {
      final updatedLiked = state.likedSongs.where((s) => s.id != event.song.id).toList();
      final updatedIds = Set<String>.from(state.likedSongIds)..remove(event.song.id);
      emit(state.copyWith(
        likedSongs: updatedLiked,
        likedSongIds: updatedIds,
      ));

      final result = await _libraryRepository.unlikeSong(event.song.id);
      result.fold(
        (failure) {
          emit(state.copyWith(
            likedSongs: previousLiked,
            likedSongIds: previousIds,
            status: LibraryStatus.error,
            errorMessage: failure.message,
          ));
        },
        (_) {},
      );
    } else {
      final updatedLiked = [event.song, ...state.likedSongs];
      final updatedIds = Set<String>.from(state.likedSongIds)..add(event.song.id);
      emit(state.copyWith(
        likedSongs: updatedLiked,
        likedSongIds: updatedIds,
      ));

      final result = await _libraryRepository.likeSong(event.song);
      result.fold(
        (failure) {
          emit(state.copyWith(
            likedSongs: previousLiked,
            likedSongIds: previousIds,
            status: LibraryStatus.error,
            errorMessage: failure.message,
          ));
        },
        (_) {},
      );
    }
  }

  Future<void> _onCreatePlaylist(
    CreatePlaylistEvent event,
    Emitter<LibraryState> emit,
  ) async {
    final result = await _libraryRepository.createPlaylist(
      event.name,
      description: event.description,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: LibraryStatus.error,
        errorMessage: failure.message,
      )),
      (playlist) {
        final updatedPlaylists = [playlist, ...state.playlists];
        emit(state.copyWith(playlists: updatedPlaylists));
      },
    );
  }

  Future<void> _onDeletePlaylist(
    DeletePlaylistEvent event,
    Emitter<LibraryState> emit,
  ) async {
    final result = await _libraryRepository.deletePlaylist(event.playlistId);

    result.fold(
      (failure) => emit(state.copyWith(
        status: LibraryStatus.error,
        errorMessage: failure.message,
      )),
      (_) {
        final updatedPlaylists = state.playlists
            .where((p) => p.id != event.playlistId)
            .toList();
        emit(state.copyWith(playlists: updatedPlaylists));
      },
    );
  }

  Future<void> _onAddToPlaylist(
    AddToPlaylistEvent event,
    Emitter<LibraryState> emit,
  ) async {
    final result = await _libraryRepository.addSongToPlaylist(event.playlistId, event.song);
    result.fold(
      (failure) => emit(state.copyWith(
        status: LibraryStatus.error,
        errorMessage: failure.message,
      )),
      (_) => add(const LoadLibraryEvent()),
    );
  }

  Future<void> _onRemoveFromPlaylist(
    RemoveFromPlaylistEvent event,
    Emitter<LibraryState> emit,
  ) async {
    final result = await _libraryRepository.removeSongFromPlaylist(
      event.playlistId,
      event.songId,
    );
    result.fold(
      (failure) => emit(state.copyWith(
        status: LibraryStatus.error,
        errorMessage: failure.message,
      )),
      (_) => add(const LoadLibraryEvent()),
    );
  }

  Future<void> _onImportSpotifyPlaylist(
    ImportSpotifyPlaylistEvent event,
    Emitter<LibraryState> emit,
  ) async {
    emit(state.copyWith(
      status: LibraryStatus.importing,
      importProgress: 0.0,
      errorMessage: null,
    ));

    final result = await _musicRepository.importSpotifyPlaylist(
      event.playlistUrl,
      onProgress: (progress) => emit(state.copyWith(importProgress: progress)),
    );

    await result.fold(
      (failure) async {
        emit(state.copyWith(
          status: LibraryStatus.error,
          errorMessage: failure.message,
          importProgress: null,
        ));
        event.onDone?.call(failure.message);
      },
      (playlist) async {
        final persistResult = await _persistImportedPlaylist(playlist);
        persistResult.fold(
          (failure) {
            emit(state.copyWith(
              status: LibraryStatus.error,
              errorMessage: failure.message,
              importProgress: null,
            ));
            event.onDone?.call(failure.message);
          },
          (savedPair) {
            final (saved, isNew) = savedPair;
            emit(state.copyWith(
              status: LibraryStatus.success,
              playlists: isNew
                  ? <Playlist>[saved, ...state.playlists]
                  : state.playlists
                      .map((p) => p.id == saved.id ? saved : p)
                      .toList(),
              importProgress: null,
            ));
            event.onDone?.call(null);
          },
        );
      },
    );
  }

  Future<void> _onImportYouTubePlaylist(
    ImportYouTubePlaylistEvent event,
    Emitter<LibraryState> emit,
  ) async {
    emit(state.copyWith(
      status: LibraryStatus.importing,
      importProgress: 0.0,
      errorMessage: null,
    ));

    final result = await _musicRepository.importYouTubePlaylist(
      event.playlistUrl,
    );

    await result.fold(
      (failure) async {
        emit(state.copyWith(
          status: LibraryStatus.error,
          errorMessage: failure.message,
          importProgress: null,
        ));
        event.onDone?.call(failure.message);
      },
      (playlist) async {
        final persistResult = await _persistImportedPlaylist(playlist);
        persistResult.fold(
          (failure) {
            emit(state.copyWith(
              status: LibraryStatus.error,
              errorMessage: failure.message,
              importProgress: null,
            ));
            event.onDone?.call(failure.message);
          },
          (savedPair) {
            final (saved, isNew) = savedPair;
            emit(state.copyWith(
              status: LibraryStatus.success,
              playlists: isNew
                  ? <Playlist>[saved, ...state.playlists]
                  : state.playlists
                      .map((p) => p.id == saved.id ? saved : p)
                      .toList(),
              importProgress: null,
            ));
            event.onDone?.call(null);
          },
        );
      },
    );
  }

  /// Save an imported playlist into the local library so it survives app
  /// restarts. When the same Spotify/YouTube playlist was imported before,
  /// its metadata and songs are refreshed atomically.
  Future<Either<Failure, (Playlist, bool)>> _persistImportedPlaylist(Playlist playlist) async {
    final songs = playlist.songs ?? const <Song>[];

    final existing = state.playlists
        .where((p) => _matchesImport(p, playlist))
        .firstOrNull;
    if (existing != null) {
      final updated = existing.copyWith(
        name: playlist.name,
        thumbnails: playlist.thumbnails ?? existing.thumbnails,
        author: playlist.author ?? existing.author,
        description: playlist.description ?? existing.description,
        songs: songs.toList(),
        trackCount: songs.length,
        spotifyPlaylistId: playlist.spotifyPlaylistId ?? existing.spotifyPlaylistId,
        youtubePlaylistId: playlist.youtubePlaylistId ?? existing.youtubePlaylistId,
        updatedAt: DateTime.now(),
      );
      final result = await _libraryRepository.saveImportedPlaylist(updated);
      return result.fold(
        (failure) => Left(failure),
        (saved) => Right((saved, false)),
      );
    }

    final toCreate = playlist.copyWith(
      songs: songs.toList(),
      trackCount: songs.length,
      updatedAt: DateTime.now(),
    );
    final createdResult = await _libraryRepository.saveImportedPlaylist(toCreate);
    return createdResult.fold(
      (failure) => Left(failure),
      (created) => Right((created, true)),
    );
  }

  /// True when [existing] is a previous import of [imported] — matched on
  /// the persisted Spotify/YouTube source id.
  bool _matchesImport(Playlist existing, Playlist imported) =>
      (imported.spotifyPlaylistId != null &&
          existing.spotifyPlaylistId == imported.spotifyPlaylistId) ||
      (imported.youtubePlaylistId != null &&
          existing.youtubePlaylistId == imported.youtubePlaylistId);

  Future<void> _onLoadHistory(
    LoadHistoryEvent event,
    Emitter<LibraryState> emit,
  ) async {
    final result = await _libraryRepository.getListeningHistory();

    result.fold(
      (failure) => null,
      (history) => emit(state.copyWith(history: history)),
    );
  }

  Future<void> _onClearHistory(
    ClearHistoryEvent event,
    Emitter<LibraryState> emit,
  ) async {
    await _libraryRepository.clearHistory();
    emit(state.copyWith(
      history: const [],
      recentlyPlayed: const [],
      stats: const ListeningStats(),
    ));
  }

  Future<void> _onDownloadSong(
    DownloadSongEvent event,
    Emitter<LibraryState> emit,
  ) async {
    // Get stream URL first
    final streamResult = await _musicRepository.getStreamUrl(event.song.playableId);

    await streamResult.fold(
      (failure) async {
        emit(state.copyWith(
          status: LibraryStatus.error,
          errorMessage: failure.message,
        ));
      },
      (streamInfo) async {
        // Download the song
        final downloadResult = await _libraryRepository.downloadSong(
          event.song,
          streamInfo.url,
        );

        downloadResult.fold(
          (failure) {
            emit(state.copyWith(
              status: LibraryStatus.error,
              errorMessage: failure.message,
            ));
          },
          (filePath) {
            final updatedDownloads = [event.song, ...state.downloads];
            final updatedIds = Set<String>.from(state.downloadedSongIds)
              ..add(event.song.id);
            emit(state.copyWith(
              downloads: updatedDownloads,
              downloadedSongIds: updatedIds,
            ));
          },
        );
      },
    );
  }

  Future<void> _onDeleteDownload(
    DeleteDownloadEvent event,
    Emitter<LibraryState> emit,
  ) async {
    final result = await _libraryRepository.deleteDownload(event.songId);

    result.fold(
      (failure) => null,
      (_) {
        final updatedDownloads = state.downloads
            .where((s) => s.id != event.songId)
            .toList();
        final updatedIds = Set<String>.from(state.downloadedSongIds)
          ..remove(event.songId);
        emit(state.copyWith(
          downloads: updatedDownloads,
          downloadedSongIds: updatedIds,
        ));
      },
    );
  }

  Future<void> _onRenamePlaylist(
    RenamePlaylistEvent event,
    Emitter<LibraryState> emit,
  ) async {
    final result = await _libraryRepository.updatePlaylist(
      event.playlistId,
      name: event.name,
    );
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (updated) {
        final updatedPlaylists = state.playlists.map((p) {
          return p.id == updated.id ? updated : p;
        }).toList();
        emit(state.copyWith(playlists: updatedPlaylists));
      },
    );
  }

  Future<void> _onReorderPlaylistSongs(
    ReorderPlaylistSongsEvent event,
    Emitter<LibraryState> emit,
  ) async {
    final target =
        state.playlists.where((p) => p.id == event.playlistId).firstOrNull;
    if (target == null) return;
    final currentSongs = List<Song>.from(target.songs ?? []);
    if (event.oldIndex < 0 ||
        event.oldIndex >= currentSongs.length ||
        event.newIndex < 0 ||
        event.newIndex >= currentSongs.length) {
      return;
    }

    final song = currentSongs.removeAt(event.oldIndex);
    currentSongs.insert(event.newIndex, song);

    final updatedPlaylist = target.copyWith(songs: currentSongs);
    final updatedPlaylists = state.playlists.map((p) {
      return p.id == target.id ? updatedPlaylist : p;
    }).toList();
    emit(state.copyWith(playlists: updatedPlaylists));

    await _libraryRepository.reorderPlaylistSongs(
      event.playlistId,
      event.oldIndex,
      event.newIndex,
    );
  }

  Future<void> _onSavePlaylist(
    SavePlaylistEvent event,
    Emitter<LibraryState> emit,
  ) async {
    final result =
        await _libraryRepository.saveImportedPlaylist(event.playlist);
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (saved) {
        final exists = state.playlists.any((p) => p.id == saved.id);
        final updated = exists
            ? state.playlists.map((p) => p.id == saved.id ? saved : p).toList()
            : [saved, ...state.playlists];
        emit(state.copyWith(playlists: updated));
      },
    );
  }
}
