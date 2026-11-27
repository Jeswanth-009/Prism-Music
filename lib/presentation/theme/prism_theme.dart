import 'package:flutter/material.dart';
import '../../core/services/settings_service.dart';

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

  // ── Semantic (resolved per brightness in PrismSpec) ───────────────────
  static const danger = Color(0xFFFF5D6C);
  static const dangerLight = Color(0xFFD64553);
  static const successDark = Color(0xFF34C77B);
  static const successLight = Color(0xFF1E8F55);
  static const warningDark = Color(0xFFFFB35C);
  static const warningLight = Color(0xFFA96400);

  /// Scrim over artwork and hero imagery. Black in both themes.
  static const scrim = Color(0x8C000000);
  static const scrimHeavy = Color(0xB3000000);

  /// Readable foreground on top of [scrim]. White in both themes.
  static const onScrim = Color(0xFFFFFFFF);

  // ── Data colours (chart provider identities; never chrome) ────────────
  static const brandApple = Color(0xFFFA57C1);
  static const brandSpotify = Color(0xFF1DB954);
  static const brandYouTube = Color(0xFFFF5252);
  static const brandBillboard = Color(0xFFFFC53D);

  // ── Rank medals (chart positions; data, never chrome) ─────────────────
  static const medalGold = Color(0xFFFFD700);
  static const medalSilver = Color(0xFFC0C0C0);
  static const medalBronze = Color(0xFFCD7F32);

  // ── Data hues (chart categories; data, never chrome) ──────────────────
  static const dataBlue = Color(0xFF5B9CF6);
  static const dataCoral = Color(0xFFFF6B5E);
  static const dataTeal = Color(0xFF2FBF9B);
  static const dataAmber = Color(0xFFF2B33D);
  static const dataViolet = Color(0xFF8B7BFF);
  static const dataPink = Color(0xFFF07EB0);
  static const dataOrange = Color(0xFFFF9A4D);
  static const dataSlate = Color(0xFF8FA1B3);

  /// Stable hue pick for data items without an assigned colour.
  static const dataHues = [
    dataBlue,
    dataCoral,
    dataTeal,
    dataAmber,
    dataViolet,
    dataPink,
    dataOrange,
    dataSlate,
  ];

  /// Logo mark only. Never use for surfaces.
  static const spectrum = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF62E8FF), Color(0xFFA978FF), Color(0xFFFF5CC8)],
  );

  /// Readable glyph/label colour on top of [background] (accent fills,
  /// badges, banners). Switches at the luminance where white stops meeting
  /// WCAG AA (4.5:1), so both branches clear it: white up to 0.18,
  /// near-black above.
  static Color onColor(Color background) => background.computeLuminance() > 0.18
      ? const Color(0xFF050608)
      : const Color(0xFFFFFFFF);
}

/// Theme-extension tokens consumed by widgets via `context.prismSpec`.
@immutable
class PrismSpec extends ThemeExtension<PrismSpec> {
  const PrismSpec({
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.hairline,
    required this.scrim,
  });

  /// The single app accent.
  final Color accent;

  /// Low-emphasis accent fill (selected chips, now-playing tint).
  final Color accentSoft;

  /// Readable text/icon colour on top of [accent] fills.
  final Color onAccent;

  /// Positive semantic colour (downloads verified, health OK).
  final Color success;

  /// Caution semantic colour (stream degradation, storage pressure).
  final Color warning;

  /// Skeleton loading blocks.
  final Color skeletonBase;
  final Color skeletonHighlight;

  /// Hairline borders on quiet cards.
  final Color hairline;

  /// Scrim over imagery.
  final Color scrim;

  static PrismSpec of(BuildContext context) {
    final theme = Theme.of(context);
    final spec = theme.extension<PrismSpec>();
    if (spec != null) return spec;
    // Bare MaterialApps (widget-test harnesses, embedders) mount without
    // the app theme; derive a quiet default instead of crashing.
    final scheme = theme.colorScheme;
    return PrismSpec(
      accent: scheme.primary,
      accentSoft: scheme.primary.withValues(alpha: 0.12),
      onAccent: PrismColors.onColor(scheme.primary),
      success: PrismColors.successDark,
      warning: PrismColors.warningDark,
      skeletonBase: scheme.surfaceContainerHigh,
      skeletonHighlight: scheme.surfaceContainerHighest,
      hairline: scheme.outlineVariant,
      scrim: PrismColors.scrim,
    );
  }

