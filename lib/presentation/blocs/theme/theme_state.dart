import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_event.dart';

const _darkSurface = Color(0xFF05060F);
const _lightSurface = Color(0xFFF8F7FB);

/// Represents the complete theme state
class ThemeState extends Equatable {
  /// Current theme mode
  final ThemeMode themeMode;

  /// Whether dynamic color is enabled
  final bool isDynamicColorEnabled;

  /// Primary color (either from album art or default)
  final Color primaryColor;

  /// Default/fallback primary color
  final Color defaultPrimaryColor;

  /// Current layout mode
  final LayoutMode layoutMode;

  /// Whether currently extracting color from image
  final bool isExtractingColor;

  const ThemeState({
    this.themeMode = ThemeMode.system,
    this.isDynamicColorEnabled = true,
    this.primaryColor = const Color(0xFF6750A4), // Material 3 default purple
    this.defaultPrimaryColor = const Color(0xFF6750A4),
    this.layoutMode = LayoutMode.list,
    this.isExtractingColor = false,
  });

  /// Get ColorScheme for light theme
  ColorScheme get lightColorScheme => _buildColorScheme(Brightness.light);

  /// Get ColorScheme for dark theme
  ColorScheme get darkColorScheme => _buildColorScheme(Brightness.dark);

  ThemeData get lightTheme => _buildTheme(Brightness.light);

  ThemeData get darkTheme => _buildTheme(Brightness.dark);

  ColorScheme _buildColorScheme(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
    );

    final bool isDark = brightness == Brightness.dark;
    final surface = isDark ? _darkSurface : _lightSurface;
    Color colorWithOpacity(Color color, double opacity) =>
        color.withAlpha((opacity * 255).round());

    return base.copyWith(
      surface: surface,
      surfaceTint: Colors.transparent,
      secondary: isDark ? const Color(0xFF50E3C2) : const Color(0xFF5B8CFF),
      tertiary: isDark ? const Color(0xFFFF9F7B) : const Color(0xFFFF7EB6),
      outlineVariant: colorWithOpacity(base.outlineVariant, 0.4),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = brightness == Brightness.dark ? darkColorScheme : lightColorScheme;
    final baseTextTheme = GoogleFonts.spaceGroteskTextTheme(
      brightness == Brightness.dark
          ? ThemeData(brightness: Brightness.dark).textTheme
          : ThemeData(brightness: Brightness.light).textTheme,
    );

    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        letterSpacing: -1.5,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        letterSpacing: -1,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        letterSpacing: -0.5,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        letterSpacing: -0.1,
      ),
    ).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
        toolbarHeight: 72,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface.withAlpha(
          ((brightness == Brightness.dark ? 0.9 : 0.95) * 255).round(),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        indicatorColor: scheme.primary.withAlpha((0.15 * 255).round()),
        backgroundColor: scheme.surface.withAlpha((0.9 * 255).round()),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        backgroundColor: scheme.surface,
        elevation: 0,
        showDragHandle: true,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh.withAlpha((0.35 * 255).round()),
        selectedColor: scheme.primary.withAlpha((0.15 * 255).round()),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        side: BorderSide(color: scheme.outlineVariant.withAlpha((0.2 * 255).round())),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHigh.withAlpha((0.6 * 255).round()),
        thumbColor: scheme.onPrimary,
      ),
      dividerColor: scheme.outlineVariant.withAlpha((0.4 * 255).round()),
      iconTheme: IconThemeData(color: scheme.onSurface),
      splashFactory: InkRipple.splashFactory,
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
      isDynamicColorEnabled: isDynamicColorEnabled ?? this.isDynamicColorEnabled,
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
