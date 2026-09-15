import 'package:flutter/material.dart';

/// Prism's visual primitives.
///
/// The chrome stays quiet: flat layered surfaces, one violet accent, Inter
/// typography. Album artwork supplies the colour; the spectrum gradient
/// survives only in the logo mark.
abstract final class PrismColors {
  // ── Surfaces ──────────────────────────────────────────────────────────
  // Dark: flat layered near-blacks.
  static const ink = Color(0xFF0A0C12); // scaffold
  static const inkLow = Color(0xFF10131C);
  static const inkRaised = Color(0xFF141826); // cards
  static const inkHigh = Color(0xFF1B2032);
  static const inkHighest = Color(0xFF232941);

  // Light: warm paper.
  static const paper = Color(0xFFF6F5F2); // scaffold
  static const paperLow = Color(0xFFFBFAF8);
  static const paperRaised = Color(0xFFFFFFFF); // cards
  static const paperHigh = Color(0xFFF0EEE9);
  static const paperHighest = Color(0xFFE7E4DD);

  // ── Accent ────────────────────────────────────────────────────────────
  static const accentDark = Color(0xFF8B7BFF);
  static const accentLight = Color(0xFF6355E8);
  static const accentContainerDark = Color(0xFF2A224F);
  static const accentContainerLight = Color(0xFFE7E2FF);

  static const danger = Color(0xFFFF5D6C);

  /// Logo mark only. Never use for surfaces.
  static const spectrum = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF62E8FF), Color(0xFFA978FF), Color(0xFFFF5CC8)],
  );
}

/// Theme-extension tokens consumed by widgets via `context.prismSpec`.
@immutable
class PrismSpec extends ThemeExtension<PrismSpec> {
  const PrismSpec({
    required this.accent,
    required this.accentSoft,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.hairline,
  });

  /// The single app accent.
  final Color accent;

  /// Low-emphasis accent fill (selected chips, now-playing tint).
  final Color accentSoft;

  /// Skeleton loading blocks.
  final Color skeletonBase;
  final Color skeletonHighlight;

  /// Hairline borders on quiet cards.
  final Color hairline;

  static PrismSpec of(BuildContext context) =>
      Theme.of(context).extension<PrismSpec>()!;

  @override
  PrismSpec copyWith({
    Color? accent,
    Color? accentSoft,
    Color? skeletonBase,
    Color? skeletonHighlight,
    Color? hairline,
  }) =>
      PrismSpec(
        accent: accent ?? this.accent,
        accentSoft: accentSoft ?? this.accentSoft,
        skeletonBase: skeletonBase ?? this.skeletonBase,
        skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
        hairline: hairline ?? this.hairline,
      );

  @override
  PrismSpec lerp(PrismSpec? other, double t) {
    if (other is! PrismSpec) return this;
    return PrismSpec(
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      skeletonBase: Color.lerp(skeletonBase, other.skeletonBase, t)!,
      skeletonHighlight: Color.lerp(
        skeletonHighlight,
        other.skeletonHighlight,
        t,
      )!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
    );
  }
}

extension PrismThemeX on BuildContext {
  ThemeData get prismTheme => Theme.of(this);
  ColorScheme get prismColors => Theme.of(this).colorScheme;
  PrismSpec get prismSpec => PrismSpec.of(this);
  bool get isPrismDark => Theme.of(this).brightness == Brightness.dark;
}

/// Radius scale used across the app.
abstract final class PrismRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 24.0;
}

/// Standard motion durations + curve.
abstract final class PrismMotion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 320);
  static const curve = Curves.easeOutCubic;
}
