import 'package:equatable/equatable.dart';
import '../../../core/utils/cancellation_token.dart';
import '../../../domain/entities/entities.dart';

/// Base class for all library events
abstract class LibraryEvent extends Equatable {
  const LibraryEvent();

  @override
  List<Object?> get props => [];
}

/// Load user's library (liked songs, playlists)
class LoadLibraryEvent extends LibraryEvent {
  const LoadLibraryEvent();
}

/// Toggle like status for a song
class ToggleLikeSongEvent extends LibraryEvent {
  final Song song;

  const ToggleLikeSongEvent(this.song);

  @override
  List<Object?> get props => [song];
}

/// Create a new playlist
class CreatePlaylistEvent extends LibraryEvent {
  final String name;
  final String? description;

  const CreatePlaylistEvent({
    required this.name,
    this.description,
  });

  @override
  List<Object?> get props => [name, description];
}

/// Delete a playlist
class DeletePlaylistEvent extends LibraryEvent {
  final String playlistId;

  const DeletePlaylistEvent(this.playlistId);

  @override
  List<Object?> get props => [playlistId];
}

/// Add song to playlist
class AddToPlaylistEvent extends LibraryEvent {
  final String playlistId;
  final Song song;

  const AddToPlaylistEvent({
    required this.playlistId,
    required this.song,
  });

  @override
  List<Object?> get props => [playlistId, song];
}

/// Remove song from playlist
class RemoveFromPlaylistEvent extends LibraryEvent {
  final String playlistId;
  final String songId;

  const RemoveFromPlaylistEvent({
    required this.playlistId,
    required this.songId,
  });

  @override
  List<Object?> get props => [playlistId, songId];
}

/// Import a Spotify playlist
///
/// [onDone] is called exactly once when the import settles — null means
/// success, otherwise it carries the error message. Callers use it to await
/// the result instead of racing on the state stream.
/// [onResult] provides the rich [ImportPlaylistResult] for review.
/// [cancelToken] permits aborting the import cooperatively.
class ImportSpotifyPlaylistEvent extends LibraryEvent {
  final String playlistUrl;
  final void Function(String? errorMessage)? onDone;
  final void Function(ImportPlaylistResult result)? onResult;
  final ImportCancellationToken? cancelToken;

  const ImportSpotifyPlaylistEvent(
    this.playlistUrl, {
    this.onDone,
    this.onResult,
    this.cancelToken,
  });

  @override
  List<Object?> get props => [playlistUrl];
}

/// Cancel an ongoing playlist import
class CancelImportEvent extends LibraryEvent {
  const CancelImportEvent();
}

/// Import a YouTube playlist
class ImportYouTubePlaylistEvent extends LibraryEvent {
  final String playlistUrl;
  final void Function(String? errorMessage)? onDone;
  final void Function(ImportPlaylistResult result)? onResult;

  const ImportYouTubePlaylistEvent(
    this.playlistUrl, {
    this.onDone,
    this.onResult,
  });

  @override
  List<Object?> get props => [playlistUrl];
}

/// Refresh an imported playlist from its original Spotify or YouTube source
class RefreshImportedPlaylistEvent extends LibraryEvent {
  final String playlistId;
  final void Function(String? errorMessage)? onDone;
  final void Function(ImportPlaylistResult? result)? onResult;

  const RefreshImportedPlaylistEvent(
    this.playlistId, {
    this.onDone,
    this.onResult,
  });

  @override
  List<Object?> get props => [playlistId];
}

/// Load listening history
class LoadHistoryEvent extends LibraryEvent {
  const LoadHistoryEvent();
}

/// Clear listening history
class ClearHistoryEvent extends LibraryEvent {
  const ClearHistoryEvent();
}

/// Download a song
class DownloadSongEvent extends LibraryEvent {
  final Song song;

  const DownloadSongEvent(this.song);

  @override
  List<Object?> get props => [song];
}

/// Delete downloaded song
class DeleteDownloadEvent extends LibraryEvent {
  final String songId;

  const DeleteDownloadEvent(this.songId);

  @override
  List<Object?> get props => [songId];
}

/// Rename or update details for an existing playlist
class RenamePlaylistEvent extends LibraryEvent {
  final String playlistId;
  final String name;
  final String? description;

  const RenamePlaylistEvent({
    required this.playlistId,
    required this.name,
    this.description,
  });

  @override
  List<Object?> get props => [playlistId, name, description];
}

/// Reorder songs in a playlist
class ReorderPlaylistSongsEvent extends LibraryEvent {
  final String playlistId;
  final int oldIndex;
  final int newIndex;

  const ReorderPlaylistSongsEvent({
    required this.playlistId,
    required this.oldIndex,
    required this.newIndex,
  });

  @override
  List<Object?> get props => [playlistId, oldIndex, newIndex];
}

/// Save / import a playlist into the user library
class SavePlaylistEvent extends LibraryEvent {
  final Playlist playlist;

  const SavePlaylistEvent(this.playlist);

  @override
  List<Object?> get props => [playlist];
}

/// Toggle favorite status for an artist
class ToggleFavoriteArtistEvent extends LibraryEvent {
  final Artist artist;

  const ToggleFavoriteArtistEvent(this.artist);

  @override
  List<Object?> get props => [artist];
}

/// Load favorite artists from storage
class LoadFavoriteArtistsEvent extends LibraryEvent {
  const LoadFavoriteArtistsEvent();
}

/// Remove a single song from listening history
class RemoveSongFromHistoryEvent extends LibraryEvent {
  final String songId;

  const RemoveSongFromHistoryEvent(this.songId);

  @override
  List<Object?> get props => [songId];
}

