import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/presentation/widgets/prism/prism_song_tile.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders title and artist', (tester) async {
    await tester.pumpWidget(wrapForTests(
      PrismSongTile(
        song: song('t1', 'Nightcall', artist: 'Kavinsky'),
        onTap: () {},
      ),
    ));
    await tester.pump();

    expect(find.text('Nightcall'), findsOneWidget);
    expect(find.text('Kavinsky'), findsOneWidget);
  });

  testWidgets('shows the index number when numbered', (tester) async {
    await tester.pumpWidget(wrapForTests(
      PrismSongTile(
        song: song('t1', 'Nightcall'),
        index: 6,
        numbered: true,
        onTap: () {},
      ),
    ));
    await tester.pump();

    expect(find.text('7'), findsOneWidget,
        reason: 'indexes are displayed 1-based');
  });

  testWidgets('tap fires the onTap callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrapForTests(
      PrismSongTile(
        song: song('t1', 'Nightcall'),
        onTap: () => tapped = true,
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Nightcall'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
