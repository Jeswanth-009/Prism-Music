import 'package:flutter/material.dart';

import '../../theme/prism_theme.dart';

/// Compact quick-access tile (Liked, Downloads, History…). Flat card with an
/// icon and a count — no gradients, artwork stays the hero of the page.
class PrismQuickTile extends StatelessWidget {
  const PrismQuickTile({
    super.key,
    required this.icon,
    required this.label,
    required this.meta,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        side: BorderSide(color: context.prismSpec.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 24, color: theme.colorScheme.primary),
              const Spacer(),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
