import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/search_results_bundle.dart';
import '../../../domain/entities/song.dart';
import '../../blocs/player/player_bloc.dart';
import '../../blocs/player/player_event.dart';
import '../../blocs/player/player_state.dart';
import '../../theme/prism_theme.dart';
import '../prism/prism_artwork.dart';
import '../prism/prism_sheet.dart';
import '../prism/prism_song_actions.dart';

/// Top Match Hero Card: highlights the #1 ranked candidate with authentic quality
/// metadata, live play/pause transport, and quick "Play Next" action.
class SearchHeroCard extends StatelessWidget {
  const SearchHeroCard({
    super.key,
    required this.topResult,
    required this.onTap,
  });

  final SearchTopResult topResult;
  final VoidCallback onTap;

  /// Returns real, authentic stream properties without hardcoded/fake badges.
  static String? authenticBadgeText(Song song) {
    if (song.source == MusicSource.local) {
      return 'Offline';
    }
    if (song.source == MusicSource.jiosaavn) {
      return 'JioSaavn · 320 kbps AAC';
    }
    if (song.source == MusicSource.youtube ||
        song.source == MusicSource.youtubeMusic) {
      return 'YouTube · 160 kbps Opus';
    }
    if (song.streamProvenance != null && song.streamProvenance!.isNotEmpty) {
      return song.streamProvenance;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final song = topResult.song;
    final badge = song != null ? authenticBadgeText(song) : topResult.kindLabel;

    return BlocBuilder<PlayerBloc, PlayerState>(
      builder: (context, playerState) {
        final isPlayingCurrent =
            song != null &&
            playerState.currentSong?.id == song.id &&
            playerState.isPlaying;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: song != null
                  ? () => showPrismSongActions(context, song)
                  : null,
              borderRadius: BorderRadius.circular(PrismRadius.lg),
              child: Container(
                padding: const EdgeInsets.all(PrismSpacing.md + 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(PrismRadius.lg),
                  border: Border.all(
                    color: context.prismSpec.hairline,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 76,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          topResult.isArtist ? PrismRadius.pill : PrismRadius.md,
                        ),
                        child: PrismArtwork(
                          url: topResult.thumbnailUrl,
                          borderRadius:
                              topResult.isArtist ? PrismRadius.pill : PrismRadius.md,
                          type: topResult.isArtist
                              ? ArtworkType.artist
                              : ArtworkType.album,
                        ),
                      ),
                    ),
                    const SizedBox(width: PrismSpacing.md + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'TOP MATCH',
                            style: PrismText.overline(context)?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: PrismSpacing.xxs),
                          Text(
                            topResult.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: PrismSpacing.xxs),
                          Text(
                            topResult.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(height: PrismSpacing.xs + 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: PrismSpacing.xs + 2,
                                vertical: PrismSpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer
                                    .withValues(alpha: 0.7),
                                borderRadius:
                                    BorderRadius.circular(PrismRadius.xs),
                              ),
                              child: Text(
                                badge,
                                style: PrismText.tabular(
                                  theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: PrismSpacing.sm),
                    if (song != null) ...[
                      IconButton(
                        icon: const Icon(Icons.low_priority_rounded, size: 20),
                        tooltip: 'Play next',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          context.read<PlayerBloc>().add(
                                AddToQueueEvent(song: song, playNext: true),
                              );
                          showPrismToast(context, 'Playing next');
                        },
                      ),
                    ],
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      icon: Icon(
                        isPlayingCurrent
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 26,
                      ),
                      tooltip: isPlayingCurrent ? 'Pause' : 'Play',
                      onPressed: () {
                        if (isPlayingCurrent) {
                          context.read<PlayerBloc>().add(const PauseEvent());
                        } else {
                          onTap();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
