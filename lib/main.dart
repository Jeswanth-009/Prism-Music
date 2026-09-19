import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:logging/logging.dart';

import 'core/di/injection.dart';
import 'core/services/audio_player_service.dart';
import 'core/services/media_session_coordinator.dart';
import 'core/services/permission_service.dart';
import 'core/services/local_backup_service.dart';
import 'core/services/prism_audio_handler.dart';
import 'core/services/settings_service.dart';
import 'package:permission_handler/permission_handler.dart' show Permission;
import 'presentation/blocs/player/player.dart';
import 'presentation/blocs/search/search.dart';
import 'presentation/blocs/library/library.dart';
import 'presentation/blocs/theme/theme.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/onboarding_page.dart';

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

  // Settings must be ready before the app builds so the persisted theme
  // mode is available to ThemeBloc on first frame.
  await SettingsService.instance.initialize();

  // 2. Get the AudioPlayerService instance
  final audioPlayerService = getIt<AudioPlayerService>();

  // 3. Initialize AudioService with our custom handler, passing the existing player.
  //    Keep the handler reference so MediaSessionCoordinator can route the
  //    notification's next/previous/stop buttons into the PlayerBloc and
  //    re-render controls when the queue changes.
  final audioHandler = PrismAudioHandler(audioPlayerService.player);
  await AudioService.init(
    builder: () => audioHandler,
    config: const AudioServiceConfig(
      // Use a dedicated v2 playback channel. Android persists the old
      // channel's visibility/importance across app upgrades, so a channel
      // created by an earlier build can remain silently suppressed even when
      // POST_NOTIFICATIONS is granted.
      androidNotificationChannelId:
          'com.prismmusic.app.channel.audio.playback.v2',
      androidNotificationChannelName: 'Prism Music',
      androidNotificationChannelDescription:
          'Now-playing controls and media session for Prism Music',
      // Brand accent tint for the media notification card.
      notificationColor: Color(0xFF8B7BFF),
      // Monochrome white glyph for the status bar (Android renders small
      // notification icons as silhouettes); the colorful prism artwork still
      // shows in the expanded card. Tapping the card reopens the app via the
      // default androidNotificationClickStartsActivity.
      androidNotificationIcon: 'drawable/ic_notification',
      // While the service remains foregrounded Android makes the media card
      // ongoing automatically. This must be false when
      // androidStopForegroundOnPause is false (audio_service enforces that
      // configuration invariant).
      androidNotificationOngoing: false,
      // Real devices frequently report a short paused state while a source is
      // prepared or audio focus is re-acquired. Stopping foreground service
      // at that point prevents some OEMs from ever posting the media card.
      androidStopForegroundOnPause: false,
      // Decode notification artwork at a bounded size: crisp on the card
      // without decoding full-resolution (up to 1280px) bitmaps.
      artDownscaleWidth: 512,
      artDownscaleHeight: 512,
    ),
  );
  MediaSessionCoordinator.instance.attachHandler(audioHandler);

  // Restore user library from the on-device backup (survives uninstall).
  await LocalBackupService.instance.restoreIfNeeded();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Request permissions (non-blocking to avoid hot restart issues).
  // The notification status is logged because Android 13+ silently hides
  // the media notification when it is denied — this line is the fastest
  // way to diagnose "no notification" from a debug log.
  // ignore: body_might_complete_normally_catch_error
  PermissionService.requestAllPermissions()
      .then((results) {
        final notif = results[Permission.notification];
        debugPrint(
          'Prism permissions: notification=$notif '
          '(denied/permanentlyDenied = no media notification on Android 13+)',
        );
      })
      .catchError((_) {});

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
