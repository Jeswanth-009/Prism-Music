import 'package:flutter/material.dart';

import '../../../core/error/error_message_mapper.dart';
import '../../theme/prism_theme.dart';

/// A shared playback and streaming error banner that displays user-friendly
/// mapped error messages with retry capability and accessible semantics.
class PrismStreamingErrorBanner extends StatelessWidget {
  const PrismStreamingErrorBanner({
    super.key,
    required this.errorMessage,
    this.onRetry,
    this.onDismiss,
    this.margin = const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
  });

  /// The raw or mapped error message string.
  final String errorMessage;

  /// Optional retry callback invoked when the user taps "Retry".
  final VoidCallback? onRetry;

  /// Optional dismiss callback.
  final VoidCallback? onDismiss;

  /// Layout margin.
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayMessage = ErrorMessageMapper.map(errorMessage);

    return Semantics(
      liveRegion: true,
      label: 'Streaming error: $displayMessage',
      child: Container(
        margin: margin,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(PrismRadius.md),
          border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: theme.colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                displayMessage,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            if (onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Dismiss error',
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}
