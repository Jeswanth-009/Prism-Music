import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'theme_event.dart';
import '../../theme/prism_page_transitions.dart';
import '../../theme/prism_theme.dart';

/// Contrast an artwork accent must hold as text on the surface. WCAG AA is
/// 4.5; dark goes higher so the accent still separates from raised cards.
const _kAccentContrastDark = 6.0;
const _kAccentContrastLight = 4.7;

/// Represents the complete theme state
class ThemeState extends Equatable {
  /// Current theme mode
  final ThemeMode themeMode;

  /// Whether dynamic color is enabled
  final bool isDynamicColorEnabled;

  /// Accent color (either from album art or default)
  final Color primaryColor;

  /// Default/fallback accent color
  final Color defaultPrimaryColor;

  /// Current layout mode
  final LayoutMode layoutMode;

  /// Whether currently extracting color from image
  final bool isExtractingColor;

  const ThemeState({
    this.themeMode = ThemeMode.system,
    this.isDynamicColorEnabled = true,
    this.primaryColor = PrismColors.accentDark,
    this.defaultPrimaryColor = PrismColors.accentDark,
    this.layoutMode = LayoutMode.list,
    this.isExtractingColor = false,
  });

  /// Get ColorScheme for light theme
  ColorScheme get lightColorScheme => _buildColorScheme(Brightness.light);

  /// Get ColorScheme for dark theme
  ColorScheme get darkColorScheme => _buildColorScheme(Brightness.dark);

  /// Built on demand. ThemeBloc only emits on theme-mode, layout and
  /// artwork-accent changes, so per-emission construction is rare; the
  /// [PrismSpec] == implementation keeps AnimatedTheme from re-lerping
  /// identical themes.
  ThemeData get lightTheme => _buildTheme(Brightness.light);

  ThemeData get darkTheme => _buildTheme(Brightness.dark);

  /// The accent for [brightness]: the brand accent as-is, or the artwork
  /// accent toned until it reads as text on the theme's surface.
  Color _accentFor(Brightness brightness) {
    if (primaryColor == defaultPrimaryColor) {
      return brightness == Brightness.dark
          ? PrismColors.accentDark
          : PrismColors.accentLight;
    }
    return _tonedAccent(primaryColor, brightness);
  }

