import 'dart:ui';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/utils/date_grouping.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/entities.dart';
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
              final hasItems =
                  state.historyEntries.isNotEmpty || state.recentlyPlayed.isNotEmpty;
              if (!hasItems) return const SizedBox.shrink();
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
          final songs = state.historyEntries.isNotEmpty
              ? state.historyEntries.map((e) => e.song).toList()
              : state.recentlyPlayed;

          if (songs.isEmpty) {
            return const PrismEmptyState(
              icon: Icons.history_rounded,
              message: 'No recently played songs yet',
              hint: 'Tracks you listen to will automatically appear here.',
            );
          }

          final entries = state.historyEntries.isNotEmpty
              ? state.historyEntries
              : songs
                  .map((s) => HistoryEntry(song: s, playedAt: DateTime.now()))
                  .toList();

          final grouped = DateGrouping.groupByPeriod(entries, (e) => e.playedAt);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${Formatters.formatCount(songs.length, 'song')} in history',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonalIcon(
                            onPressed: () => _playAll(context, songs),
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Play all'),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton.filledTonal(
                            tooltip: 'Shuffle history',
                            onPressed: () => _playAll(context, songs, shuffle: true),
                            icon: const Icon(Icons.shuffle_rounded, size: 18),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Stored privately on your device. Cleared history does not affect lifetime play statistics.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (final group in grouped.entries) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                    child: Text(
                      group.key.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  sliver: SliverList.builder(
                    itemCount: group.value.length,
                    itemBuilder: (context, index) {
                      final entry = group.value[index];
                      final song = entry.song;
                      return BlocBuilder<PlayerBloc, PlayerState>(
                        builder: (context, playerState) => PrismSongTile(
                          song: song,
                          subtitle:
                              '${song.artist} • ${DateGrouping.formatRelativeTime(entry.playedAt)}',
                          isPlaying: playerState.currentSong?.id == song.id,
                          isPlayingPaused: !playerState.isPlaying,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                song.durationFormatted,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                tooltip: 'Remove from history',
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  context.read<LibraryBloc>().add(
                                    RemoveSongFromHistoryEvent(song.playableId),
                                  );
                                },
                              ),
                            ],
                          ),
                          onTap: () => context.read<PlayerBloc>().add(
                            PlaySongEvent(
                              song: song,
                              queue: songs,
                              queueIndex: songs.indexOf(song),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
              ),
            ],
          );
        },
      ),
    );
  }
}
