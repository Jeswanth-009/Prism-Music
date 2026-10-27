
import 'package:flutter/material.dart';

import '../../theme/prism_theme.dart';

/// Overview listening stats card for the library tab.
class LibraryStatsCard extends StatelessWidget {
  const LibraryStatsCard({
    super.key,
    required this.totalPlays,
    required this.uniqueSongs,
    this.topArtist,
    this.mostPlayed,
    this.onTap,
  });

  final int totalPlays;
  final int uniqueSongs;
  final String? topArtist;
  final String? mostPlayed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        border: Border.all(color: context.prismSpec.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _stat(theme, 'Plays', '$totalPlays'),
              const SizedBox(width: 12),
              _stat(theme, 'Songs', '$uniqueSongs'),
            ],
          ),
          if (topArtist != null || mostPlayed != null) ...[
            const SizedBox(height: 14),
            Divider(color: context.prismSpec.hairline),
            const SizedBox(height: 10),
            if (mostPlayed != null)
              _row(
                theme,
                Icons.play_circle_outline_rounded,
                'Most played',
                mostPlayed!,
              ),
            if (topArtist != null) ...[
              const SizedBox(height: 8),
              _row(theme, Icons.person_outline_rounded, 'Top artist',
                  topArtist!),
            ],
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        child: card,
      ),
    );
  }

  Widget _stat(ThemeData theme, String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
                theme.colorScheme.surfaceContainerHigh.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(PrismRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _row(ThemeData theme, IconData icon, String label, String value) =>
      Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
}
