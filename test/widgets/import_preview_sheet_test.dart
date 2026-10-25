import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/presentation/blocs/library/library_bloc.dart';
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

  testWidgets(
      'ImportReviewSheet displays confidence badges, filter chips, and uncertain matches',
      (tester) async {
    final songExact = song('m1', 'Exact Hit', artist: 'Artist One').copyWith(
      matchConfidence: 0.95,
    );
    final songUncertain = song('m2', 'Uncertain Live Song', artist: 'Artist Two').copyWith(
      matchConfidence: 0.60,
    );
    final songUnmatched = song('u1', 'Unmatched B-Side', artist: 'Artist Three');

    final importResult = ImportPlaylistResult(
      playlist: playlist(
        'p1',
        'Rock Anthems',
        songs: [songExact, songUncertain],
      ),
      matchedTracks: [songExact, songUncertain],
      unmatchedTracks: [songUnmatched],
      totalSourceTracks: 3,
      previewItems: [
        ImportPreviewItem.fromMatch(
          sourceTrack: songExact,
          matchedSong: songExact,
          confidence: 0.95,
        ),
        ImportPreviewItem.fromMatch(
          sourceTrack: songUncertain,
          matchedSong: songUncertain,
          confidence: 0.60,
        ),
        ImportPreviewItem.fromMatch(
          sourceTrack: songUnmatched,
          matchedSong: null,
          confidence: 0.0,
        ),
      ],
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
          child: const Text('Open Review Sheet'),
        ),
      ),
      size: const Size(500, 900),
      libraryBloc: bloc,
    );

    await tester.tap(find.text('Open Review Sheet'));
    await tester.pumpAndSettle();

    // Verify filter chips exist
    expect(find.text('All (3)'), findsOneWidget);
    expect(find.text('Uncertain (1)'), findsOneWidget);
    expect(find.text('Unmatched (1)'), findsOneWidget);

    // Verify confidence badges
    expect(find.text('Exact (95%)'), findsOneWidget);
    expect(find.text('Uncertain (60%)'), findsOneWidget);

    // Verify unmatched section and its buttons
    expect(find.text('Unmatched Tracks (1)'), findsOneWidget);
    expect(find.text('Unmatched B-Side'), findsOneWidget);
    expect(find.text('Match'), findsOneWidget);
    expect(find.text('Copy List'), findsOneWidget);

    // Filter to Uncertain
    await tester.tap(find.text('Uncertain (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Uncertain Matches (1)'), findsOneWidget);
    expect(find.text('Uncertain Live Song'), findsOneWidget);
    expect(find.text('Correct'), findsOneWidget);
  });
}
