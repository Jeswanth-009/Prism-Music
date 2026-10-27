import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/song.dart';
import '../../blocs/library/library_bloc.dart';
import '../../blocs/library/library_event.dart';
import '../../blocs/library/library_state.dart';
import '../../blocs/player/player_bloc.dart';
import '../../blocs/player/player_event.dart';
import '../../blocs/player/player_state.dart';
import 'player_queue_sheet.dart';

/// Secondary action bar for shuffle, repeat, favorite/like, lyrics, and queue.
class PlayerActionBar extends StatelessWidget {
  const PlayerActionBar({
    super.key,
    required this.song,
    required this.state,
    required this.showLyrics,
    required this.onToggleLyrics,
  });

  final Song song;
  final PlayerState state;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return BlocBuilder<LibraryBloc, LibraryState>(
      buildWhen: (prev, curr) =>
          prev.isSongLiked(song.id) != curr.isSongLiked(song.id),
      builder: (context, library) {
        final isLiked = library.isSongLiked(song.id);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: 'Shuffle',
                onPressed: () =>
                    context.read<PlayerBloc>().add(const ToggleShuffleEvent()),
                icon: Icon(
                  Icons.shuffle_rounded,
                  color: state.isShuffleEnabled
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
              IconButton(
                tooltip: switch (state.repeatMode) {
                  RepeatMode.off => 'Repeat: Off',
                  RepeatMode.all => 'Repeat: All',
                  RepeatMode.one => 'Repeat: One',
                },
                onPressed: () {
                  context.read<PlayerBloc>().add(
                        const CycleRepeatModeEvent(),
                      );
                  final nextMode = switch (state.repeatMode) {
                    RepeatMode.off => 'Repeat All',
                    RepeatMode.all => 'Repeat One',
                    RepeatMode.one => 'Repeat Off',
                  };
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(nextMode),
                      duration: const Duration(milliseconds: 900),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: Icon(
                  switch (state.repeatMode) {
                    RepeatMode.one => Icons.repeat_one_rounded,
                    RepeatMode.all => Icons.repeat_rounded,
                    RepeatMode.off => Icons.repeat_rounded,
                  },
                  color: state.repeatMode != RepeatMode.off
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
              IconButton(
                tooltip: isLiked ? 'Unlike' : 'Like',
                onPressed: () =>
                    context.read<LibraryBloc>().add(ToggleLikeSongEvent(song)),
                icon: Icon(
                  isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_outline_rounded,
                  color: isLiked ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              IconButton(
                tooltip: 'Lyrics',
                onPressed: onToggleLyrics,
                icon: Icon(
                  Icons.lyrics_outlined,
                  color: showLyrics ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              IconButton(
                tooltip: 'Queue',
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const PlayerQueueSheet(),
                ),
                icon: Icon(
                  Icons.queue_music_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
