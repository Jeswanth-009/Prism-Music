import 'package:flutter/material.dart';

import '../../theme/prism_theme.dart';

/// Section title with an optional trailing action.
///
/// The one header pattern for every horizontal rail and list section:
/// titleLarge at default weight, a quiet "See all" text action, and the
/// page gutter as padding.
class PrismSectionHeader extends StatelessWidget {
  const PrismSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(
      PrismSpacing.gutter,
      26,
      PrismSpacing.gutter,
      12,
    ),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge,
            ),
          ),
          if (actionLabel != null)
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
