import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';
import 'package:prism_music/presentation/pages/player_page.dart';
import 'package:prism_music/presentation/widgets/player/mini_player.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the empty state when nothing is playing',
      (tester) async {
    await pumpTestWidget(tester, const PlayerPage());
    await tester.pump();

    expect(find.text('No song playing'), findsOneWidget);
  });

  testWidgets('renders the current song with playback controls',
      (tester) async {
    final playerBloc = buildTestPlayerBloc();
    addTearDown(playerBloc.close);
    // Bare song (no artwork URL) so color extraction is skipped entirely.
    playerBloc.emit(const PlayerState(
      status: PlayerStatus.playing,
      currentSong: Song(
        id: 'now1',
        title: 'Now Playing Song',
        artist: 'Now Artist',
        duration: Duration(seconds: 200),
        thumbnails: Thumbnails(),
      ),
    ));

    await pumpTestWidget(
      tester,
      const PlayerPage(),
      playerBloc: playerBloc,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Now Playing Song'), findsOneWidget);
  });

  testWidgets(
      'renders audio provenance badge with truthful info and opens details sheet on tap',
      (tester) async {
    final playerBloc = buildTestPlayerBloc();
    addTearDown(playerBloc.close);

    playerBloc.emit(const PlayerState(
      status: PlayerStatus.playing,
      currentSong: Song(
        id: 'provenance1',
        title: 'Provenance Song',
        artist: 'Prism Artist',
        duration: Duration(seconds: 180),
        thumbnails: Thumbnails(),
      ),
      currentStreamInfo: StreamInfo(
        url: 'https://example.com/stream.mp4',
        codec: 'mp4a',
        bitrate: 320,
        container: 'mp4',
        quality: AudioQuality.high,
        streamProvenance: 'jiosaavn_matched',
        matchConfidence: 0.94,
      ),
    ));

    await pumpTestWidget(
      tester,
      const PlayerPage(),
      playerBloc: playerBloc,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Provenance Song'), findsOneWidget);
    expect(find.text('JioSaavn'), findsOneWidget);
    expect(find.text('320 kbps · MP4A'), findsOneWidget);
    expect(find.text('94%'), findsOneWidget);

    // Tap provenance badge to open diagnostics sheet
    await tester.tap(find.text('JioSaavn'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Audio Stream Diagnostics'), findsOneWidget);
    expect(find.text('Resolution Source'), findsOneWidget);
    expect(find.text('94% Verified'), findsOneWidget);
    expect(find.text('Switch to YouTube Audio'), findsOneWidget);
    expect(find.text('Reload Fresh Stream'), findsOneWidget);
  });

  testWidgets('shows visible error banner and retry action when in error state',
      (tester) async {
    final playerBloc = buildTestPlayerBloc();
    addTearDown(playerBloc.close);

    playerBloc.emit(const PlayerState(
      status: PlayerStatus.error,
      errorMessage: 'Network timeout loading audio stream',
      currentSong: Song(
        id: 'err1',
        title: 'Error Song',
        artist: 'Artist',
        duration: Duration(seconds: 180),
        thumbnails: Thumbnails(),
      ),
    ));

    await pumpTestWidget(
      tester,
      const PlayerPage(),
      playerBloc: playerBloc,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Network timeout loading audio stream'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('mini player renders error message and retry button in error state',
      (tester) async {
    final playerBloc = buildTestPlayerBloc();
    addTearDown(playerBloc.close);

    playerBloc.emit(const PlayerState(
      status: PlayerStatus.error,
      errorMessage: 'Audio stream failed',
      currentSong: Song(
        id: 'err1',
        title: 'Error Song',
        artist: 'Artist',
        duration: Duration(seconds: 180),
        thumbnails: Thumbnails(),
      ),
    ));

    await pumpTestWidget(
      tester,
      const Scaffold(bottomNavigationBar: MiniPlayer()),
      playerBloc: playerBloc,
    );
    await tester.pump();

    expect(find.text('Audio stream failed'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });
}
