import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/error_message_mapper.dart';
import '../../blocs/player/player.dart';
import '../../pages/player_page.dart';
import '../../theme/prism_theme.dart';
import '../prism/prism_artwork.dart';
import 'crossfade_visualizer_badge.dart';

/// Persistent compact player above the navigation pill. Tap opens the
/// full player.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  void _openPlayer(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) => const PlayerPage(),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: PrismMotion.curve),
              ),
          child: FadeTransition(opacity: animation, child: child),
        ),
        transitionDuration: PrismMotion.slow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return BlocBuilder<PlayerBloc, PlayerState>(
      builder: (context, state) {
        final song = state.currentSong;
        if (song == null) return const SizedBox.shrink();

        final progress = state.duration.inMilliseconds > 0
            ? (state.position.inMilliseconds / state.duration.inMilliseconds)
                  .clamp(0.0, 1.0)
            : 0.0;

        return Semantics(
          button: true,
          label: 'Open player for ${song.title}',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              constraints: const BoxConstraints(minHeight: 68),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(PrismRadius.lg),
                border: Border.all(color: context.prismSpec.hairline),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () => _openPlayer(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      minHeight: 2,
                      value: progress,
                      color: scheme.primary,
                      backgroundColor: Colors.transparent,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                      child: Row(
                          children: [
                            Hero(
                              tag:
                                  'album_art_${song.youtubeId ?? song.id}',
                              child: SizedBox.square(
                                dimension: 48,
                                child: PrismArtwork(
                                  url: song.thumbnailUrl,
                                  borderRadius: PrismRadius.sm,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          song.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleMedium,
                                        ),
                                      ),
                                      if (state.repeatMode != RepeatMode.off ||
                                          state.isShuffleEnabled) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: scheme.primaryContainer
                                                .withValues(alpha: 0.7),
                                            borderRadius:
                                                BorderRadius.circular(PrismRadius.xs),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (state.isShuffleEnabled) ...[
                                                Icon(
                                                  Icons.shuffle_rounded,
                                                  size: PrismIconSize.xs,
                                                  color: scheme
                                                      .onPrimaryContainer,
                                                ),
                                                if (state.repeatMode !=
                                                    RepeatMode.off)
                                                  const SizedBox(width: 2),
                                              ],
                                              if (state.repeatMode ==
                                                  RepeatMode.one)
                                                Icon(
                                                  Icons.repeat_one_rounded,
                                                  size: PrismIconSize.xs,
                                                  color: scheme
                                                      .onPrimaryContainer,
                                                )
                                              else if (state.repeatMode ==
                                                  RepeatMode.all)
                                                Icon(
                                                  Icons.repeat_rounded,
                                                  size: PrismIconSize.xs,
                                                  color: scheme
                                                      .onPrimaryContainer,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 1),
                                  if (state.status == PlayerStatus.error)
                                    Text(
                                      state.errorMessage != null
                                          ? ErrorMessageMapper.map(state.errorMessage!)
                                          : 'Playback error · Tap to retry',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.error,
                                      ),
                                    )
                                  else if (state.status == PlayerStatus.completed)
                                    Text(
                                      'Queue finished · Tap to replay',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.primary,
                                      ),
                                    )
                                  else if (state.isLoading &&
                                      state.loadingStage != PlayerLoadingStage.none)
                                    Row(
                                      children: [
                                        SizedBox.square(
                                          dimension: 10,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: scheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            state.loadingStage.displayLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: scheme.primary,
                                                ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            song.artist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: scheme.onSurfaceVariant,
                                                ),
                                          ),
                                        ),
                                        if (state.isCrossfading) ...[
                                          const SizedBox(width: 4),
                                          const CrossfadeVisualizerBadge(
                                            isCrossfading: true,
                                            compact: true,
                                          ),
                                        ] else if (state.currentStreamInfo != null) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '· ${state.streamProvenanceLabel}',
                                            style: PrismText.tabular(
                                              theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                color: scheme.primary,
                                              )),
                                          ),
                                        ],
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            _MiniAction(
                              label: state.status == PlayerStatus.error
                                  ? 'Retry'
                                  : (state.status == PlayerStatus.completed
                                      ? 'Replay'
                                      : (state.isPlaying ? 'Pause' : 'Play')),
                              icon: state.isBuffering
                                  ? null
                                  : state.status == PlayerStatus.error
                                      ? Icons.refresh_rounded
                                      : (state.status == PlayerStatus.completed
                                          ? Icons.replay_rounded
                                          : (state.isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded)),
                              onPressed: () {
                                if (state.status == PlayerStatus.completed) {
                                  final replaySong = state.queue.isNotEmpty
                                      ? state.queue.first
                                      : state.currentSong;
                                  if (replaySong != null) {
                                    context.read<PlayerBloc>().add(
                                          PlaySongEvent(
                                            song: replaySong,
                                            queue: state.queue,
                                            queueIndex: 0,
                                          ),
                                        );
                                  }
                                } else {
                                  context.read<PlayerBloc>().add(
                                        state.isPlaying
                                            ? const PauseEvent()
                                            : const ResumeEvent(),
                                      );
                                }
                              },
                            ),
                            _MiniAction(
                              label: 'Next',
                              icon: Icons.skip_next_rounded,
                              onPressed: state.canSkipNext
                                  ? () => context
                                      .read<PlayerBloc>()
                                      .add(const NextEvent())
                                  : null,
                            ),
                          ],
                        ),
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

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
          foregroundColor: scheme.onSurface,
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.25),
        ),
        icon: icon == null
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              )
            : Icon(icon, size: 22),
      ),
    );
  }
}

/// Persistent mini player wrapper for subpage and collection routes.
/// Renders the mini player with safe area padding when a song is active,
/// and collapses smoothly when inactive.
class PrismPersistentMiniPlayer extends StatelessWidget {
  const PrismPersistentMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerBloc, PlayerState>(
      builder: (context, state) {
        if (state.currentSong == null) return const SizedBox.shrink();
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: const MiniPlayer(),
          ),
        );
      },
    );
  }
}

