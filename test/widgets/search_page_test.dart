import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/presentation/blocs/search/search_bloc.dart';
import 'package:prism_music/presentation/blocs/search/search_event.dart';
import 'package:prism_music/presentation/pages/search_page.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('renders the search field and filter chips', (tester) async {
    await pumpTestWidget(
      tester,
      const SearchPage(embedded: true),
      searchBloc: bloc,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(TextField), findsOneWidget);
    // The chip row offers the per-type filters (no 'All' chip).
    expect(find.text('Songs'), findsOneWidget);
    expect(find.text('Artists'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);
  });

  testWidgets('renders search results for an active query', (tester) async {
    musicRepo.searchResult = Right([song('s1', 'Fade To Black')]);
    bloc.add(const SearchQueryEvent(
      query: 'fade to black',
      filter: SearchFilter.songs,
    ));

    await pumpTestWidget(
      tester,
      const SearchPage(embedded: true),
      searchBloc: bloc,
    );
    // The bloc debounces with real timers — let them fire outside the
    // fake-async zone, then flush the UI.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    expect(find.text('Fade To Black'), findsOneWidget);
  });

  testWidgets('filter chips update the active filter', (tester) async {
    await pumpTestWidget(
      tester,
      const SearchPage(embedded: true),
      searchBloc: bloc,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Artists'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(bloc.state.filter, SearchFilter.artists);
  });
}
