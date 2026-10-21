import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import '../blocs/library/library.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../blocs/player/player_state.dart';
import '../theme/prism_theme.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/prism/prism_artwork.dart';
import '../widgets/prism/prism_collection_header.dart';
import '../widgets/prism/prism_dialog.dart';
import '../widgets/prism/prism_sheet.dart';
import '../widgets/prism/prism_song_actions.dart';
import '../widgets/prism/prism_song_tile.dart';
import '../widgets/prism/prism_states.dart';

class PlaylistDetailPage extends StatefulWidget {
  const PlaylistDetailPage({super.key, required this.playlist});

  final Playlist playlist;

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isReordering = false;
  bool _showSearch = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showRenameDialog(BuildContext context, Playlist playlist) {
    final textController = TextEditingController(text: playlist.name);
    showPrismDialog(
      context: context,
      title: 'Rename Playlist',
      content: TextField(
        controller: textController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Playlist name',
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PrismRadius.lg),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final newName = textController.text.trim();
            if (newName.isNotEmpty) {
              context.read<LibraryBloc>().add(
                    RenamePlaylistEvent(
                      playlistId: playlist.id,
                      name: newName,
                    ),
                  );
              Navigator.of(context).pop();
            }
          },
          child: const Text('Save'),
        ),
      ],
    ).whenComplete(() => textController.dispose());
  }

  void _confirmDelete(BuildContext context, Playlist playlist) {
    showPrismConfirmDialog(
      context: context,
      title: 'Delete "${playlist.name}"?',
      message: 'This cannot be undone. All songs will be removed from this playlist.',
      confirmLabel: 'Delete playlist',
      isDestructive: true,
      onConfirm: () {
        context.read<LibraryBloc>().add(DeletePlaylistEvent(playlist.id));
      },
    );
  }

  void _refreshFromSource(BuildContext context, Playlist playlist) {
    showPrismToast(context, 'Refreshing playlist from source…');
    context.read<LibraryBloc>().add(
          RefreshImportedPlaylistEvent(
            playlist.id,
            onDone: (error) {
              if (!context.mounted) return;
              if (error != null) {
                showPrismToast(context, 'Refresh failed: $error');
              } else {
                showPrismToast(context, 'Playlist refreshed successfully');
              }
            },
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LibraryBloc, LibraryState>(
      listenWhen: (previous, current) {
        final existedBefore =
            previous.playlists.any((p) => p.id == widget.playlist.id);
        final existsNow =
            current.playlists.any((p) => p.id == widget.playlist.id);
        return existedBefore && !existsNow;
      },
      listener: (context, state) {
        // Gracefully exit when playlist was deleted
        Navigator.of(context).maybePop();
      },
      builder: (context, libraryState) {
        final current = libraryState.playlists
                .where((p) => p.id == widget.playlist.id)
                .firstOrNull ??
            widget.playlist;

        final songs = current.songs ?? const [];
        final query = _searchCtrl.text.trim().toLowerCase();
        final displaySongs = query.isEmpty
            ? songs
            : songs.where((s) {
                return s.title.toLowerCase().contains(query) ||
                    s.artist.toLowerCase().contains(query);
              }).toList();

        return Scaffold(
          bottomNavigationBar: const PrismPersistentMiniPlayer(),
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            actions: [
              if (songs.isNotEmpty)
                IconButton(
                  tooltip: _showSearch ? 'Close search' : 'Search in playlist',
                  icon: Icon(_showSearch
                      ? Icons.close_rounded
                      : Icons.search_rounded),
                  onPressed: () {
                    setState(() {
                      _showSearch = !_showSearch;
                      if (!_showSearch) _searchCtrl.clear();
                    });
                  },
                ),
              if (current.spotifyPlaylistId != null ||
                  current.youtubePlaylistId != null)
                IconButton(
                  tooltip: 'Refresh from source',
                  icon: const Icon(Icons.sync_rounded),
                  onPressed: () => _refreshFromSource(context, current),
                ),
              if (current.isUserCreated && songs.length > 1)
                IconButton(
                  tooltip: _isReordering ? 'Done reordering' : 'Reorder songs',
                  icon: Icon(_isReordering
                      ? Icons.check_rounded
                      : Icons.reorder_rounded),
                  onPressed: () {
                    setState(() {
                      _isReordering = !_isReordering;
                    });
                  },
                ),
              PopupMenuButton<String>(
                tooltip: 'Playlist options',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (val) {
                  if (val == 'rename') {
                    _showRenameDialog(context, current);
                  } else if (val == 'delete') {
                    _confirmDelete(context, current);
                  } else if (val == 'refresh') {
                    _refreshFromSource(context, current);
                  }
                },
                itemBuilder: (_) => [
                  if (current.spotifyPlaylistId != null ||
                      current.youtubePlaylistId != null)
                    const PopupMenuItem(
                      value: 'refresh',
                      child: Text('Refresh from source'),
                    ),
                  if (current.isUserCreated)
                    const PopupMenuItem(
                      value: 'rename',
                      child: Text('Rename playlist'),
                    ),
                  if (current.isUserCreated)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete playlist'),
                    ),
                ],
              ),
            ],
          ),
          body: _isReordering
              ? _buildReorderList(context, current, songs)
              : _buildPlaylistView(context, current, displaySongs),
        );
      },
    );
  }

  Widget _buildReorderList(
    BuildContext context,
    Playlist playlist,
    List<Song> songs,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: theme.colorScheme.surfaceContainerHigh,
          child: Text(
            'Drag songs to change playlist order',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
            itemCount: songs.length,
            onReorder: (oldIndex, newIndex) {
              if (oldIndex < newIndex) newIndex -= 1;
              context.read<LibraryBloc>().add(
                    ReorderPlaylistSongsEvent(
                      playlistId: playlist.id,
                      oldIndex: oldIndex,
                      newIndex: newIndex,
                    ),
                  );
            },
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                key: ValueKey('reorder_${song.id}_$index'),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(PrismRadius.xs),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: PrismArtwork(url: song.thumbnailUrl),
                  ),
                ),
                title: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.drag_handle_rounded),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistView(
    BuildContext context,
    Playlist playlist,
    List<Song> displaySongs,
  ) {
    final theme = Theme.of(context);
    final allSongs = playlist.songs ?? const [];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PrismCollectionHeader(
                title: playlist.name,
                badge: playlist.spotifyPlaylistId != null
                    ? 'Spotify Import'
                    : (playlist.youtubePlaylistId != null
                        ? 'YouTube Import'
                        : (playlist.isUserCreated ? 'Playlist' : 'Featured')),
                subtitle: playlist.author,
                artworkUrl: playlist.thumbnailUrl,
                icon: Icons.queue_music_rounded,
                metadata: '${Formatters.formatCount(allSongs.length, 'song')}'
                    '${playlist.totalDurationFormatted.isEmpty ? '' : ' · ${playlist.totalDurationFormatted}'}',
                onPlayAll: allSongs.isEmpty
                    ? null
                    : () => _play(context, displaySongs, 0),
                onShuffle: allSongs.isEmpty
                    ? null
                    : () {
                        final shuffled = [...displaySongs]..shuffle();
                        context.read<PlayerBloc>().add(
                              PlaySongEvent(
                                song: shuffled.first,
                                queue: shuffled,
                                queueIndex: 0,
                              ),
                            );
                      },
              ),
              if (_showSearch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Filter playlist…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHigh
                          .withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PrismRadius.lg),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
            ],
          ),
        ),
        if (allSongs.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: PrismEmptyState(
              icon: Icons.queue_music_rounded,
              message: 'This playlist has no available songs yet.',
            ),
          )
        else if (displaySongs.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: PrismEmptyState(
              icon: Icons.search_off_rounded,
              message: 'No matching songs found',
              hint: 'Try a different filter term.',
              actionLabel: 'Clear filter',
              onAction: () => setState(() => _searchCtrl.clear()),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
            sliver: SliverList.builder(
              itemCount: displaySongs.length,
              itemBuilder: (context, index) {
                final song = displaySongs[index];
                return BlocBuilder<PlayerBloc, PlayerState>(
                  builder: (context, playerState) => PrismSongTile(
                    song: song,
                    isPlaying: playerState.currentSong?.id == song.id,
                    isPlayingPaused: !playerState.isPlaying,
                    onTap: () => _play(context, displaySongs, index),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (playlist.isUserCreated)
                          _RemoveSongButton(
                            playlistId: playlist.id,
                            songId: song.id,
                          ),
                        IconButton(
                          icon: const Icon(Icons.more_vert_rounded, size: 18),
                          tooltip: 'More options for ${song.title}',
                          onPressed: () => showPrismSongActions(context, song),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _play(BuildContext context, List<Song> queue, int index) {
    if (queue.isEmpty) return;
    context.read<PlayerBloc>().add(
          PlaySongEvent(
            song: queue[index],
            queue: queue,
            queueIndex: index,
          ),
        );
  }
}

/// Accessible remove affordance for a song inside a user playlist.
class _RemoveSongButton extends StatelessWidget {
  const _RemoveSongButton({
    required this.playlistId,
    required this.songId,
  });

  final String playlistId;
  final String songId;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Remove from playlist',
      icon: Icon(
        Icons.close_rounded,
        size: 18,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onPressed: () {
        context.read<LibraryBloc>().add(
              RemoveFromPlaylistEvent(playlistId: playlistId, songId: songId),
            );
        showPrismToast(context, 'Removed from playlist');
      },
    );
  }
}
