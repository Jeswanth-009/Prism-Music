import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/presentation/blocs/library/library_bloc.dart';
import 'package:prism_music/presentation/blocs/library/library_event.dart';
import 'package:prism_music/presentation/pages/liked_songs_page.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLibraryRepository libraryRepo;

  setUp(() {
    libraryRepo = FakeLibraryRepository();
  });

  testWidgets('shows the empty state without liked songs', (tester) async {
    await tester.pumpWidget(wrapForTests(const LikedSongsPage()));
    await tester.pump();

    expect(find.text('Songs you love live here'), findsOneWidget);
  });

  testWidgets('renders liked songs from the bloc state', (tester) async {
    libraryRepo.likedSongs = [
      song('l1', 'First Like'),
      song('l2', 'Second Like'),
    ];
    final libraryBloc = LibraryBloc(
      libraryRepository: libraryRepo,
      musicRepository: FakeMusicRepository(),
    );
    addTearDown(libraryBloc.close);
    libraryBloc.add(const LoadLibraryEvent());

    await tester.pumpWidget(wrapForTests(
      const LikedSongsPage(),
      libraryBloc: libraryBloc,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('First Like'), findsOneWidget);
    expect(find.text('Second Like'), findsOneWidget);
  });

  testWidgets('tapping a song starts playback', (tester) async {
    final audio = FakeAudioPlayerService();
    libraryRepo.likedSongs = [song('l1', 'First Like')];

    final libraryBloc = LibraryBloc(
      libraryRepository: libraryRepo,
      musicRepository: FakeMusicRepository(),
    );
    addTearDown(libraryBloc.close);
    final playerBloc = buildTestPlayerBloc(audioPlayerService: audio);
    addTearDown(playerBloc.close);
    libraryBloc.add(const LoadLibraryEvent());

    await tester.pumpWidget(wrapForTests(
      const LikedSongsPage(),
      libraryBloc: libraryBloc,
      playerBloc: playerBloc,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('First Like'));
    await waitFor(() => audio.setUrls.isNotEmpty);
  });
}
