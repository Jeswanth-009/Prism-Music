import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/playlist.dart';
import '../blocs/library/library.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../blocs/player/player_state.dart';
import '../theme/prism_theme.dart';
import '../widgets/prism/prism_artwork.dart';
import '../widgets/prism/prism_sheet.dart';
import '../widgets/prism/prism_song_tile.dart';
import '../widgets/prism/prism_states.dart';
import '../widgets/common/bouncing_tap_widget.dart';

class PlaylistDetailPage extends StatelessWidget {
  const PlaylistDetailPage({super.key, required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    // Follow the bloc so removals and re-imports are reflected live —
    // the widget argument is only the entry snapshot.
    return BlocBuilder<LibraryBloc, LibraryState>(
      builder: (context, libraryState) {
        final current = libraryState.playlists
                .where((p) => p.id == playlist.id)
                .firstOrNull ??
            playlist;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          body: _PlaylistBody(playlist: current),
        );
      },
    );
  }
}

class _PlaylistBody extends StatelessWidget {
  const _PlaylistBody({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final songs = playlist.songs ?? const [];
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
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
                            '${songs.length} songs'
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
                if (songs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _play(context, 0),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play all'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        tooltip: 'Shuffle play',
                        onPressed: () {
                          final shuffled = [...songs]..shuffle();
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
              ],
            ),
          ),
        ),
        if (songs.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: PrismEmptyState(
              icon: Icons.queue_music_rounded,
              message: 'This playlist has no available songs yet.',
            ),
          )
        else
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
                    onTap: () => _play(context, index),
                    // Songs can only be removed from playlists the user
                    // owns (or imported) — remote playlists are read-only.
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

  void _play(BuildContext context, int index) {
    context.read<PlayerBloc>().add(
      PlaySongEvent(
        song: (playlist.songs ?? const [])[index],
        queue: playlist.songs ?? const [],
        queueIndex: index,
      ),
    );
  }
}

/// Quiet remove affordance for a song inside a user playlist.
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
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.close_rounded,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
