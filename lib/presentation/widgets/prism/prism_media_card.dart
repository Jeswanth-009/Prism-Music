import 'package:flutter/material.dart';

import '../../theme/prism_theme.dart';
import '../common/bouncing_tap_widget.dart';
import 'prism_artwork.dart';

/// Square artwork card for horizontal rails (new releases, artists, albums).
class PrismMediaCard extends StatelessWidget {
  const PrismMediaCard({
    super.key,
    required this.url,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.width = 140,
    this.circle = false,
  });

  final String url;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final double width;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: BouncingTapWidget(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: circle
                  ? ClipOval(
                      child: PrismArtwork(url: url, fit: BoxFit.cover),
                    )
                  : PrismArtwork(
                      url: url,
                      borderRadius: PrismRadius.lg,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
