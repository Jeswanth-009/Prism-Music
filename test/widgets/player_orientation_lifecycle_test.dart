import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';
import 'package:prism_music/presentation/pages/player_page.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PlayerPage unlocks landscape on init and restores portrait on dispose', (tester) async {
    final orientations = <List<DeviceOrientation>>[];

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'SystemChrome.setPreferredOrientations') {
          final list = (methodCall.arguments as List<dynamic>)
              .map((e) => DeviceOrientation.values.firstWhere((v) => v.toString() == e))
              .toList();
          orientations.add(list);
          return null;
        }
        return null;
      },
    );

    final playerBloc = buildTestPlayerBloc();
    addTearDown(playerBloc.close);
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
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PlayerPage()),
            );
          },
          child: const Text('Open Player'),
        ),
      ),
      playerBloc: playerBloc,
    );

    // Initial state before opening
    expect(find.text('Open Player'), findsOneWidget);

    // Open PlayerPage
    await tester.tap(find.text('Open Player'));
    await tester.pumpAndSettle();

    // Verify orientations included all four orientations
    expect(orientations.isNotEmpty, isTrue);
    final lastSet = orientations.last;
    expect(lastSet.contains(DeviceOrientation.landscapeLeft), isTrue);
    expect(lastSet.contains(DeviceOrientation.landscapeRight), isTrue);

    // Pop PlayerPage
    Navigator.of(tester.element(find.byType(PlayerPage))).pop();
    await tester.pumpAndSettle();

    // Verify restored to portrait
    final afterPop = orientations.last;
    expect(afterPop, equals([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]));
  });
}
