import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/entities/song.dart';
import '../../theme/prism_theme.dart';
import 'prism_artwork.dart';
import 'prism_song_actions.dart';

/// The standard song row used in every list across the app.
///
/// Long-press opens the shared song actions sheet (play next, queue,
/// playlists, like, download, share) unless [onLongPress] is provided.
class PrismSongTile extends StatelessWidget {
  const PrismSongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.index,
    this.subtitle,
    this.trailing,
    this.isPlaying = false,
    this.isPlayingPaused = false,
    this.artSize = 48,
    this.onLongPress,
    this.numbered = false,
  });

  final Song song;
  final VoidCallback onTap;
  final int? index;
  final String? subtitle;
  final Widget? trailing;
  final bool isPlaying;
  final bool isPlayingPaused;
  final double artSize;
  final VoidCallback? onLongPress;
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = context.prismSpec;
    final accent = isPlaying ? spec.accent : null;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress ?? () => showPrismSongActions(context, song),
      borderRadius: BorderRadius.circular(PrismRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (numbered && index != null) ...[
              SizedBox(
                width: 26,
                child: Text(
                  '${index! + 1}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: accent ??
                        theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: .8,
                        ),
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            SizedBox.square(
              dimension: artSize,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PrismArtwork(
                    url: song.thumbnailUrl,
                    borderRadius: PrismRadius.sm,
                  ),
                  if (isPlaying)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .45),
                          borderRadius: BorderRadius.circular(PrismRadius.sm),
                        ),
                        child: Center(
                          child: _PlayingBars(
                            color: Colors.white,
                            paused: isPlayingPaused,
                          ),
                        ),
                      ),
                    ),
                ],
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
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle ?? song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Text(
                  song.durationFormatted,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Three animated bars shown over the artwork of the current song.
class _PlayingBars extends StatefulWidget {
  const _PlayingBars({required this.color, required this.paused});

  final Color color;
  final bool paused;

  @override
  State<_PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<_PlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void didUpdateWidget(covariant _PlayingBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  void _update() {
    if (widget.paused) {
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 * 3.1415927;
        final heights = List.generate(3, (i) {
          final phase = t - i * 0.9;
          return 6 + (7 * (0.5 + 0.5 * math.sin(phase))).abs();
        });
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final h in heights)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Container(
                  width: 3,
                  height: h,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
