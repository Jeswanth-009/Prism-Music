import 'package:dartz/dartz.dart';
import '../../core/error/error.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/library_repository.dart';
import '../datasources/local/local_datasource.dart';

/// Implementation of LibraryRepository using local storage
class LibraryRepositoryImpl implements LibraryRepository {
  final LocalDataSource _localDataSource;

  LibraryRepositoryImpl({
    required LocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  // ============ LIKED SONGS ============

  @override
  Future<Either<Failure, List<Song>>> getLikedSongs() async {
    try {
      final songs = await _localDataSource.getLikedSongs();
      return Right(songs);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> likeSong(Song song) async {
    try {
      await _localDataSource.likeSong(song);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> unlikeSong(String songId) async {
    try {
      await _localDataSource.unlikeSong(songId);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<bool> isSongLiked(String songId) async {
    return _localDataSource.isSongLiked(songId);
  }

  // ============ PLAYLISTS ============

  @override
  Future<Either<Failure, List<Playlist>>> getUserPlaylists() async {
    try {
      final playlists = await _localDataSource.getPlaylists();
      return Right(playlists);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Playlist>> createPlaylist(
    String name, {
    String? description,
  }) async {
    try {
      final playlist = await _localDataSource.createPlaylist(
        name,
        description: description,
      );
      return Right(playlist);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deletePlaylist(String playlistId) async {
    try {
      await _localDataSource.deletePlaylist(playlistId);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Playlist>> updatePlaylist(
    String playlistId, {
    String? name,
    String? description,
  }) async {
    try {
      final playlist = await _localDataSource.updatePlaylist(
        playlistId,
        name: name,
        description: description,
      );
      return Right(playlist);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addSongToPlaylist(
    String playlistId,
    Song song,
  ) async {
    try {
      await _localDataSource.addSongToPlaylist(playlistId, song);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> removeSongFromPlaylist(
    String playlistId,
    String songId,
  ) async {
    try {
      await _localDataSource.removeSongFromPlaylist(playlistId, songId);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> reorderPlaylistSongs(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    try {
      // Get current playlist
      final playlist = await _localDataSource.getPlaylist(playlistId);
      if (playlist == null || playlist.songs == null) {
        return const Left(CacheFailure(message: 'Playlist not found'));
      }

      // Reorder songs
      final songs = List<Song>.from(playlist.songs!);
      final song = songs.removeAt(oldIndex);
      songs.insert(newIndex, song);

      // Update playlist
      // Note: This would need proper implementation to persist the order
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  // ============ LISTENING HISTORY ============

  @override
  Future<Either<Failure, List<Song>>> getListeningHistory({
    int limit = 50,
    DateTime? since,
  }) async {
    try {
      final history = await _localDataSource.getListeningHistory(
        limit: limit,
        since: since,
      );
      return Right(history);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addToHistory(Song song) async {
    try {
      await _localDataSource.addToHistory(song);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearHistory() async {
    try {
      await _localDataSource.clearHistory();
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Song>>> getRecentlyPlayed({int limit = 20}) async {
    return getListeningHistory(limit: limit);
  }

  // ============ DOWNLOADS ============

  @override
  Future<Either<Failure, List<Song>>> getDownloadedSongs() async {
    try {
      final songs = await _localDataSource.getDownloadedSongs();
      return Right(songs);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> downloadSong(
    Song song,
    String streamUrl, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      // TODO: Implement actual download with dio
      // For now, just save the metadata
      final filePath = '/downloads/${song.id}.opus';
      await _localDataSource.saveDownload(song, filePath);
      return Right(filePath);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(DownloadFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteDownload(String songId) async {
    try {
      await _localDataSource.deleteDownload(songId);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<bool> isSongDownloaded(String songId) async {
    return _localDataSource.isSongDownloaded(songId);
  }

  @override
  Future<String?> getDownloadedSongPath(String songId) async {
    return _localDataSource.getDownloadPath(songId);
  }

  // ============ CACHED METADATA ============

  @override
  Future<Either<Failure, void>> cacheSong(Song song) async {
    try {
      await _localDataSource.cacheSong(song);
      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Song?> getCachedSong(String songId) async {
    return _localDataSource.getCachedSong(songId);
  }

  @override
  Future<Either<Failure, void>> clearCache() async {
    try {
      await _localDataSource.clearCache();
      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
