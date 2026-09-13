import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../blocs/library/library_bloc.dart';
import '../blocs/library/library_state.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../theme/prism_theme.dart';
import '../widgets/cards/song_card.dart';

class LikedSongsPage extends StatelessWidget {
  const LikedSongsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.chevronLeft),
        ),
        title: const Text('Liked Songs'),
      ),
      body: BlocBuilder<LibraryBloc, LibraryState>(
        builder: (context, state) {
          final songs = state.likedSongs;
          if (songs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        LucideIcons.heart,
                        color: theme.colorScheme.primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Songs you love live here',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the heart while listening and Prism will keep it in your private library.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const PrismSpectrumLine(),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: songs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final song = songs[index];
              return SongCard(
                song: song,
                compact: true,
                onTap: () => context.read<PlayerBloc>().add(
                  PlaySongEvent(song: song, queue: songs, queueIndex: index),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
