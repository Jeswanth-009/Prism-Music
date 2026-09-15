import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/player/player.dart';
import '../../pages/player_page.dart';
import '../../theme/prism_theme.dart';
import '../prism/prism_artwork.dart';

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
              height: 68,
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
                  children: [
                    LinearProgressIndicator(
                      minHeight: 2,
                      value: progress,
                      color: scheme.primary,
                      backgroundColor: Colors.transparent,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 6, 0),
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
                                  Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.2,
                                        ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            _MiniAction(
                              label: state.isPlaying ? 'Pause' : 'Play',
                              icon: state.isBuffering
                                  ? null
                                  : state.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                              onPressed: () => context.read<PlayerBloc>().add(
                                state.isPlaying
                                    ? const PauseEvent()
                                    : const ResumeEvent(),
                              ),
                            ),
                            _MiniAction(
                              label: 'Next',
                              icon: Icons.skip_next_rounded,
                              onPressed: state.hasNext
                                  ? () => context
                                      .read<PlayerBloc>()
                                      .add(const NextEvent())
                                  : null,
                            ),
                          ],
                        ),
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
        onPressed: onPressed,
        style: IconButton.styleFrom(
          fixedSize: const Size(44, 44),
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
