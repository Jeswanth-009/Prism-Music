import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/di/injection.dart';
import '../../../domain/entities/song.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../blocs/library/library.dart';
import '../../blocs/player/player.dart' hide DownloadSongEvent;
import '../../theme/prism_theme.dart';
import 'prism_sheet.dart';

/// Standard context menu for a song: play next, queue, playlists, like,
/// download, share. Opened by long-pressing any [PrismSongTile] or via the
/// player's options menu.
Future<void> showPrismSongActions(BuildContext context, Song song) {
  return showPrismSheet(
    context: context,
    builder: (sheetContext) => _SongActionsSheet(song: song),
  );
}

/// Playlist chooser for [showPrismSongActions] — exposed separately so the
/// player's own menu can link straight to it.
Future<void> showPrismPlaylistPicker(BuildContext context, Song song) {
  return showPrismSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _PlaylistPickerSheet(song: song),
  );
}

class _SongActionsSheet extends StatelessWidget {
  const _SongActionsSheet({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BlocBuilder<LibraryBloc, LibraryState>(
        builder: (context, library) {
          final isLiked = library.isSongLiked(song.id);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(PrismRadius.sm),
                      child: SizedBox.square(
                        dimension: 44,
                        child: song.thumbnailUrl.isNotEmpty
                            ? Image.network(
                                song.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox(),
                              )
                            : const SizedBox(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              PrismSheetAction(
                icon: Icons.play_arrow_rounded,
                label: 'Play now',
                onTap: () {
                  Navigator.pop(context);
                  context
                      .read<PlayerBloc>()
                      .add(PlaySongEvent(song: song, queue: [song]));
                },
              ),
              PrismSheetAction(
                icon: Icons.low_priority_rounded,
                label: 'Play next',
                onTap: () {
                  Navigator.pop(context);
                  context.read<PlayerBloc>().add(
                        AddToQueueEvent(song: song, playNext: true),
                      );
                  showPrismToast(context, 'Playing next');
                },
              ),
              PrismSheetAction(
                icon: Icons.queue_music_rounded,
                label: 'Add to queue',
                onTap: () {
                  Navigator.pop(context);
                  context
                      .read<PlayerBloc>()
                      .add(AddToQueueEvent(song: song));
                  showPrismToast(context, 'Added to queue');
                },
              ),
              PrismSheetAction(
                icon: Icons.playlist_add_rounded,
                label: 'Add to playlist',
                onTap: () {
                  Navigator.pop(context);
                  showPrismPlaylistPicker(context, song);
                },
              ),
              PrismSheetAction(
                icon: isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_outline_rounded,
                label: isLiked
                    ? 'Remove from liked'
                    : 'Add to liked songs',
                onTap: () {
                  Navigator.pop(context);
                  context.read<LibraryBloc>().add(ToggleLikeSongEvent(song));
                },
              ),
              PrismSheetAction(
                icon: Icons.download_rounded,
                label: 'Download',
                onTap: () {
                  Navigator.pop(context);
                  context.read<LibraryBloc>().add(DownloadSongEvent(song));
                  showPrismToast(context, 'Downloading "${song.title}"…');
                },
              ),
              PrismSheetAction(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: () {
                  Navigator.pop(context);
                  final videoId = song.youtubeId ?? song.id;
                  final url = 'https://music.youtube.com/watch?v=$videoId';
                  ShareSong.share(song.title, song.artist, url);
                },
              ),
              const SizedBox(height: 6),
            ],
          );
        },
      ),
    );
  }
}

class _PlaylistPickerSheet extends StatelessWidget {
  const _PlaylistPickerSheet({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BlocBuilder<LibraryBloc, LibraryState>(
        builder: (context, state) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add to playlist',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
            if (state.playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                child: Text(
                  'You have no playlists yet — create one below.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: state.playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = state.playlists[index];
                    return ListTile(
                      leading: const Icon(Icons.queue_music_rounded),
                      title: Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${playlist.trackCount} songs'),
                      onTap: () {
                        Navigator.pop(context);
                        context.read<LibraryBloc>().add(
                              AddToPlaylistEvent(
                                playlistId: playlist.id,
                                song: song,
                              ),
                            );
                        showPrismToast(
                          context,
                          'Added to ${playlist.name}',
                        );
                      },
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
              child: OutlinedButton.icon(
                onPressed: () => _createAndAdd(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New playlist'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAndAdd(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) =>
              Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty || !context.mounted) return;

    // Create via the repository so we get the new playlist's id back and
    // can add the song in the same breath; then refresh the bloc.
    final result = await getIt<LibraryRepository>()
        .createPlaylist(name, description: null);
    if (!context.mounted) return;
    result.fold(
      (failure) => showPrismToast(context, 'Could not create playlist'),
      (playlist) {
        context.read<LibraryBloc>().add(const LoadLibraryEvent());
        context.read<LibraryBloc>().add(
              AddToPlaylistEvent(playlistId: playlist.id, song: song),
            );
        Navigator.pop(context);
        showPrismToast(context, 'Added to $name');
      },
    );
  }
}

/// Share helper kept out of the widget tree for reuse.
abstract final class ShareSong {
  static void share(String title, String artist, String url) {
    Share.share('$title - $artist\n$url');
  }
}
