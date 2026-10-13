import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/di/injection.dart';
import 'package:prism_music/presentation/blocs/search/search_bloc.dart';
import 'package:prism_music/presentation/pages/charts_hub_page.dart';
import 'package:prism_music/presentation/pages/home_page.dart';
import 'package:prism_music/presentation/pages/home_tab.dart';
import 'package:prism_music/presentation/pages/library_tab.dart';
import 'package:prism_music/presentation/pages/search_page.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await getIt.reset();
    initTestHive('home_page');
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets(
      'HomePage mounts HomeTab initially and lazily mounts other tabs on selection',
      (tester) async {
    final musicRepo = FakeMusicRepository()
      ..trendingResult = const Right([])
      ..newReleasesResult = const Right([]);
    final searchBloc = SearchBloc(
      musicRepository: musicRepo,
      localDataSource: FakeLocalDataSource(),
    );
    addTearDown(searchBloc.close);

    registerTestGetIt(
      musicRepository: musicRepo,
      recommendationService: FakeRecommendationService(),
    );

    await pumpTestWidget(
      tester,
      const HomePage(),
      searchBloc: searchBloc,
    );
    await tester.pump();

    // HomeTab is initially mounted
    expect(find.byType(HomeTab), findsOneWidget);
    // Other tabs are not mounted yet
    expect(find.byType(SearchPage), findsNothing);
    expect(find.byType(ChartsHubPage), findsNothing);
    expect(find.byType(LibraryTab), findsNothing);

    // Tap Library tab
    await tester.tap(find.byTooltip('Library'));
    await tester.pump();

    // Library tab is now mounted
    expect(find.byType(LibraryTab), findsOneWidget);
    // Search & Charts are still not mounted
    expect(find.byType(SearchPage), findsNothing);
    expect(find.byType(ChartsHubPage), findsNothing);
  });
}