  @override
  PrismSpec copyWith({
    Color? accent,
    Color? accentSoft,
    Color? onAccent,
    Color? success,
    Color? warning,
    Color? skeletonBase,
    Color? skeletonHighlight,
    Color? hairline,
    Color? scrim,
  }) =>
      PrismSpec(
        accent: accent ?? this.accent,
        accentSoft: accentSoft ?? this.accentSoft,
        onAccent: onAccent ?? this.onAccent,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        skeletonBase: skeletonBase ?? this.skeletonBase,
        skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
        hairline: hairline ?? this.hairline,
        scrim: scrim ?? this.scrim,
      );

  @override
  PrismSpec lerp(PrismSpec? other, double t) {
    if (other is! PrismSpec) return this;
    return PrismSpec(
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      skeletonBase: Color.lerp(skeletonBase, other.skeletonBase, t)!,
      skeletonHighlight: Color.lerp(
        skeletonHighlight,
        other.skeletonHighlight,
        t,
      )!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }

  /// Value equality. ThemeData compares its extensions, so without this a
  /// rebuilt theme never equals the last one and AnimatedTheme re-runs.
  @override
  bool operator ==(Object other) =>
      other is PrismSpec &&
      other.accent == accent &&
      other.accentSoft == accentSoft &&
      other.onAccent == onAccent &&
      other.success == success &&
      other.warning == warning &&
      other.skeletonBase == skeletonBase &&
      other.skeletonHighlight == skeletonHighlight &&
      other.hairline == hairline &&
      other.scrim == scrim;

  @override
  int get hashCode => Object.hash(
        accent,
        accentSoft,
        onAccent,
        success,
        warning,
        skeletonBase,
        skeletonHighlight,
        hairline,
        scrim,
      );
}

extension PrismThemeX on BuildContext {
  ThemeData get prismTheme => Theme.of(this);
  ColorScheme get prismColors => Theme.of(this).colorScheme;
  PrismSpec get prismSpec => PrismSpec.of(this);
  bool get isPrismDark => Theme.of(this).brightness == Brightness.dark;
}

/// Spacing scale used consistently across all views and collection routes.
abstract final class PrismSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Horizontal page gutter. Every scrollable page edge uses this.
  static const gutter = 20.0;

  /// Gap between cards inside a horizontal rail.
  static const railGap = 12.0;
}

/// Radius scale used across the app.
abstract final class PrismRadius {
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 24.0;
  static const pill = 999.0;
}

/// Icon size scale. Inline badges use [xs], row and bar icons [sm]/[md],
/// hero and empty-state icons [lg]/[xl].
abstract final class PrismIconSize {
  static const xs = 14.0;
  static const sm = 16.0;
  static const md = 20.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

/// Text roles the Material theme has no slot for.
abstract final class PrismText {
  /// Label for all-caps eyebrows ("NOW PLAYING"). Caps always ship with
  /// tracking; uppercasing is the caller's job.
  static TextStyle? overline(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium?.copyWith(
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          );

  /// [style] with tabular figures, so times, ranks and bitrates line up.
  static TextStyle? tabular(TextStyle? style) => style?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

/// Standard motion durations + curve with reduced-motion support.
abstract final class PrismMotion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 320);
  static const curve = Curves.easeOutCubic;

  /// Returns true if either the system or user setting requests reduced motion.
  static bool isReducedMotion(BuildContext context) {
    final systemDisabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final userDisabled = SettingsService.instance.reducedMotionMode;
    return systemDisabled || userDisabled;
  }

  /// Returns Duration.zero if the user has requested reduced motion.
  static Duration duration(BuildContext context, Duration standard) {
    return isReducedMotion(context) ? Duration.zero : standard;
  }

  static Duration fastOf(BuildContext context) => duration(context, fast);
  static Duration baseOf(BuildContext context) => duration(context, base);
  static Duration slowOf(BuildContext context) => duration(context, slow);
}
