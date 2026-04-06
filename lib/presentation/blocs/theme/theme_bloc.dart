import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:palette_generator/palette_generator.dart';
import 'theme_event.dart';
import 'theme_state.dart';

/// BLoC for managing app theme and dynamic colors
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc() : super(const ThemeState()) {
    on<SetThemeModeEvent>(_onSetThemeMode);
    on<UpdateDynamicColorEvent>(_onUpdateDynamicColor);
    on<ToggleDynamicColorEvent>(_onToggleDynamicColor);
    on<SetLayoutModeEvent>(_onSetLayoutMode);
    on<ResetThemeEvent>(_onResetTheme);
  }

  void _onSetThemeMode(
    SetThemeModeEvent event,
    Emitter<ThemeState> emit,
  ) {
    emit(state.copyWith(themeMode: event.mode));
    // TODO: Persist theme preference
  }

  Future<void> _onUpdateDynamicColor(
    UpdateDynamicColorEvent event,
    Emitter<ThemeState> emit,
  ) async {
    if (!state.isDynamicColorEnabled) return;

    // If a direct color is provided, use it
    if (event.primaryColor != null) {
      emit(state.copyWith(primaryColor: event.primaryColor));
      return;
    }

    // If an image URL is provided, extract color
    if (event.imageUrl != null && event.imageUrl!.isNotEmpty) {
      emit(state.copyWith(isExtractingColor: true));

      try {
        final paletteGenerator = await PaletteGenerator.fromImageProvider(
          NetworkImage(event.imageUrl!),
          maximumColorCount: 20,
        );

        // Get the dominant color or vibrant color
        Color? extractedColor = paletteGenerator.dominantColor?.color ??
            paletteGenerator.vibrantColor?.color ??
            paletteGenerator.mutedColor?.color;

        if (extractedColor != null) {
          // Ensure the color has enough saturation
          final hsl = HSLColor.fromColor(extractedColor);
          if (hsl.saturation < 0.3) {
            // If color is too muted, increase saturation
            extractedColor = hsl.withSaturation(0.5).toColor();
          }
          emit(state.copyWith(
            primaryColor: extractedColor,
            isExtractingColor: false,
          ));
        } else {
          emit(state.copyWith(isExtractingColor: false));
        }
      } catch (e) {
        // Fallback to default on error
        emit(state.copyWith(
          primaryColor: state.defaultPrimaryColor,
          isExtractingColor: false,
        ));
      }
    }
  }

  void _onToggleDynamicColor(
    ToggleDynamicColorEvent event,
    Emitter<ThemeState> emit,
  ) {
    final enabled = !state.isDynamicColorEnabled;
    emit(state.copyWith(
      isDynamicColorEnabled: enabled,
      primaryColor: enabled ? state.primaryColor : state.defaultPrimaryColor,
    ));
    // TODO: Persist preference
  }

  void _onSetLayoutMode(
    SetLayoutModeEvent event,
    Emitter<ThemeState> emit,
  ) {
    emit(state.copyWith(layoutMode: event.mode));
    // TODO: Persist preference
  }

  void _onResetTheme(
    ResetThemeEvent event,
    Emitter<ThemeState> emit,
  ) {
    emit(const ThemeState());
  }
}
