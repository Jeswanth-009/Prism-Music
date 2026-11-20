import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/domain/repositories/music_repository.dart';
import 'package:prism_music/presentation/blocs/search/search_bloc.dart';
import 'package:prism_music/presentation/blocs/search/search_event.dart';
import 'package:prism_music/presentation/blocs/search/search_state.dart';
import 'package:prism_music/presentation/pages/search_page.dart';

import '../../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ensureWidgetTestHive();
  });

  late FakeMusicRepository musicRepo;
  late FakeLocalDataSource localDataSource;
  late SearchBloc bloc;

  setUp(() {
    musicRepo = FakeMusicRepository();
    localDataSource = FakeLocalDataSource();
    bloc = SearchBloc(
      musicRepository: musicRepo,
      localDataSource: localDataSource,
    );
  });

  tearDown(() => bloc.close());

  testWidgets(
      'renders category-tailored empty states with Switch to All when other results exist',
      (tester) async {
    // Bundle contains 1 artist but 0 songs
    bloc.emit(
      const SearchState(
        status: SearchStatus.success,
        query: 'coldplay',
        filter: SearchFilter.songs,
        results: SearchResults(
          songs: [],
          artists: [
            Artist(id: 'a1', name: 'Coldplay'),
          ],
        ),
      ),
    );

    await pumpTestWidget(
      tester,
      const SearchPage(embedded: true),
      searchBloc: bloc,
      size: const Size(600, 900),
    );
    await tester.pump();

    // Songs empty state with category icon and switch action
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    expect(find.text('No songs found'), findsOneWidget);
    expect(find.text('Switch to All'), findsOneWidget);

    // Switch to Albums filter tab
    bloc.emit(
      const SearchState(
        status: SearchStatus.success,
        query: 'coldplay',
        filter: SearchFilter.albums,
        results: SearchResults(
          songs: [],
          albums: [],
          artists: [
            Artist(id: 'a1', name: 'Coldplay'),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.album_rounded), findsOneWidget);
    expect(find.text('No albums found'), findsOneWidget);
    expect(find.text('Switch to All'), findsOneWidget);

    // Switch to Playlists filter tab
    bloc.emit(
      const SearchState(
        status: SearchStatus.success,
        query: 'coldplay',
        filter: SearchFilter.playlists,
        results: SearchResults(
          songs: [],
          playlists: [],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);
    expect(find.text('No playlists found'), findsOneWidget);
    // When completely empty, offers Clear Search
    expect(find.text('Clear Search'), findsOneWidget);
  });
}
