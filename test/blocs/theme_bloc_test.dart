import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/presentation/blocs/theme/theme_bloc.dart';
import 'package:prism_music/presentation/blocs/theme/theme_event.dart';
import 'package:prism_music/presentation/blocs/theme/theme_state.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // ThemeBloc persists through the SettingsService singleton, which is
    // backed by Hive — the box survives across tests in this file, so
    // reset the dynamic-accent flag every test for determinism.
    initTestHive('theme');
    await SettingsService.instance.initialize();
    await SettingsService.instance.setDynamicAccent(false);
  });

  group('ThemeBloc', () {
    test('starts with the injected initial mode', () {
      final bloc = ThemeBloc(initialThemeMode: ThemeMode.dark);
      expect(bloc.state.themeMode, ThemeMode.dark);
      return bloc.close();
    });

    test('SetThemeModeEvent updates state and persists the choice',
        () async {
      final bloc = ThemeBloc(initialThemeMode: ThemeMode.system);
      bloc.add(const SetThemeModeEvent(ThemeMode.light));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(bloc.state.themeMode, ThemeMode.light);
      expect(SettingsService.instance.themeMode, ThemeMode.light);
      await bloc.close();
    });

    test('light and dark themes are built with distinct brightnesses', () {
      final state = const ThemeState();
      expect(state.lightTheme.brightness, Brightness.light);
      expect(state.darkTheme.brightness, Brightness.dark);
      expect(state.lightTheme.useMaterial3, isTrue);
      expect(state.darkTheme.useMaterial3, isTrue);
    });

    test('ToggleDynamicColorEvent flips the flag and persists it',
        () async {
      final bloc = ThemeBloc(initialThemeMode: ThemeMode.system);
      expect(bloc.state.isDynamicColorEnabled, isFalse);

      bloc.add(const ToggleDynamicColorEvent());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.isDynamicColorEnabled, isTrue);
      expect(SettingsService.instance.dynamicAccent, isTrue);

      // Second toggle flips back off and reverts the primary color.
      bloc.add(const ToggleDynamicColorEvent());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.isDynamicColorEnabled, isFalse);
      expect(bloc.state.primaryColor, bloc.state.defaultPrimaryColor);
      expect(SettingsService.instance.dynamicAccent, isFalse);
      await bloc.close();
    });

    test('UpdateDynamicColorEvent with a direct color applies it when '
        'dynamic color is enabled', () async {
      final bloc = ThemeBloc(initialThemeMode: ThemeMode.system);
      bloc.add(const ToggleDynamicColorEvent());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      bloc.add(const UpdateDynamicColorEvent(primaryColor: Colors.teal));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(bloc.state.primaryColor, Colors.teal);
      await bloc.close();
    });

    test('UpdateDynamicColorEvent is ignored while dynamic color is off',
        () async {
      final bloc = ThemeBloc(initialThemeMode: ThemeMode.system);
      final colorBefore = bloc.state.primaryColor;

      bloc.add(const UpdateDynamicColorEvent(primaryColor: Colors.red));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(bloc.state.primaryColor, colorBefore);
      await bloc.close();
    });

    test('SetLayoutModeEvent updates the layout mode', () async {
      final bloc = ThemeBloc(initialThemeMode: ThemeMode.system);
      bloc.add(const SetLayoutModeEvent(LayoutMode.grid));

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.layoutMode, LayoutMode.grid);
      await bloc.close();
    });

    test('ResetThemeEvent returns to defaults', () async {
      final bloc = ThemeBloc(initialThemeMode: ThemeMode.dark);
      bloc.add(const SetLayoutModeEvent(LayoutMode.minimalist));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      bloc.add(const ResetThemeEvent());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(bloc.state.themeMode, ThemeMode.system);
      expect(bloc.state.layoutMode, LayoutMode.list);
      await bloc.close();
    });
  });
}
