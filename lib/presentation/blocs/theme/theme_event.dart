import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Base class for all theme events
abstract class ThemeEvent extends Equatable {
  const ThemeEvent();

  @override
  List<Object?> get props => [];
}

/// Set theme mode (light/dark/system)
class SetThemeModeEvent extends ThemeEvent {
  final ThemeMode mode;

  const SetThemeModeEvent(this.mode);

  @override
  List<Object?> get props => [mode];
}

/// Update dynamic color from album art
class UpdateDynamicColorEvent extends ThemeEvent {
  final String? imageUrl;
  final Color? primaryColor;

  const UpdateDynamicColorEvent({
    this.imageUrl,
    this.primaryColor,
  });

  @override
  List<Object?> get props => [imageUrl, primaryColor];
}

/// Toggle dynamic color feature
class ToggleDynamicColorEvent extends ThemeEvent {
  const ToggleDynamicColorEvent();
}

/// Set layout mode
class SetLayoutModeEvent extends ThemeEvent {
  final LayoutMode mode;

  const SetLayoutModeEvent(this.mode);

  @override
  List<Object?> get props => [mode];
}

/// Reset theme to default
class ResetThemeEvent extends ThemeEvent {
  const ResetThemeEvent();
}

/// Layout mode options
enum LayoutMode {
  list,
  grid,
  minimalist,
}
