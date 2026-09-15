import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/playlist.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../blocs/player/player_state.dart';
import '../theme/prism_theme.dart';
import '../widgets/prism/prism_song_tile.dart';
import '../widgets/prism/prism_states.dart';

class PlaylistDetailPage extends StatelessWidget {
  const PlaylistDetailPage({super.key, required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final songs = playlist.songs ?? const [];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: context.prismSpec.accentSoft,
                      borderRadius: BorderRadius.circular(PrismRadius.lg),
                    ),
                    child: Icon(
                      Icons.queue_music_rounded,
                      color: theme.colorScheme.primary,
                      size: 36,
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
                        const SizedBox(height: 6),
                        Text(
                          '${songs.length} songs${playlist.totalDurationFormatted.isEmpty ? '' : ' · ${playlist.totalDurationFormatted}'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
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
      ),
    );
  }
}
