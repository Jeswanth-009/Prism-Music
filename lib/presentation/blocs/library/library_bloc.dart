import 'package:flutter_bloc/flutter_bloc.dart';
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
  }

  Future<void> _onLoadLibrary(
    LoadLibraryEvent event,
    Emitter<LibraryState> emit,
  ) async {
    emit(state.copyWith(status: LibraryStatus.loading));

    try {
      final likedResult = await _libraryRepository.getLikedSongs();
      final playlistsResult = await _libraryRepository.getUserPlaylists();
      final historyResult = await _libraryRepository.getListeningHistory(limit: _libraryHistoryLimit);
      final recentResult = await _libraryRepository.getRecentlyPlayed(limit: _libraryHistoryLimit);
      final downloadsResult = await _libraryRepository.getDownloadedSongs();
      final statsResult = await _libraryRepository.getListeningStats();

      likedResult.fold(
        (failure) => emit(state.copyWith(
          status: LibraryStatus.error,
          errorMessage: failure.message,
        )),
        (likedSongs) {
          final likedIds = likedSongs.map((s) => s.id).toSet();
          
          playlistsResult.fold(
            (failure) => null,
            (playlists) {
              historyResult.fold(
                (failure) => null,
                (history) {
                  recentResult.fold(
                    (failure) => null,
                    (recent) {
                      downloadsResult.fold(
                        (failure) => null,
                        (downloads) {
                          final downloadIds = downloads.map((s) => s.id).toSet();
                          
                          emit(state.copyWith(
                            status: LibraryStatus.success,
                            likedSongs: likedSongs,
                            likedSongIds: likedIds,
                            playlists: playlists,
                            history: history,
                            recentlyPlayed: recent,
                            stats: statsResult.fold(
                              (_) => state.stats,
                              (s) => s,
                            ),
                            downloads: downloads,
                            downloadedSongIds: downloadIds,
                          ));
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      );
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

    if (isCurrentlyLiked) {
      await _libraryRepository.unlikeSong(event.song.id);
      final updatedLiked = state.likedSongs.where((s) => s.id != event.song.id).toList();
      final updatedIds = Set<String>.from(state.likedSongIds)..remove(event.song.id);
      emit(state.copyWith(
        likedSongs: updatedLiked,
        likedSongIds: updatedIds,
      ));
    } else {
      await _libraryRepository.likeSong(event.song);
      final updatedLiked = [event.song, ...state.likedSongs];
      final updatedIds = Set<String>.from(state.likedSongIds)..add(event.song.id);
      emit(state.copyWith(
        likedSongs: updatedLiked,
        likedSongIds: updatedIds,
      ));
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
    await _libraryRepository.addSongToPlaylist(event.playlistId, event.song);
    // Reload the library to get updated playlist
    add(const LoadLibraryEvent());
  }

  Future<void> _onRemoveFromPlaylist(
    RemoveFromPlaylistEvent event,
    Emitter<LibraryState> emit,
  ) async {
    await _libraryRepository.removeSongFromPlaylist(
      event.playlistId,
      event.songId,
    );
    // Reload the library to get updated playlist
    add(const LoadLibraryEvent());
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
        final (saved, isNew) = await _persistImportedPlaylist(playlist);
        emit(state.copyWith(
          status: LibraryStatus.success,
          playlists: isNew
              ? [saved, ...state.playlists]
              : state.playlists
                  .map((p) => p.id == saved.id ? saved : p)
                  .toList(),
          importProgress: null,
        ));
        event.onDone?.call(null);
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
        final (saved, isNew) = await _persistImportedPlaylist(playlist);
        emit(state.copyWith(
          status: LibraryStatus.success,
          playlists: isNew
              ? [saved, ...state.playlists]
              : state.playlists
                  .map((p) => p.id == saved.id ? saved : p)
                  .toList(),
          importProgress: null,
        ));
        event.onDone?.call(null);
      },
    );
  }

  /// Save an imported playlist into the local library so it survives app
  /// restarts. When the same Spotify/YouTube playlist was imported before,
  /// its songs are refreshed in place instead of creating a duplicate.
  ///
  /// Returns the playlist as it should appear in state, plus whether it is
  /// a new entry. Falls back to the in-memory playlist when persistence
  /// fails.
  Future<(Playlist, bool)> _persistImportedPlaylist(Playlist playlist) async {
    final songs = playlist.songs ?? const <Song>[];

    final existing = state.playlists
        .where((p) => _matchesImport(p, playlist))
        .firstOrNull;
    if (existing != null) {
      final updated = existing.copyWith(
        name: playlist.name,
        thumbnails: playlist.thumbnails,
        author: playlist.author,
        description: playlist.description,
        songs: songs.toList(),
        trackCount: songs.length,
        updatedAt: DateTime.now(),
      );
      final result =
          await _libraryRepository.updatePlaylistSongs(existing.id, songs);
      // Keep the refreshed copy even when the write fails — the listener
      // gets correct state either way.
      result.fold((_) => null, (_) => null);
      return (updated, false);
    }

    final createdResult = await _libraryRepository.createPlaylist(
      playlist.name,
      description: playlist.description,
    );

    return createdResult.fold(
      (failure) async => (playlist, true),
      (created) async {
        for (final song in songs) {
          await _libraryRepository.addSongToPlaylist(created.id, song);
        }
        return (
          created.copyWith(
            songs: songs.toList(),
            trackCount: songs.length,
            thumbnails: playlist.thumbnails,
            author: playlist.author,
            spotifyPlaylistId: playlist.spotifyPlaylistId,
            youtubePlaylistId: playlist.youtubePlaylistId,
          ),
          true,
        );
      },
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
    emit(state.copyWith(history: []));
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
}
