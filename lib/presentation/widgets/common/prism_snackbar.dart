import 'package:flutter/material.dart';

import '../../../core/error/error_message_mapper.dart';
import '../../theme/prism_theme.dart';

/// Shows an elevated, themed error SnackBar with a user-friendly message
/// and an optional interactive retry action.
void showPrismErrorSnackBar(
  BuildContext context, {
  required dynamic error,
  String? customMessage,
  VoidCallback? onRetry,
  String retryLabel = 'Retry',
  Duration duration = const Duration(seconds: 4),
}) {
  final message = customMessage ?? ErrorMessageMapper.map(error);
  final theme = Theme.of(context);

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: theme.colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            theme.colorScheme.errorContainer.withValues(alpha: 0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PrismRadius.md),
          side: BorderSide(
            color: theme.colorScheme.error.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        duration: duration,
        action: onRetry != null
            ? SnackBarAction(
                label: retryLabel,
                textColor: theme.colorScheme.error,
                onPressed: onRetry,
              )
            : null,
      ),
    );
}
