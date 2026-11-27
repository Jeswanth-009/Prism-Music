import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/daily_mix_service.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../blocs/player/player_state.dart';
import '../theme/prism_theme.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/prism/prism_daily_mix_card.dart';
import '../widgets/prism/prism_song_tile.dart';

/// Dedicated page showing an on-device Daily Mix with tracklist and transport controls
class DailyMixPage extends StatelessWidget {
  final DailyMix mix;

  const DailyMixPage({super.key, required this.mix});

  void _play(BuildContext context, int index) {
    context.read<PlayerBloc>().add(
          PlaySongEvent(song: mix.songs[index], queue: mix.songs, queueIndex: index),
        );
  }

  void _playShuffled(BuildContext context) {
    if (mix.songs.isEmpty) return;
    final shuffled = [...mix.songs]..shuffle();
    context.read<PlayerBloc>().add(
          PlaySongEvent(song: shuffled.first, queue: shuffled, queueIndex: 0),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      bottomNavigationBar: const PrismPersistentMiniPlayer(),
      appBar: AppBar(
        title: Text(mix.title),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(PrismRadius.lg),
                  border: Border.all(
                    color: mix.primaryAccent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(PrismRadius.md),
                            child: PrismDailyMixCard(
                              mix: mix,
                              onTap: () {},
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Made on your phone from what you play',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: mix.primaryAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mix.title,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${mix.songs.length} songs',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      mix.subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: mix.primaryAccent,
                              foregroundColor:
                                  PrismColors.onColor(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            onPressed: mix.songs.isEmpty ? null : () => _play(context, 0),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Play all'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filledTonal(
                          tooltip: 'Shuffle Play',
                          onPressed: mix.songs.isEmpty ? null : () => _playShuffled(context),
                          icon: const Icon(Icons.shuffle_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
            sliver: SliverList.builder(
              itemCount: mix.songs.length,
              itemBuilder: (context, index) {
                final song = mix.songs[index];
                return BlocBuilder<PlayerBloc, PlayerState>(
                  buildWhen: (prev, curr) =>
                      (prev.currentSong?.id == song.id) !=
                          (curr.currentSong?.id == song.id) ||
                      (prev.isPlaying != curr.isPlaying &&
                          curr.currentSong?.id == song.id),
                  builder: (context, playerState) {
                    return PrismSongTile(
                      song: song,
                      numbered: true,
                      index: index + 1,
                      showOverflowAction: true,
                      isPlaying: playerState.currentSong?.id == song.id,
                      isPlayingPaused: !playerState.isPlaying,
                      onTap: () => _play(context, index),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
