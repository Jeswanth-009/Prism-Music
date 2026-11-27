import 'package:flutter/material.dart';

import '../../theme/prism_theme.dart';

/// Unified empty state.
class PrismEmptyState extends StatelessWidget {
  const PrismEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String message;
  final String? hint;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PrismSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The icon sits in a quiet ring, sized to the role it plays:
            // a placeholder glyph, not a shout.
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.prismSpec.hairline),
                color: theme.colorScheme.surfaceContainer.withValues(
                  alpha: 0.5,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: PrismIconSize.xl,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: .55),
              ),
            ),
            SizedBox(
              height: compact ? PrismSpacing.md : PrismSpacing.lg,
            ),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (hint != null) ...[
              const SizedBox(height: PrismSpacing.xs + 2),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: PrismSpacing.lg + 2),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Unified error state with retry.
class PrismErrorState extends StatelessWidget {
  const PrismErrorState({
    super.key,
    this.title,
    this.message,
    required this.onRetry,
  });

  final String? title;
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PrismSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.prismSpec.hairline),
                color: theme.colorScheme.surfaceContainer.withValues(
                  alpha: 0.5,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.cloud_off_rounded,
                size: PrismIconSize.xl,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: .55),
              ),
            ),
            const SizedBox(height: PrismSpacing.lg),
            Text(
              title ?? 'Could not load music',
              style: theme.textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: PrismSpacing.xs + 2),
              Text(
                message!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: PrismSpacing.lg + 2),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
