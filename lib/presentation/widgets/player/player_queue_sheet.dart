import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/player/player_bloc.dart';
import '../../blocs/player/player_event.dart';
import '../../blocs/player/player_state.dart';
import '../../theme/prism_theme.dart';
import '../prism/prism_artwork.dart';
import '../prism/prism_states.dart';

class PlayerQueueSheet extends StatelessWidget {
  const PlayerQueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerBloc, PlayerState>(
      builder: (context, state) {
        if (state.queue.isEmpty) {
          return const SizedBox(
            height: 260,
            child: PrismEmptyState(
              icon: Icons.queue_music_rounded,
              message: 'Queue is empty',
            ),
          );
        }

        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.62,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Up next',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<PlayerBloc>().add(const ClearQueueEvent());
                        Navigator.pop(context);
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: state.queue.length,
                  padding: const EdgeInsets.only(bottom: 24),
                  proxyDecorator: (child, index, animation) =>
                      AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) => Material(
                      elevation: 8,
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(PrismRadius.md),
                      child: child,
                    ),
                  ),
                  onReorder: (oldIndex, newIndex) {
                    if (oldIndex < newIndex) newIndex -= 1;
                    context.read<PlayerBloc>().add(
                      ReorderQueueEvent(
                        oldIndex: oldIndex,
                        newIndex: newIndex,
                      ),
                    );
                  },
                  itemBuilder: (context, index) {
                    final song = state.queue[index];
                    final isPlaying = index == state.queueIndex;

                    return ListTile(
                      key: ValueKey('${song.playableId}_$index'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 2,
                      ),
                      leading: SizedBox.square(
                        dimension: 46,
                        child: PrismArtwork(
                          url: song.thumbnailUrl,
                          borderRadius: PrismRadius.sm,
                        ),
                      ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isPlaying
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isPlaying
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      subtitle: Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isPlaying)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Icon(
                                Icons.graphic_eq_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              tooltip: 'Remove',
                              onPressed: () => context.read<PlayerBloc>().add(
                                RemoveFromQueueEvent(index),
                              ),
                            ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Icon(
                              Icons.drag_handle_rounded,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      onTap: isPlaying
                          ? null
                          : () {
                              Navigator.pop(context);
                              context.read<PlayerBloc>().add(
                                PlaySongEvent(
                                  song: song,
                                  queue: state.queue,
                                  queueIndex: index,
                                ),
                              );
                            },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
