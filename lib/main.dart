import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:logging/logging.dart';

import 'core/di/injection.dart';
import 'core/services/audio_player_service.dart';
import 'core/services/media_session_coordinator.dart';
import 'core/services/local_backup_service.dart';
import 'core/services/prism_audio_handler.dart';
import 'core/services/settings_service.dart';
import 'presentation/blocs/player/player.dart';
import 'presentation/blocs/search/search.dart';
import 'presentation/blocs/library/library.dart';
import 'presentation/blocs/theme/theme.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/onboarding_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global logging setup: active only in debug mode to prevent leaking
  // search queries, stream URLs, or internal state in release logcat.
  if (kDebugMode) {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
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
  } else {
    Logger.root.level = Level.OFF;
  }

  try {
    // Initialize Hive FIRST, before any services that depend on it
    await Hive.initFlutter();

    // 1. Initialize dependencies so we can access AudioPlayerService
    await initializeDependencies().timeout(const Duration(seconds: 8));

    // Settings must be ready before the app builds so the persisted theme
    // mode is available to ThemeBloc on first frame.
    await SettingsService.instance.initialize().timeout(const Duration(seconds: 5));

    // 2. Get the AudioPlayerService instance
    final audioPlayerService = getIt<AudioPlayerService>();

    // 3. Initialize AudioService with our custom handler, passing the existing player.
    final audioHandler = PrismAudioHandler(audioPlayerService.player);
    await AudioService.init(
      builder: () => audioHandler,
      config: const AudioServiceConfig(
        androidNotificationChannelId:
            'com.prismmusic.app.channel.audio.playback.v2',
        androidNotificationChannelName: 'Prism Music',
        androidNotificationChannelDescription:
            'Now-playing controls and media session for Prism Music',
        notificationColor: Color(0xFF8B7BFF),
        androidNotificationIcon: 'drawable/ic_notification',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
        artDownscaleWidth: 512,
        artDownscaleHeight: 512,
      ),
    ).timeout(const Duration(seconds: 8));
    MediaSessionCoordinator.instance.attachHandler(audioHandler);

    // Restore user library from the on-device backup (survives uninstall).
    try {
      await LocalBackupService.instance.restoreIfNeeded().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Backup restore skipped due to timeout or error: $e');
    }

    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    runApp(const PrismMusicApp());
  } catch (e, stack) {
    debugPrint('Fatal initialization error: $e\n$stack');
    runApp(StartupErrorApp(errorMessage: e.toString()));
  }
}

/// Fallback recovery screen when unexpected fatal error occurs during startup (M27)
class StartupErrorApp extends StatelessWidget {
  final String errorMessage;

  const StartupErrorApp({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prism Music Recovery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D12),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B7BFF),
          surface: Color(0xFF181822),
        ),
      ),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFF6B6B),
                  size: 64,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Prism Music Startup Issue',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'The application encountered a problem during initialization. Your downloads and library data are preserved.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFB0B0C0),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181822),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2E2E3E)),
                  ),
                  child: Text(
                    errorMessage,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFFFF9E9E),
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => main(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry Startup'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8B7BFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
          return MaterialApp(
            title: 'Prism Music',
            debugShowCheckedModeBanner: false,
            theme: themeState.lightTheme,
            darkTheme: themeState.darkTheme,
            themeMode: themeState.themeMode,
            home: SettingsService.instance.onboardingComplete
                ? const HomePage()
                : const OnboardingPage(),
          );
        },
      ),
    );
  }
}
