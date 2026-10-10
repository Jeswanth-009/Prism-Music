import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import '../blocs/library/library.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../blocs/player/player_state.dart';
import '../theme/prism_theme.dart';
import '../widgets/common/bouncing_tap_widget.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/prism/prism_artwork.dart';
import '../widgets/prism/prism_dialog.dart';
import '../widgets/prism/prism_sheet.dart';
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
    );
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
                  }
                },
                itemBuilder: (_) => [
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: context.prismSpec.accentSoft,
                        borderRadius: BorderRadius.circular(PrismRadius.lg),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(PrismRadius.lg),
                        child: PrismArtwork(
                          url: playlist.thumbnailUrl ?? '',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (playlist.author != null &&
                              playlist.author!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              playlist.author!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            '${allSongs.length} ${allSongs.length == 1 ? 'song' : 'songs'}'
                            '${playlist.totalDurationFormatted.isEmpty ? '' : ' · ${playlist.totalDurationFormatted}'}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (allSongs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _play(context, displaySongs, 0),
                          icon: const Icon(Icons.play_arrow_rounded, size: 22),
                          label: const Text('Play all'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        tooltip: 'Shuffle play',
                        onPressed: () {
                          final shuffled = [...displaySongs]..shuffle();
                          context.read<PlayerBloc>().add(
                                PlaySongEvent(
                                  song: shuffled.first,
                                  queue: shuffled,
                                  queueIndex: 0,
                                ),
                              );
                        },
                        icon: const Icon(Icons.shuffle_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHigh,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_showSearch) ...[
                  const SizedBox(height: 14),
                  TextField(
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
                ],
              ],
            ),
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
                    trailing: playlist.isUserCreated
                        ? _RemoveSongButton(
                            playlistId: playlist.id,
                            songId: song.id,
                          )
                        : null,
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

/// Quiet remove affordance for a song inside a user playlist with accessible touch target.
class _RemoveSongButton extends StatelessWidget {
  const _RemoveSongButton({
    required this.playlistId,
    required this.songId,
  });

  final String playlistId;
  final String songId;

  @override
  Widget build(BuildContext context) {
    return BouncingTapWidget(
      onTap: () {
        context.read<LibraryBloc>().add(
              RemoveFromPlaylistEvent(playlistId: playlistId, songId: songId),
            );
        showPrismToast(context, 'Removed from playlist');
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          Icons.close_rounded,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
