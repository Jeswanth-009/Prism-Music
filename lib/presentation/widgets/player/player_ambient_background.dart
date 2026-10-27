import 'package:flutter/material.dart';

/// Dynamic ambient gradient background derived from dominant artwork color.
class PlayerAmbientBackground extends StatelessWidget {
  const PlayerAmbientBackground({
    super.key,
    required this.dominantColor,
  });

  final Color? dominantColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = dominantColor ?? theme.colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  accent.withValues(alpha: 0.34),
                  theme.colorScheme.surfaceContainerLow.withValues(alpha: .6),
                  theme.colorScheme.surface,
                ]
              : [
                  accent.withValues(alpha: 0.16),
                  theme.colorScheme.surface,
                  theme.colorScheme.surfaceContainerLow,
                ],
        ),
      ),
    );
  }
}
