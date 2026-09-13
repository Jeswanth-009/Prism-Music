import 'package:flutter/material.dart';

/// The small, deliberate set of visual primitives used across Prism Music.
/// Album artwork is allowed to introduce extra colour; the app chrome is not.
abstract final class PrismColors {
  static const ink = Color(0xFF080B12);
  static const inkRaised = Color(0xFF10151F);
  static const inkSoft = Color(0xFF171D28);
  static const paper = Color(0xFFF7F5F0);
  static const paperRaised = Color(0xFFFFFFFF);
  static const paperSoft = Color(0xFFECEAE4);

  static const cyan = Color(0xFF2DE2C5);
  static const lime = Color(0xFFB8F23C);
  static const coral = Color(0xFFFF6B4A);
  static const danger = Color(0xFFFF5D6C);

  static const spectrum = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [cyan, lime, coral],
  );
}

extension PrismThemeX on BuildContext {
  ThemeData get prismTheme => Theme.of(this);
  ColorScheme get prismColors => Theme.of(this).colorScheme;
  bool get isPrismDark => Theme.of(this).brightness == Brightness.dark;
}

class PrismSpectrumLine extends StatelessWidget {
  const PrismSpectrumLine({super.key, this.width = 64, this.height = 3});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: PrismColors.spectrum,
        borderRadius: BorderRadius.circular(height),
      ),
    );
  }
}

class PrismSurface extends StatelessWidget {
  const PrismSurface({
    super.key,
    required this.child,
    this.padding,
    this.radius = 20,
    this.onTap,
    this.emphasized = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final VoidCallback? onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surface = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: padding,
      decoration: BoxDecoration(
        color: emphasized
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );

    if (onTap == null) return surface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: surface,
      ),
    );
  }
}
