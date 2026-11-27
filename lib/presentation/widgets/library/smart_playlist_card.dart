import 'package:flutter/material.dart';

import '../../../core/services/smart_playlist_service.dart';
import '../../pages/smart_playlist_page.dart';
import '../../theme/prism_theme.dart';

/// Card tile representing a computed dynamic smart playlist.
///
/// The playlist's hue tints a quiet card — loud gradient fills pulled the
/// whole rail off-palette; the hue still identifies the mix.
class SmartPlaylistCard extends StatelessWidget {
  final SmartPlaylist smartPlaylist;

  const SmartPlaylistCard({super.key, required this.smartPlaylist});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = context.prismSpec;
    final hue = smartPlaylist.gradientColors.first;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SmartPlaylistPage(smartPlaylist: smartPlaylist),
          ),
        );
      },
      borderRadius: BorderRadius.circular(PrismRadius.lg),
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            hue.withValues(alpha: 0.14),
            theme.colorScheme.surfaceContainer,
          ),
          borderRadius: BorderRadius.circular(PrismRadius.lg),
          border: Border.all(color: spec.hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(PrismSpacing.md + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(PrismSpacing.sm),
                    decoration: BoxDecoration(
                      color: hue.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      smartPlaylist.icon,
                      color: hue,
                      size: PrismIconSize.md,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PrismSpacing.sm,
                      vertical: PrismSpacing.xxs + 1,
                    ),
                    decoration: BoxDecoration(
                      color: hue.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(PrismRadius.xs),
                    ),
                    child: Text(
                      '${smartPlaylist.trackCount}',
                      style: PrismText.tabular(
                        theme.textTheme.labelSmall?.copyWith(color: hue),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PrismSpacing.lg),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    smartPlaylist.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: PrismSpacing.xxs),
                  Text(
                    smartPlaylist.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
