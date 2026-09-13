import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:logging/logging.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'core/di/injection.dart';
import 'core/services/audio_player_service.dart';
import 'core/services/permission_service.dart';
import 'core/services/local_backup_service.dart';
import 'core/services/prism_audio_handler.dart';
import 'presentation/blocs/player/player.dart';
import 'presentation/blocs/search/search.dart';
import 'presentation/blocs/library/library.dart';
import 'presentation/blocs/theme/theme.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/theme/prism_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Temporary global logging setup for search diagnostics.
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // Keep format compact for mobile logcat readability.
    debugPrint(
      '[${record.level.name}] ${record.loggerName}: ${record.message}',
    );
    if (record.error != null) {
      debugPrint('  error: ${record.error}');
    }
    if (record.stackTrace != null) {
      debugPrint('  stack: ${record.stackTrace}');
    }
  });

  // Initialize Hive FIRST, before any services that depend on it
  await Hive.initFlutter();

  // 1. Initialize dependencies so we can access AudioPlayerService
  await initializeDependencies();

  // 2. Get the AudioPlayerService instance
  final audioPlayerService = getIt<AudioPlayerService>();

  // 3. Initialize AudioService with our custom handler, passing the existing player
  await AudioService.init(
    builder: () => PrismAudioHandler(audioPlayerService.player),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.prismmusic.app.channel.audio',
      androidNotificationChannelName: 'Prism Music',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  // Restore user library from the on-device backup (survives uninstall).
  await LocalBackupService.instance.restoreIfNeeded();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Request permissions (non-blocking to avoid hot restart issues)
  // ignore: body_might_complete_normally_catch_error
  PermissionService.requestAllPermissions().catchError((_) {});

  runApp(const PrismMusicApp());
}

/// The main Prism Music application widget
class PrismMusicApp extends StatelessWidget {
  const PrismMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeBloc>(create: (_) => getIt<ThemeBloc>()),
        BlocProvider<PlayerBloc>(create: (_) => getIt<PlayerBloc>()),
        BlocProvider<SearchBloc>(create: (_) => getIt<SearchBloc>()),
        BlocProvider<LibraryBloc>(
          create: (_) => getIt<LibraryBloc>()..add(const LoadLibraryEvent()),
        ),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          return ShadApp.custom(
            themeMode: themeState.themeMode,
            theme: ShadThemeData(
              brightness: Brightness.light,
              colorScheme: ShadColorScheme(
                background: PrismColors.paper,
                foreground: PrismColors.ink,
                card: PrismColors.paperRaised,
                cardForeground: PrismColors.ink,
                popover: PrismColors.paperRaised,
                popoverForeground: PrismColors.ink,
                primary: const Color(0xFF007E73),
                primaryForeground: Colors.white,
                secondary: PrismColors.paperSoft,
                secondaryForeground: PrismColors.ink,
                muted: PrismColors.paperSoft,
                mutedForeground: const Color(0xFF656760),
                accent: const Color(0xFFD9F7F0),
                accentForeground: const Color(0xFF005B53),
                destructive: PrismColors.danger,
                destructiveForeground: Colors.white,
                border: const Color(0xFFDDDAD3),
                input: const Color(0xFFDDDAD3),
                ring: const Color(0xFF007E73),
                selection: const Color(0xFFBCEDE4),
              ),
            ),
            darkTheme: ShadThemeData(
              brightness: Brightness.dark,
              colorScheme: const ShadColorScheme(
                background: PrismColors.ink,
                foreground: Color(0xFFF4F2ED),
                card: PrismColors.inkRaised,
                cardForeground: Color(0xFFF4F2ED),
                popover: PrismColors.inkRaised,
                popoverForeground: Color(0xFFF4F2ED),
                primary: PrismColors.magenta,
                primaryForeground: PrismColors.ink,
                secondary: PrismColors.inkSoft,
                secondaryForeground: Color(0xFFF4F2ED),
                muted: PrismColors.inkSoft,
                mutedForeground: Color(0xFF9DA5B2),
                accent: Color(0xFF123B38),
                accentForeground: Color(0xFFBDF9EE),
                destructive: PrismColors.danger,
                destructiveForeground: Colors.white,
                border: Color(0xFF252C38),
                input: Color(0xFF252C38),
                ring: PrismColors.magenta,
                selection: Color(0xFF174B45),
              ),
            ),
            appBuilder: (context) {
              return MaterialApp(
                title: 'Prism Music',
                debugShowCheckedModeBanner: false,
                theme: themeState.lightTheme,
                darkTheme: themeState.darkTheme,
                themeMode: themeState.themeMode,
                builder: (context, child) {
                  return ShadAppBuilder(child: child!);
                },
                home: const HomePage(),
              );
            },
          );
        },
      ),
    );
  }
}
