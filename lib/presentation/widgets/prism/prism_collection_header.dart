import 'package:flutter/material.dart';

import '../../theme/prism_theme.dart';
import 'prism_artwork.dart';

/// Unified collection header for collection surfaces (Liked Songs,
/// Recently Played, Playlists, Albums, Charts, Curated Mixes).
///
/// Provides a consistent, accessible hierarchy: artwork or hero icon,
/// collection badge, title, descriptive metadata chips, and prominent
/// Play/Shuffle controls.
class PrismCollectionHeader extends StatelessWidget {
  const PrismCollectionHeader({
    super.key,
    required this.title,
    this.badge,
    this.subtitle,
    this.artworkUrl,
    this.icon,
    this.iconColor,
    this.metadata,
    this.onPlayAll,
    this.onShuffle,
    this.isPlayActive = false,
    this.actions,
    this.headerBadge,
  });

  /// The collection title (e.g. 'Liked Songs', 'Top 50 USA', 'Album Name').
  final String title;

  /// Optional top badge category (e.g. 'COLLECTION', 'ALBUM', 'CHART').
  final String? badge;

  /// Descriptive subtitle or author.
  final String? subtitle;

  /// Artwork thumbnail URL.
  final String? artworkUrl;

  /// Icon used if [artworkUrl] is empty or null.
  final IconData? icon;

  /// Color used for the hero icon container.
  final Color? iconColor;

  /// Formatted metadata string (e.g. '50 songs · 2 hr 45 min').
  final String? metadata;

  /// Primary play-all callback.
  final VoidCallback? onPlayAll;

  /// Shuffle-play callback.
  final VoidCallback? onShuffle;

  /// Whether current playback matches this collection.
  final bool isPlayActive;

  /// Additional action buttons (e.g. Save, Sort, Reorder, Clear).
  final List<Widget>? actions;

  /// An optional alert or provenance banner (e.g. 'Curated Discovery Mix').
  final Widget? headerBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final spec = context.prismSpec;
    final isTablet = MediaQuery.sizeOf(context).width > 600;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroMedia(context, scheme, spec),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (badge != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: spec.accentSoft,
                          borderRadius: BorderRadius.circular(PrismRadius.xs),
                          border: Border.all(color: spec.hairline),
                        ),
                        child: Text(
                          badge!.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: (isTablet
                              ? theme.textTheme.headlineMedium
                              : theme.textTheme.titleLarge)
                          ?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (metadata != null && metadata!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        metadata!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (headerBadge != null) ...[
            const SizedBox(height: 14),
            headerBadge!,
          ],
          if (onPlayAll != null || onShuffle != null || (actions != null && actions!.isNotEmpty)) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (onPlayAll != null)
                  FilledButton.icon(
                    onPressed: onPlayAll,
                    icon: Icon(
                      isPlayActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 20,
                    ),
                    label: Text(isPlayActive ? 'Pause' : 'Play all'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                if (onShuffle != null)
                  IconButton.filledTonal(
                    onPressed: onShuffle,
                    tooltip: 'Shuffle collection',
                    icon: const Icon(Icons.shuffle_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.surfaceContainerHigh,
                    ),
                  ),
                if (actions != null) ...actions!,
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroMedia(
    BuildContext context,
    ColorScheme scheme,
    PrismSpec spec,
  ) {
    const double size = 80;

    if (artworkUrl != null && artworkUrl!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PrismRadius.md),
          border: Border.all(color: spec.hairline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: PrismArtwork(
          url: artworkUrl!,
          borderRadius: PrismRadius.md,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: iconColor ?? spec.accentSoft,
        borderRadius: BorderRadius.circular(PrismRadius.md),
        border: Border.all(color: spec.hairline),
      ),
      child: Center(
        child: Icon(
          icon ?? Icons.music_note_rounded,
          size: 38,
          color: iconColor != null ? Colors.white : scheme.primary,
        ),
      ),
    );
  }
}
