import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/settings_service.dart';
import '../../theme/prism_theme.dart';

/// Wraps a single list item with a smooth staggered fade-in and subtle slide-up.
/// Automatically disables animation and renders instantly when reduced motion is preferred.
class PrismStaggeredItem extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration duration;
  final Duration delayStep;
  final Offset initialOffset;
  final Curve curve;

  const PrismStaggeredItem({
    super.key,
    required this.index,
    required this.child,
    this.duration = PrismMotion.base,
    this.delayStep = const Duration(milliseconds: 35),
    this.initialOffset = const Offset(0.0, 16.0),
    this.curve = PrismMotion.curve,
  });

  @override
  State<PrismStaggeredItem> createState() => _PrismStaggeredItemState();
}

class _PrismStaggeredItemState extends State<PrismStaggeredItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.initialOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    if (SettingsService.instance.reducedMotionMode) {
      _controller.value = 1.0;
      return;
    }

    final delayMs =
        (widget.index * widget.delayStep.inMilliseconds).clamp(0, 350);
    if (delayMs == 0) {
      _controller.forward();
    } else {
      _timer = Timer(Duration(milliseconds: delayMs), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (PrismMotion.isReducedMotion(context)) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) => Transform.translate(
          offset: _slideAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
