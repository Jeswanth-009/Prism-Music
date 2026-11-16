import 'package:flutter/material.dart';

import '../prism/prism_sheet.dart';

/// Shows the ambient audio recognition bottom sheet.
Future<void> showAmbientRecognitionSheet({
  required BuildContext context,
  required ValueChanged<String> onRecognized,
}) {
  return showPrismSheet(
    context: context,
    builder: (_) => AmbientRecognitionSheet(onRecognized: onRecognized),
  );
}

/// Ambient music identification sheet featuring animated waveform radar rings.
class AmbientRecognitionSheet extends StatefulWidget {
  const AmbientRecognitionSheet({super.key, required this.onRecognized});

  final ValueChanged<String> onRecognized;

  @override
  State<AmbientRecognitionSheet> createState() =>
      _AmbientRecognitionSheetState();
}

class _AmbientRecognitionSheetState extends State<AmbientRecognitionSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Identify Music',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Listening for music playing around you...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox.square(
              dimension: 140,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      for (int i = 0; i < 3; i++)
                        _buildWaveRing(
                          progress: (_controller.value + (i * 0.33)) % 1.0,
                          color: theme.colorScheme.primary,
                        ),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primaryContainer,
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          size: 32,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveRing({required double progress, required Color color}) {
    final size = 68.0 + (progress * 72.0);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: opacity * 0.6),
          width: 2.0,
        ),
      ),
    );
  }
}
