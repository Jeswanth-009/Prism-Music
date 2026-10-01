import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';
import 'package:prism_music/presentation/pages/player_page.dart';

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
}
