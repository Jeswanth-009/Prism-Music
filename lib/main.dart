import 'package:flutter/material.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Temporary global logging setup for search diagnostics.
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // Keep format compact for mobile logcat readability.
    debugPrint('[${record.level.name}] ${record.loggerName}: ${record.message}');
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
        BlocProvider<ThemeBloc>(
          create: (_) => getIt<ThemeBloc>(),
        ),
        BlocProvider<PlayerBloc>(
          create: (_) => getIt<PlayerBloc>(),
        ),
        BlocProvider<SearchBloc>(
          create: (_) => getIt<SearchBloc>(),
        ),
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
              colorScheme: const ShadZincColorScheme.light(),
            ),
            darkTheme: ShadThemeData(
              brightness: Brightness.dark,
              colorScheme: const ShadZincColorScheme.dark(),
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
