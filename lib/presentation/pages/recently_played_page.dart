import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/song.dart';
import '../blocs/library/library.dart';
import '../blocs/player/player.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/prism/prism_dialog.dart';
import '../widgets/prism/prism_song_tile.dart';
import '../widgets/prism/prism_states.dart';

/// Full view of listening history with clear controls, play all, and persistent playback.
class RecentlyPlayedPage extends StatelessWidget {
  const RecentlyPlayedPage({super.key});

  void _confirmClear(BuildContext context) {
    showPrismConfirmDialog(
      context: context,
      title: 'Clear listening history?',
      message:
          'This will remove all recently played tracks from your history. Your saved stats and playlists will remain untouched.',
      confirmLabel: 'Clear history',
      isDestructive: true,
      onConfirm: () {
        context.read<LibraryBloc>().add(const ClearHistoryEvent());
      },
    );
  }

  void _playAll(BuildContext context, List<Song> songs, {bool shuffle = false}) {
    if (songs.isEmpty) return;
    final queue = shuffle ? ([...songs]..shuffle()) : songs;
    context.read<PlayerBloc>().add(
      PlaySongEvent(song: queue.first, queue: queue, queueIndex: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      bottomNavigationBar: const PrismPersistentMiniPlayer(),
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Recently Played'),
        actions: [
          BlocBuilder<LibraryBloc, LibraryState>(
            builder: (context, state) {
              if (state.recentlyPlayed.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Clear history',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => _confirmClear(context),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<LibraryBloc, LibraryState>(
        builder: (context, state) {
          final songs = state.recentlyPlayed;

          if (songs.isEmpty) {
            return const PrismEmptyState(
              icon: Icons.history_rounded,
              message: 'No recently played songs yet',
              hint: 'Tracks you listen to will automatically appear here.',
            );
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      Text(
                        '${songs.length} ${songs.length == 1 ? 'song' : 'songs'} in history',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.tonalIcon(
                        onPressed: () => _playAll(context, songs),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('Play all'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Shuffle history',
                        onPressed: () => _playAll(context, songs, shuffle: true),
                        icon: const Icon(Icons.shuffle_rounded, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
                sliver: SliverList.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return BlocBuilder<PlayerBloc, PlayerState>(
                      builder: (context, playerState) => PrismSongTile(
                        song: song,
                        isPlaying: playerState.currentSong?.id == song.id,
                        isPlayingPaused: !playerState.isPlaying,
                        onTap: () => context.read<PlayerBloc>().add(
                          PlaySongEvent(
                            song: song,
                            queue: songs,
                            queueIndex: index,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
