import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/utils/cancellation_token.dart';
import 'package:prism_music/domain/entities/entities.dart';
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

  testWidgets(
      'ImportReviewSheet shows unmatched tracks and interactive match button',
      (tester) async {
    final unmatched = song('u1', 'Unmatched Song', artist: 'Artist X');
    final matched = song('m1', 'Matched Song', artist: 'Artist Y');
    final importResult = ImportPlaylistResult(
      playlist: playlist('p1', 'Imported Playlist', songs: [matched]),
      matchedTracks: [matched],
      unmatchedTracks: [unmatched],
      totalSourceTracks: 2,
    );

    final bloc = buildBloc();
    await pumpTestWidget(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => ImportReviewSheet(result: importResult),
          ),
          child: const Text('Open Sheet'),
        ),
      ),
      size: const Size(500, 800),
      libraryBloc: bloc,
    );
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Unmatched Tracks (1)'), findsOneWidget);
    expect(find.text('Unmatched Song'), findsOneWidget);
    expect(find.text('Match'), findsOneWidget);
    expect(find.text('Copy List'), findsOneWidget);
  });

  testWidgets('ImportProgressDialog cancels import when cancel button tapped',
      (tester) async {
    final token = ImportCancellationToken();
    var dismissed = false;
    final bloc = buildBloc();

    await pumpTestWidget(
      tester,
      ImportProgressDialog(
        cancelToken: token,
        onDismiss: () => dismissed = true,
      ),
      size: const Size(500, 600),
      libraryBloc: bloc,
    );
    await tester.pump();

    expect(find.text('Importing Playlist'), findsOneWidget);
    expect(find.text('Cancel Import'), findsOneWidget);

    await tester.tap(find.text('Cancel Import'));
    await tester.pump();

    expect(token.isCancelled, isTrue);
    expect(dismissed, isTrue);
  });
}
