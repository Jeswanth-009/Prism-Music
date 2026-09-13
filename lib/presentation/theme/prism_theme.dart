import 'package:flutter/material.dart';

/// The small, deliberate set of visual primitives used across Prism Music.
/// Album artwork is allowed to introduce extra colour; the app chrome is not.
abstract final class PrismColors {
  static const ink = Color(0xFF070B1D);
  static const inkRaised = Color(0xFF10182F);
  static const inkSoft = Color(0xFF182342);
  static const paper = Color(0xFFF7F5F0);
  static const paperRaised = Color(0xFFFFFFFF);
  static const paperSoft = Color(0xFFECEAE4);

  static const cyan = Color(0xFF62E8FF);
  static const violet = Color(0xFFA978FF);
  static const magenta = Color(0xFFFF5CC8);
  static const lime = Color(0xFF86F7C0);
  static const coral = Color(0xFFFF7096);
  static const danger = Color(0xFFFF5D6C);

  static const spectrum = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [cyan, violet, magenta],
  );

  static const aurora = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF253C99), Color(0xFF7B3FC6), Color(0xFFD94D9A)],
  );
}

class AuroraBackdrop extends StatelessWidget {
  const AuroraBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: dark ? PrismColors.ink : const Color(0xFFF6F7FF),
          ),
        ),
        Positioned(
          top: -180,
          left: -120,
          child: _Glow(color: PrismColors.violet, size: 360, opacity: dark ? .22 : .12),
        ),
        Positioned(
          top: 60,
          right: -170,
          child: _Glow(color: PrismColors.cyan, size: 380, opacity: dark ? .14 : .10),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size, required this.opacity});
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)],
        ),
      ),
    ),
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
