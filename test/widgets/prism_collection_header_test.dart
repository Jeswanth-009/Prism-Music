import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/presentation/widgets/prism/prism_collection_header.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders title, badge, and metadata correctly', (tester) async {
    await tester.pumpWidget(wrapForTests(
      const PrismCollectionHeader(
        title: 'Best of Indie',
        badge: 'Playlist',
        subtitle: 'Curated indie gems',
        metadata: '25 songs · 1 hr 20 min',
      ),
    ));
    await tester.pump();

    expect(find.text('Best of Indie'), findsOneWidget);
    expect(find.text('PLAYLIST'), findsOneWidget);
    expect(find.text('Curated indie gems'), findsOneWidget);
    expect(find.text('25 songs · 1 hr 20 min'), findsOneWidget);
  });

  testWidgets('triggers onPlayAll and onShuffle callbacks', (tester) async {
    var playAllTapped = false;
    var shuffleTapped = false;

    await tester.pumpWidget(wrapForTests(
      PrismCollectionHeader(
        title: 'Summer Hits',
        onPlayAll: () => playAllTapped = true,
        onShuffle: () => shuffleTapped = true,
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Play all'));
    await tester.pump();
    expect(playAllTapped, isTrue);

    await tester.tap(find.byTooltip('Shuffle collection'));
    await tester.pump();
    expect(shuffleTapped, isTrue);
  });
}
