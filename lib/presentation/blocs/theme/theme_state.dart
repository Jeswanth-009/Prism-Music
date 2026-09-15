import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_event.dart';
import '../../theme/prism_theme.dart';

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

  ThemeData get lightTheme => _buildTheme(Brightness.light);

  ThemeData get darkTheme => _buildTheme(Brightness.dark);

  /// Nudges the accent toward the lightness that reads well on the given
  /// brightness, so one seed accent can serve both themes.
  Color _accentFor(Brightness brightness) {
    final hsl = HSLColor.fromColor(primaryColor);
    if (brightness == Brightness.dark) {
      return hsl.withLightness(0.72).withSaturation(
        hsl.saturation.clamp(0.45, 0.75),
      ).toColor();
    }
    return hsl.withLightness(0.48).withSaturation(
      hsl.saturation.clamp(0.50, 0.80),
    ).toColor();
  }

  ColorScheme _buildColorScheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final accent = _accentFor(brightness);
    final surface = isDark ? PrismColors.ink : PrismColors.paper;
    final onSurface = isDark
        ? const Color(0xFFF3F4F9)
        : const Color(0xFF171922);

    return ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: isDark
          ? PrismColors.accentContainerDark
          : PrismColors.accentContainerLight,
      onPrimaryContainer: isDark
          ? const Color(0xFFCFC5FF)
          : const Color(0xFF2A1D66),
      secondary: accent.withValues(alpha: .55),
      onSecondary: Colors.white,
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
          : const Color(0xFF5E6373),
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
          : const Color(0xFFC8C4BB),
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
    final scheme = brightness == Brightness.dark
        ? darkColorScheme
        : lightColorScheme;
    final isDark = brightness == Brightness.dark;

    final baseTextTheme = GoogleFonts.interTextTheme(
      brightness == Brightness.dark
          ? ThemeData(brightness: Brightness.dark).textTheme
          : ThemeData(brightness: Brightness.light).textTheme,
    );

    final textTheme = baseTextTheme
        .copyWith(
          displayLarge: baseTextTheme.displayLarge?.copyWith(
            letterSpacing: -1.2,
            fontWeight: FontWeight.w700,
          ),
          displaySmall: baseTextTheme.displaySmall?.copyWith(
            letterSpacing: -0.8,
            fontWeight: FontWeight.w700,
          ),
          headlineLarge: baseTextTheme.headlineLarge?.copyWith(
            letterSpacing: -0.9,
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: baseTextTheme.headlineMedium?.copyWith(
            letterSpacing: -0.6,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: baseTextTheme.titleLarge?.copyWith(
            letterSpacing: -0.3,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: baseTextTheme.titleMedium?.copyWith(
            letterSpacing: -0.2,
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    final spec = PrismSpec(
      accent: scheme.primary,
      accentSoft: scheme.primary.withValues(alpha: isDark ? 0.16 : 0.10),
      skeletonBase: isDark
          ? PrismColors.inkHigh
          : PrismColors.paperHigh,
      skeletonHighlight: isDark
          ? PrismColors.inkHighest
          : PrismColors.paperHighest,
      hairline: scheme.outlineVariant,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      extensions: [spec],
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
          borderRadius: BorderRadius.circular(PrismRadius.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        backgroundColor: scheme.surfaceContainerLow,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.45),
        selectedColor: spec.accentSoft,
        checkmarkColor: scheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .3)),
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
          side: BorderSide(color: scheme.outline),
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
