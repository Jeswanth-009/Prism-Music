import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/entities/song.dart';
import '../../../blocs/library/library_bloc.dart';
import '../../../blocs/library/library_event.dart';
import '../../../blocs/library/library_state.dart';
import '../../../blocs/player/player_bloc.dart';
import '../../../blocs/player/player_event.dart';
import '../../../blocs/player/player_state.dart';
import '../../prism/prism_artwork.dart';
import '../player_controls_section.dart';
import '../player_lyrics_sheet.dart';
import '../player_queue_sheet.dart';
import '../player_slider_widget.dart';

/// Classic framed player layout with retro 5-button transport controls.
class ClassicPlayerLayout extends StatelessWidget {
  final Song song;
  final PlayerState state;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;
  final void Function(String artistName) onArtistTap;
  final VoidCallback onProvenanceTap;

  const ClassicPlayerLayout({
    super.key,
    required this.song,
    required this.state,
    required this.showLyrics,
    required this.onToggleLyrics,
    required this.onArtistTap,
    required this.onProvenanceTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.sizeOf(context).width > 600;

    return Column(
      children: [
        Expanded(
          child: showLyrics
              ? PlayerLyricsView(
                  key: ValueKey('lyrics_${song.id}'),
                  song: song,
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? 480 : double.infinity,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 12),
                          // Classic framed album artwork
                          AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: PrismArtwork(
                                  url: song.thumbnailUrl,
                                  width: double.infinity,
                                  height: double.infinity,
                                  borderRadius: 0,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Track info with inline like button
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    GestureDetector(
                                      onTap: () => onArtistTap(song.artist),
                                      child: Text(
                                        song.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    if (song.album != null &&
                                        song.album!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        song.album!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              BlocBuilder<LibraryBloc, LibraryState>(
                                builder: (context, lib) {
                                  final isLiked = lib.isSongLiked(song.id);
                                  return IconButton(
                                    icon: Icon(
                                      isLiked
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_outline_rounded,
                                      color: isLiked
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    onPressed: () => context
                                        .read<LibraryBloc>()
                                        .add(ToggleLikeSongEvent(song)),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        // Classic Scrubber
        PlayerSliderWidget(state: state),
        const SizedBox(height: 12),
        // Classic 5-button transport bar
        ClassicTransportControls(state: state),
        const SizedBox(height: 12),
        // Classic bottom utilities: Diagnostics, Lyrics, Queue
        ClassicUtilityRow(
          song: song,
          state: state,
          showLyrics: showLyrics,
          onToggleLyrics: onToggleLyrics,
          onProvenanceTap: onProvenanceTap,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class ClassicTransportControls extends StatelessWidget {
  final PlayerState state;

  const ClassicTransportControls({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            tooltip: 'Shuffle',
            iconSize: 22,
            icon: Icon(
              Icons.shuffle_rounded,
              color: state.isShuffleEnabled
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
            onPressed: () =>
                context.read<PlayerBloc>().add(const ToggleShuffleEvent()),
          ),
          IconButton(
            tooltip: 'Previous',
            iconSize: 32,
            icon: const Icon(Icons.skip_previous_rounded),
            onPressed: state.canSkipPrevious
                ? () => context.read<PlayerBloc>().add(const PreviousEvent())
                : null,
          ),
          PlayerPlayPauseButton(state: state),
          IconButton(
            tooltip: 'Next',
            iconSize: 32,
            icon: const Icon(Icons.skip_next_rounded),
            onPressed: state.canSkipNext
                ? () => context.read<PlayerBloc>().add(const NextEvent())
                : null,
          ),
          IconButton(
            tooltip: switch (state.repeatMode) {
              RepeatMode.off => 'Repeat: Off',
              RepeatMode.all => 'Repeat: All',
              RepeatMode.one => 'Repeat: One',
            },
            iconSize: 22,
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
            onPressed: () =>
                context.read<PlayerBloc>().add(const CycleRepeatModeEvent()),
          ),
        ],
      ),
    );
  }
}

class ClassicUtilityRow extends StatelessWidget {
  final Song song;
  final PlayerState state;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;
  final VoidCallback onProvenanceTap;

  const ClassicUtilityRow({
    super.key,
    required this.song,
    required this.state,
    required this.showLyrics,
    required this.onToggleLyrics,
    required this.onProvenanceTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Audio Source & Diagnostics',
            icon: const Icon(Icons.info_outline_rounded, size: 20),
            onPressed: onProvenanceTap,
          ),
          IconButton(
            tooltip: 'Lyrics',
            icon: Icon(
              Icons.lyrics_outlined,
              size: 20,
              color: showLyrics ? scheme.primary : scheme.onSurfaceVariant,
            ),
            onPressed: onToggleLyrics,
          ),
          IconButton(
            tooltip: 'Queue',
            icon: const Icon(Icons.queue_music_rounded, size: 20),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => const PlayerQueueSheet(),
            ),
          ),
        ],
      ),
    );
  }
}
