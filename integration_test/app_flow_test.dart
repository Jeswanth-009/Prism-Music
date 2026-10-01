import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:prism_music/main.dart' as app;
import 'package:prism_music/presentation/blocs/player/player_bloc.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';
import 'package:prism_music/presentation/pages/home_page.dart';
import 'package:prism_music/presentation/pages/player_page.dart';
import 'package:prism_music/presentation/widgets/player/mini_player.dart';

/// End-to-end flow: search → play → background → notification metadata →
/// next track.
///
/// Runs against the REAL app (real services, real network) on a device or
/// emulator — NOT part of `flutter test` / CI. Run with:
///
///   flutter test integration_test/app_flow_test.dart
///
/// (a booted Android emulator/device with internet access is required).
///
/// What each step asserts:
///  1. The app boots into the home page.
///  2. Typing a query surfaces song results.
///  3. Tapping the first result moves PlayerBloc to `playing` with audio
///     position advancing (real audio on the device).
///  4. Backgrounding the app (lifecycle pause) keeps playback alive and
///     the media notification's metadata reflects the current song —
///     verified through the player bloc's currentSong, which drives the
///     audio_service notification.
///  5. Skipping to the next track loads and plays a different song.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<PlayerBloc> playerBloc(WidgetTester tester) async {
    final context = tester.element(find.byType(HomePage));
    return context.read<PlayerBloc>();
  }

  testWidgets('search → play → background → notification → next track',
      (tester) async {
    // 1. Boot the real app.
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    // First launch may show onboarding; complete it if present.
    if (find.byType(TextField).evaluate().isEmpty) {
      // Give the home tab time to settle.
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
    expect(find.byType(HomePage), findsOneWidget);

    // 2. Search: switch to the Search tab and enter a query.
    // The bottom nav exposes the search destination via an icon; find the
    // TextField after switching.
    final searchIconFinder = find.byIcon(Icons.search_rounded);
    expect(searchIconFinder, findsWidgets);
    await tester.tap(searchIconFinder.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.enterText(find.byType(TextField).first, 'ed sheeran shape of you');
    // Submit via the keyboard search action.
    await tester.testTextInput.receiveAction(TextInputAction.search);
    // Debounce + network search.
    await tester.pumpAndSettle(const Duration(seconds: 6));

    // 3. Play the first result.
    final firstResult = find.textContaining('Shape of You').first;
    expect(firstResult, findsWidgets, reason: 'search should surface results');
    await tester.tap(firstResult);
    // Give resolve + buffering a generous window (real network).
    await tester.pumpAndSettle(const Duration(seconds: 12));

    final bloc = await playerBloc(tester);
    expect(bloc.state.status, PlayerStatus.playing,
        reason: 'audio should be playing after tapping a result');
    expect(bloc.state.currentSong, isNotNull);

    // Position advances with real playback.
    final positionBefore = bloc.state.position;
    await Future<void>.delayed(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(
      bloc.state.position.inMilliseconds,
      greaterThan(positionBefore.inMilliseconds),
      reason: 'playback position should advance',
    );

    // 4. Background the app — playback must continue (audio_service keeps
    // the foreground notification alive).
    tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(seconds: 2));
    tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(bloc.state.status, PlayerStatus.playing,
        reason: 'playback must survive backgrounding');
    // The media notification metadata mirrors currentSong.
    expect(bloc.state.currentSong!.title, isNotEmpty);

    // Mini player reflects the playing song.
    expect(find.byType(MiniPlayer), findsOneWidget);

    // 5. Next track.
    final songBefore = bloc.state.currentSong!.id;
    final nextButton = find.byIcon(Icons.skip_next_rounded);
    expect(nextButton, findsOneWidget);
    await tester.tap(nextButton);
    await tester.pumpAndSettle(const Duration(seconds: 12));

    expect(bloc.state.status, PlayerStatus.playing,
        reason: 'next track should start playing');
    expect(
      bloc.state.currentSong!.id,
      isNot(songBefore),
      reason: 'next track should be a different song',
    );

    // Open the full player once to confirm the page renders with the song.
    await tester.tap(find.byType(MiniPlayer));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byType(PlayerPage), findsOneWidget);
  });
}
