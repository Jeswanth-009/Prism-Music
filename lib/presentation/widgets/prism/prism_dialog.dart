import 'package:flutter/material.dart';
import '../../theme/prism_theme.dart';

/// Shows a standardized Prism styled dialog.
Future<T?> showPrismDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  List<Widget>? actions,
}) {
  final theme = Theme.of(context);
  return showDialog<T>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PrismRadius.lg),
      ),
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      content: content,
      actions: actions,
    ),
  );
}

/// Shows a confirmation dialog with optional destructive coloring.
Future<bool?> showPrismConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
  required VoidCallback onConfirm,
}) {
  final theme = Theme.of(context);
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PrismRadius.lg),
      ),
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                )
              : null,
          onPressed: () {
            Navigator.of(dialogContext).pop(true);
            onConfirm();
          },
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
