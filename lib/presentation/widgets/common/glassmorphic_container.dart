import 'package:flutter/material.dart';

class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final BoxBorder? border;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.blur = 20,
    this.opacity = 0.5,
    this.borderRadius,
    this.padding,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(16);

    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: effectiveBorderRadius,
        border: border ?? Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}