  /// Resolves an artwork accent to the tone that holds
  /// [_kAccentContrastDark] / [_kAccentContrastLight] against the surface.
  ///
  /// HSL lightness is not perceptual — a "72%" amber is far brighter than a
  /// "72%" blue — so the tone is picked by luminance. Every hue lands at the
  /// same visual weight, and pale accents no longer take white glyphs they
  /// cannot contrast with ([PrismColors.onColor] handles the glyph side).
  static Color _tonedAccent(Color seed, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface =
        (isDark ? PrismColors.ink : PrismColors.paper).computeLuminance();
    final contrast = isDark ? _kAccentContrastDark : _kAccentContrastLight;
    final target = isDark
        ? contrast * (surface + 0.05) - 0.05
        : (surface + 0.05) / contrast - 0.05;

    final base = HSLColor.fromColor(seed);
    // A near-grey seed has no meaningful hue; borrow the brand's.
    final hue = base.saturation < 0.08
        ? HSLColor.fromColor(PrismColors.accentDark).hue
        : base.hue;
    final hsl = base
        .withHue(hue)
        .withSaturation(
          base.saturation.clamp(isDark ? 0.45 : 0.50, isDark ? 0.75 : 0.80),
        );

    // Luminance rises monotonically with lightness. Find where it crosses
    // the target, then keep the side that stays darker than it in light
    // mode and lighter than it in dark mode.
    var lo = 0.0;
    var hi = 1.0;
    for (var i = 0; i < 20; i++) {
      final mid = (lo + hi) / 2;
      final crossed =
          hsl.withLightness(mid).toColor().computeLuminance() >= target;
      if (crossed) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return hsl.withLightness(isDark ? hi : lo).toColor();
  }

  ColorScheme _buildColorScheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final accent = _accentFor(brightness);
    final surface = isDark ? PrismColors.ink : PrismColors.paper;
    final onSurface = isDark
        ? const Color(0xFFF3F4F9)
        : const Color(0xFF171922);

    final onAccent = PrismColors.onColor(accent);

    return ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      // Containers follow the accent, so an amber track never sits in a
      // violet container.
      primaryContainer: Color.lerp(
        isDark ? PrismColors.inkRaised : PrismColors.paperRaised,
        accent,
        isDark ? 0.22 : 0.14,
      )!,
      onPrimaryContainer: Color.lerp(onSurface, accent, isDark ? 0.55 : 0.6)!,
      secondary: accent.withValues(alpha: .55),
      onSecondary: onAccent,
      secondaryContainer: isDark
          ? PrismColors.inkHigh
          : PrismColors.paperHigh,
      onSecondaryContainer: onSurface,
      tertiary: accent,
      onTertiary: Colors.white,
      error: PrismColors.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: isDark
          ? const Color(0xFFA3A9BD)
          : const Color(0xFF494D5C),
      surfaceContainerLowest: isDark
          ? const Color(0xFF07080D)
          : Colors.white,
      surfaceContainerLow: isDark
          ? PrismColors.inkLow
          : PrismColors.paperLow,
      surfaceContainer: isDark
          ? PrismColors.inkRaised
          : PrismColors.paperRaised,
      surfaceContainerHigh: isDark
          ? PrismColors.inkHigh
          : PrismColors.paperHigh,
      surfaceContainerHighest: isDark
          ? PrismColors.inkHighest
          : PrismColors.paperHighest,
      outline: isDark
          ? const Color(0xFF3A415A)
          : const Color(0xFFB0ACA2),
      outlineVariant: isDark
          ? const Color(0xFF262C3F)
          : const Color(0xFFE3E0D8),
      surfaceTint: Colors.transparent,
      shadow: Colors.black,
      inverseSurface: isDark
          ? PrismColors.paperRaised
          : PrismColors.inkHighest,
      onInverseSurface: isDark
          ? const Color(0xFF171922)
          : const Color(0xFFF3F4F9),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = _buildColorScheme(brightness);
    final isDark = brightness == Brightness.dark;

    final baseTextTheme = (brightness == Brightness.dark
            ? ThemeData(brightness: Brightness.dark).textTheme
            : ThemeData(brightness: Brightness.light).textTheme)
        .apply(fontFamily: 'Inter');

    final textTheme = baseTextTheme
        .copyWith(
          // One scale, three weights (400 read / 500-600 emphasize /
          // 700 announce). Tracking follows size: negative on display,
          // neutral on body, positive on small labels and caps.
          displayLarge: baseTextTheme.displayLarge?.copyWith(
            fontSize: 44,
            height: 1.1,
            letterSpacing: -0.9,
            fontWeight: FontWeight.w700,
          ),
          displayMedium: baseTextTheme.displayMedium?.copyWith(
            fontSize: 36,
            height: 1.12,
            letterSpacing: -0.72,
            fontWeight: FontWeight.w700,
          ),
          displaySmall: baseTextTheme.displaySmall?.copyWith(
            fontSize: 32,
            height: 1.14,
            letterSpacing: -0.5,
            fontWeight: FontWeight.w700,
          ),
          headlineLarge: baseTextTheme.headlineLarge?.copyWith(
            fontSize: 32,
            height: 1.15,
            letterSpacing: -0.5,
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: baseTextTheme.headlineMedium?.copyWith(
            fontSize: 28,
            height: 1.18,
            letterSpacing: -0.35,
            fontWeight: FontWeight.w600,
          ),
          headlineSmall: baseTextTheme.headlineSmall?.copyWith(
            fontSize: 24,
            height: 1.22,
            letterSpacing: -0.25,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: baseTextTheme.titleLarge?.copyWith(
            fontSize: 22,
            height: 1.25,
            letterSpacing: -0.2,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: baseTextTheme.titleMedium?.copyWith(
            fontSize: 16,
            height: 1.3,
            letterSpacing: -0.1,
            fontWeight: FontWeight.w600,
          ),
          titleSmall: baseTextTheme.titleSmall?.copyWith(
            fontSize: 14,
            height: 1.35,
            letterSpacing: 0,
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(
            fontSize: 16,
            height: 1.5,
            letterSpacing: 0,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(
            fontSize: 14,
            height: 1.45,
            letterSpacing: 0,
            fontWeight: FontWeight.w400,
          ),
          bodySmall: baseTextTheme.bodySmall?.copyWith(
            fontSize: 12,
            height: 1.4,
            letterSpacing: 0.15,
            fontWeight: FontWeight.w400,
          ),
          labelLarge: baseTextTheme.labelLarge?.copyWith(
            fontSize: 14,
            height: 1.2,
            letterSpacing: 0.25,
            fontWeight: FontWeight.w500,
          ),
          labelMedium: baseTextTheme.labelMedium?.copyWith(
            fontSize: 12,
            height: 1.25,
            letterSpacing: 0.2,
            fontWeight: FontWeight.w500,
          ),
          labelSmall: baseTextTheme.labelSmall?.copyWith(
            fontSize: 11,
            height: 1.2,
            letterSpacing: 0.25,
            fontWeight: FontWeight.w500,
          ),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    final spec = PrismSpec(
      accent: scheme.primary,
      accentSoft: scheme.primary.withValues(alpha: isDark ? 0.16 : 0.10),
      onAccent: PrismColors.onColor(scheme.primary),
      success: isDark ? PrismColors.successDark : PrismColors.successLight,
      warning: isDark ? PrismColors.warningDark : PrismColors.warningLight,
      skeletonBase: isDark
          ? PrismColors.inkHigh
          : PrismColors.paperHigh,
      skeletonHighlight: isDark
          ? PrismColors.inkHighest
          : PrismColors.paperHighest,
      hairline: scheme.outlineVariant,
      scrim: PrismColors.scrim,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      extensions: [spec],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PrismPageTransitionsBuilder(),
          TargetPlatform.iOS: PrismPageTransitionsBuilder(),
          TargetPlatform.linux: PrismPageTransitionsBuilder(),
          TargetPlatform.macOS: PrismPageTransitionsBuilder(),
          TargetPlatform.windows: PrismPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
        toolbarHeight: 64,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PrismRadius.md),
          side: BorderSide(color: spec.hairline),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        backgroundColor: scheme.surfaceContainer,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PrismRadius.xl),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.45),
        selectedColor: spec.accentSoft,
        checkmarkColor: scheme.primary,
        // Pills. A chip row scrolls on one line; it never wraps.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PrismRadius.pill),
        ),
        labelStyle: textTheme.labelLarge,
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        side: BorderSide(color: spec.hairline),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHigh.withValues(alpha: .6),
        thumbColor: scheme.onPrimary,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PrismRadius.md),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: spec.hairline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: .5),
        space: 1,
        thickness: 1,
      ),
      dividerColor: scheme.outlineVariant.withValues(alpha: .5),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PrismRadius.md),
        ),
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  ThemeState copyWith({
    ThemeMode? themeMode,
    bool? isDynamicColorEnabled,
    Color? primaryColor,
    Color? defaultPrimaryColor,
    LayoutMode? layoutMode,
    bool? isExtractingColor,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      isDynamicColorEnabled:
          isDynamicColorEnabled ?? this.isDynamicColorEnabled,
      primaryColor: primaryColor ?? this.primaryColor,
      defaultPrimaryColor: defaultPrimaryColor ?? this.defaultPrimaryColor,
      layoutMode: layoutMode ?? this.layoutMode,
      isExtractingColor: isExtractingColor ?? this.isExtractingColor,
    );
  }

  @override
  List<Object?> get props => [
        themeMode,
        isDynamicColorEnabled,
        primaryColor,
        defaultPrimaryColor,
        layoutMode,
        isExtractingColor,
      ];
}
