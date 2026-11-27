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
    this.showOverflowAction = true,
    this.isDownloaded = false,
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
  final bool showOverflowAction;
  final bool isDownloaded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final spec = context.prismSpec;
    final accent = isPlaying ? spec.accent : null;

    return Semantics(
      button: true,
      selected: isPlaying,
      label: '${song.title} by ${song.artist}',
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress ?? () => showPrismSongActions(context, song),
        borderRadius: BorderRadius.circular(PrismRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PrismSpacing.md,
            vertical: PrismSpacing.sm,
          ),
          child: Row(
            children: [
              if (numbered && index != null) ...[
                SizedBox(
                  width: 26,
                  child: Text(
                    '${index! + 1}',
                    style: PrismText.tabular(
                      theme.textTheme.labelLarge?.copyWith(
                        color: accent ?? scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: PrismSpacing.md),
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
                            color: spec.scrim,
                            borderRadius: BorderRadius.circular(PrismRadius.sm),
                          ),
                          child: Center(
                            child: _PlayingBars(
                              color: PrismColors.onColor(spec.scrim),
                              paused: isPlayingPaused,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: PrismSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          theme.textTheme.titleSmall?.copyWith(color: accent),
                    ),
                    const SizedBox(height: PrismSpacing.xxs),
                    Row(
                      children: [
                        if (isDownloaded) ...[
                          Icon(
                            Icons.download_done_rounded,
                            size: PrismIconSize.xs,
                            color: spec.success,
                          ),
                          const SizedBox(width: PrismSpacing.xs),
                        ],
                        Expanded(
                          child: Text(
                            subtitle ?? song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: PrismSpacing.sm),
              if (trailing != null)
                trailing!
              else ...[
                Text(
                  song.durationFormatted,
                  style: PrismText.tabular(
                    theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (showOverflowAction) ...[
                  const SizedBox(width: PrismSpacing.xs),
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      size: PrismIconSize.md,
                    ),
                    tooltip: 'More options for ${song.title}',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                    visualDensity: VisualDensity.standard,
                    onPressed: () => showPrismSongActions(context, song),
                  ),
                ],
              ],
            ],
          ),
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // First start lives here: _update() reads MediaQuery through context,
    // which initState may not.
    _update();
  }

  @override
  void didUpdateWidget(covariant _PlayingBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  void _update() {
    if (widget.paused || PrismMotion.isReducedMotion(context)) {
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
