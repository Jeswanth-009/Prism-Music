import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/player/player.dart';
import '../../pages/player_page.dart';
import '../../theme/prism_theme.dart';

/// Prism's persistent playback surface. It is intentionally the only frosted
/// surface in the main shell so it reads as a distinct, always-available tool.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  void _openPlayer(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) => const PlayerPage(),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 0.08), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: FadeTransition(opacity: animation, child: child),
        ),
        transitionDuration: const Duration(milliseconds: 320),
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
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Material(
                  color: scheme.surfaceContainer.withValues(alpha: 0.92),
                  child: InkWell(
                    onTap: () => _openPlayer(context),
                    child: Container(
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: scheme.outlineVariant),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                            child: LinearProgressIndicator(
                              minHeight: 2,
                              value: progress,
                              color: PrismColors.cyan,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                              child: Row(
                                children: [
                                  Hero(
                                    tag:
                                        'album_art_${song.youtubeId ?? song.id}',
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox.square(
                                        dimension: 54,
                                        child: song.thumbnailUrl.isEmpty
                                            ? _ArtworkFallback(
                                                color: scheme.primary,
                                              )
                                            : CachedNetworkImage(
                                                imageUrl: song.thumbnailUrl,
                                                fit: BoxFit.cover,
                                                placeholder: (_, __) =>
                                                    _ArtworkFallback(
                                                      color: scheme.primary,
                                                    ),
                                                errorWidget: (_, __, ___) =>
                                                    _ArtworkFallback(
                                                      color: scheme.primary,
                                                    ),
                                              ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -0.25,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
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
                                  _PlayerAction(
                                    label: state.isPlaying ? 'Pause' : 'Play',
                                    icon: state.isBuffering
                                        ? null
                                        : state.isPlaying
                                        ? LucideIcons.pause
                                        : LucideIcons.play,
                                    primary: true,
                                    onPressed: () =>
                                        context.read<PlayerBloc>().add(
                                          state.isPlaying
                                              ? const PauseEvent()
                                              : const ResumeEvent(),
                                        ),
                                  ),
                                  _PlayerAction(
                                    label: 'Next',
                                    icon: LucideIcons.skipForward,
                                    onPressed: state.hasNext
                                        ? () => context.read<PlayerBloc>().add(
                                            const NextEvent(),
                                          )
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
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlayerAction extends StatelessWidget {
  const _PlayerAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          fixedSize: const Size(42, 42),
          backgroundColor: primary ? scheme.primary : Colors.transparent,
          foregroundColor: primary ? scheme.onPrimary : scheme.onSurface,
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.25),
        ),
        icon: icon == null
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primary ? scheme.onPrimary : scheme.primary,
                ),
              )
            : Icon(icon, size: 20),
      ),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.32),
            PrismColors.coral.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: Icon(LucideIcons.music2, color: color, size: 24),
    );
  }
}
