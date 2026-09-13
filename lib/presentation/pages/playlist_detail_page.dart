import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../domain/entities/playlist.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../theme/prism_theme.dart';
import '../widgets/cards/song_card.dart';

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
          icon: const Icon(LucideIcons.chevronLeft),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Row(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      gradient: PrismColors.spectrum,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      LucideIcons.listMusic,
                      color: PrismColors.ink,
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
                            fontWeight: FontWeight.w800,
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
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'This playlist has no available songs yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList.separated(
                itemCount: songs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final song = songs[index];
                  return SongCard(
                    song: song,
                    compact: true,
                    onTap: () => context.read<PlayerBloc>().add(
                      PlaySongEvent(
                        song: song,
                        queue: songs,
                        queueIndex: index,
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
