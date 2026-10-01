import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/presentation/blocs/library/library_bloc.dart';
import 'package:prism_music/presentation/blocs/library/library_event.dart';
import 'package:prism_music/presentation/pages/library_tab.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLibraryRepository libraryRepo;

  setUp(() {
    libraryRepo = FakeLibraryRepository();
  });

  LibraryBloc buildBloc() {
    final bloc = LibraryBloc(
      libraryRepository: libraryRepo,
      musicRepository: FakeMusicRepository(),
    );
    addTearDown(bloc.close);
    return bloc;
  }

  testWidgets('quick tiles show library counts', (tester) async {
    libraryRepo.likedSongs = [song('l1', 'A'), song('l2', 'B')];
    libraryRepo.downloads = [song('d1', 'C')];
    libraryRepo.recentlyPlayed = [song('r1', 'D')];
    final bloc = buildBloc()..add(const LoadLibraryEvent());

    await pumpTestWidget(
      tester,
      const LibraryTab(),
      size: const Size(400, 1600),
      libraryBloc: bloc,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('2 songs'), findsOneWidget);
    expect(find.text('1 songs'), findsNWidgets(2));
  });

  testWidgets('playlists grid renders names and source badges', (tester) async {
    libraryRepo.playlists = [
      playlist('p1', 'Comeback Comrade', spotifyPlaylistId: 'abc'),
      playlist('p2', 'Chill Mix', youtubePlaylistId: 'RD123'),
      playlist('p3', 'My Own'),
    ];
    final bloc = buildBloc()..add(const LoadLibraryEvent());

    await pumpTestWidget(
      tester,
      const LibraryTab(),
      size: const Size(400, 1600),
      libraryBloc: bloc,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Comeback Comrade'), findsOneWidget);
    expect(find.text('Chill Mix'), findsOneWidget);
    expect(find.text('My Own'), findsOneWidget);
    expect(find.text('Spotify'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
  });

  testWidgets('shows the empty state without playlists', (tester) async {
    final bloc = buildBloc()..add(const LoadLibraryEvent());

    await pumpTestWidget(
      tester,
      const LibraryTab(),
      size: const Size(400, 1600),
      libraryBloc: bloc,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('No playlists yet'), findsOneWidget);
  });
}
