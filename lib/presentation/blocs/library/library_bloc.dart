import 'package:flutter_bloc/flutter_bloc.dart';
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
    ));

    try {
      final result = await _musicRepository.importSpotifyPlaylist(event.playlistUrl);

      result.fold(
        (failure) {
          emit(state.copyWith(
            status: LibraryStatus.error,
            errorMessage: failure.message,
            importProgress: null,
          ));
        },
        (playlist) {
          final updatedPlaylists = [playlist, ...state.playlists];
          emit(state.copyWith(
            status: LibraryStatus.success,
            playlists: updatedPlaylists,
            importProgress: null,
          ));
        },
      );
    } catch (e) {
      emit(state.copyWith(
        status: LibraryStatus.error,
        errorMessage: e.toString(),
        importProgress: null,
      ));
    }
  }

  Future<void> _onImportYouTubePlaylist(
    ImportYouTubePlaylistEvent event,
    Emitter<LibraryState> emit,
  ) async {
    emit(state.copyWith(
      status: LibraryStatus.importing,
      importProgress: 0.0,
    ));

    try {
      final result = await _musicRepository.importYouTubePlaylist(event.playlistUrl);

      result.fold(
        (failure) {
          emit(state.copyWith(
            status: LibraryStatus.error,
            errorMessage: failure.message,
            importProgress: null,
          ));
        },
        (playlist) {
          final updatedPlaylists = [playlist, ...state.playlists];
          emit(state.copyWith(
            status: LibraryStatus.success,
            playlists: updatedPlaylists,
            importProgress: null,
          ));
        },
      );
    } catch (e) {
      emit(state.copyWith(
        status: LibraryStatus.error,
        errorMessage: e.toString(),
        importProgress: null,
      ));
    }
  }

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
