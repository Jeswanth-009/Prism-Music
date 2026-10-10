import 'package:equatable/equatable.dart';
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
class ImportSpotifyPlaylistEvent extends LibraryEvent {
  final String playlistUrl;
  final void Function(String? errorMessage)? onDone;

  const ImportSpotifyPlaylistEvent(this.playlistUrl, {this.onDone});

  @override
  List<Object?> get props => [playlistUrl];
}

/// Import a YouTube playlist
class ImportYouTubePlaylistEvent extends LibraryEvent {
  final String playlistUrl;
  final void Function(String? errorMessage)? onDone;

  const ImportYouTubePlaylistEvent(this.playlistUrl, {this.onDone});

  @override
  List<Object?> get props => [playlistUrl];
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

/// Rename an existing playlist
class RenamePlaylistEvent extends LibraryEvent {
  final String playlistId;
  final String name;

  const RenamePlaylistEvent({
    required this.playlistId,
    required this.name,
  });

  @override
  List<Object?> get props => [playlistId, name];
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

