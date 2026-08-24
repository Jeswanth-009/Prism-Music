import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../domain/entities/entities.dart';
import '../blocs/library/library.dart';
import '../blocs/player/player.dart';
import '../widgets/common/bouncing_tap_widget.dart';

/// Full, scrollable view of the listening history. Tapping a song plays it.
class RecentlyPlayedPage extends StatelessWidget {
  const RecentlyPlayedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recently played'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: shadTheme.colorScheme.foreground,
        elevation: 0,
      ),
      body: BlocBuilder<LibraryBloc, LibraryState>(
        builder: (context, state) {
          final songs = state.recentlyPlayed;

          if (songs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.history,
                    size: 48,
                    color: shadTheme.colorScheme.mutedForeground,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No recently played songs yet',
                    style: TextStyle(
                      color: shadTheme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: songs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final song = songs[index];
              return _HistoryTile(
                song: song,
                onTap: () => context.read<PlayerBloc>().add(
                  PlaySongEvent(
                    song: song,
                    queue: songs,
                    queueIndex: index,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _HistoryTile({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);

    return BouncingTapWidget(
      onTap: onTap,
      scaleFactor: 0.96,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: song.thumbnailUrl.isNotEmpty
                    ? Image.network(
                        song.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallback(shadTheme),
                      )
                    : _fallback(shadTheme),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: shadTheme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              song.durationFormatted,
              style: TextStyle(
                fontSize: 12,
                color: shadTheme.colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(ShadThemeData shadTheme) {
    return Container(
      color: shadTheme.colorScheme.muted,
      child: Icon(
        LucideIcons.music,
        size: 22,
        color: shadTheme.colorScheme.mutedForeground,
      ),
    );
  }
}
