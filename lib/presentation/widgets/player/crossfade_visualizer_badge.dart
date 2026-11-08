import 'package:flutter/material.dart';
import '../../theme/prism_theme.dart';

/// Visual feedback badge showing that audio crossfade transition is actively running.
class CrossfadeVisualizerBadge extends StatefulWidget {
  final bool isCrossfading;
  final bool compact;

  const CrossfadeVisualizerBadge({
    super.key,
    required this.isCrossfading,
    this.compact = false,
  });

  @override
  State<CrossfadeVisualizerBadge> createState() => _CrossfadeVisualizerBadgeState();
}

class _CrossfadeVisualizerBadgeState extends State<CrossfadeVisualizerBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: widget.isCrossfading
          ? FadeTransition(
              opacity: _pulseAnimation,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 6 : 10,
                  vertical: widget.compact ? 2 : 4,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF8B7BFF),
                      Color(0xFF6355E8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: PrismColors.accentDark.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.swap_horiz_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.compact ? 'Fade' : 'Crossfading...',
                      style: TextStyle(
                        fontSize: widget.compact ? 10 : 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
