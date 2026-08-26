import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'dart:ui';

import '../../blocs/player/player_bloc.dart';
import '../../blocs/player/player_event.dart';
import '../../blocs/player/player_state.dart';

class PlayerQueueSheet extends StatelessWidget {
  const PlayerQueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerBloc, PlayerState>(
      builder: (context, state) {
        if (state.queue.isEmpty) {
          return const ShadSheet(
            title: Text('Queue'),
            child: SizedBox(
              height: 200,
              child: Center(
                child: Text('Queue is empty'),
              ),
            ),
          );
        }

        return ShadSheet(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Up Next',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  ShadButton.ghost(
                    onPressed: () {
                      context.read<PlayerBloc>().add(const ClearQueueEvent());
                      Navigator.pop(context);
                    },
                    size: ShadButtonSize.sm,
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ],
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: ReorderableListView.builder(
              itemCount: state.queue.length,
              proxyDecorator: (Widget child, int index, Animation<double> animation) {
                return Material(
                  elevation: 12,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                          ),
                        ),
                        child: child,
                      ),
                    ),
                  ),
                );
              },
              onReorder: (int oldIndex, int newIndex) {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
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

                return Padding(
                  key: ValueKey('${song.playableId}_$index'),
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isPlaying 
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: isPlaying
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                              width: 1,
                            )
                          : Border.all(color: Colors.transparent, width: 1),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: song.thumbnailUrl.isNotEmpty
                              ? Image.network(
                                  song.thumbnailUrl,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: const Icon(LucideIcons.music),
                                ),
                        ),
                      ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                          color: isPlaying ? Theme.of(context).colorScheme.primary : null,
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
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Icon(
                                LucideIcons.audioLines,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                            )
                          else
                            ShadIconButton.ghost(
                              icon: const Icon(LucideIcons.x, size: 18),
                              width: 36,
                              height: 36,
                              onPressed: () {
                                context.read<PlayerBloc>().add(
                                      RemoveFromQueueEvent(index),
                                    );
                              },
                            ),
                          const SizedBox(width: 4),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Icon(
                              LucideIcons.gripVertical,
                              size: 20,
                              color: Colors.grey,
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
                    ),
                  ),
                ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
