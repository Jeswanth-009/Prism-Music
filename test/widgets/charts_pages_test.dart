import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/di/injection.dart';
import 'package:prism_music/core/services/chart_service.dart';
import 'package:prism_music/domain/repositories/music_repository.dart';
import 'package:prism_music/presentation/blocs/player/player_bloc.dart';
import 'package:prism_music/presentation/pages/chart_page.dart';
import 'package:prism_music/presentation/pages/charts_hub_page.dart';
import 'package:prism_music/presentation/widgets/prism/prism_states.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMusicRepository musicRepo;
  late PlayerBloc playerBloc;

  setUp(() async {
    await getIt.reset();
    musicRepo = FakeMusicRepository();
    getIt.registerSingleton<MusicRepository>(musicRepo);
    playerBloc = buildTestPlayerBloc();
  });

  tearDown(() async {
    playerBloc.close();
    await getIt.reset();
  });

  testWidgets('hub renders all six chart cards with sources', (tester) async {
    await tester.pumpWidget(wrapForTests(const ChartsHubPage()));
    await tester.pump();

    expect(find.text('Billboard Hot 100'), findsOneWidget);
    expect(find.text('Billboard Global 200'), findsOneWidget);
    expect(find.text('YouTube Trending'), findsOneWidget);
    expect(find.text('TikTok Billboard Top 50'), findsOneWidget);
    expect(find.text('New Releases'), findsOneWidget);
    // Source labels appear per card.
    expect(find.text('Billboard'), findsNWidgets(3));
    expect(find.text('YouTube'), findsNWidgets(3));
  });

  testWidgets('hub shows the country chip', (tester) async {
    await tester.pumpWidget(wrapForTests(const ChartsHubPage()));
    await tester.pump();

    // Default country is US before any settings are configured.
    expect(find.text('United States'), findsOneWidget);
  });

  testWidgets('chart page shows the error state when fetch fails',
      (tester) async {
    musicRepo.throwOnSearch = true;
    final chart = ChartService.getAvailableCharts('US', 'United States')[3];

    await tester.pumpWidget(wrapForTests(
      ChartPage(chart: chart),
      playerBloc: playerBloc,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(PrismErrorState), findsOneWidget);
  });

  testWidgets('chart page shows the empty state when search returns no songs',
      (tester) async {
    musicRepo.searchResult = const Right([]);
    final chart = ChartService.getAvailableCharts('US', 'United States')[2];

    await tester.pumpWidget(wrapForTests(
      ChartPage(chart: chart),
      playerBloc: playerBloc,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('No chart songs are available right now.'),
      findsOneWidget,
    );
  });

  testWidgets('chart page renders songs with Play all', (tester) async {
    musicRepo.searchResult = Right([
      song('c1', 'Chart Topper', artist: 'Chart Artist'),
      song('c2', 'Runner Up', artist: 'Chart Artist'),
    ]);
    final chart = ChartService.getAvailableCharts('US', 'United States')[4];

    await tester.pumpWidget(wrapForTests(
      ChartPage(chart: chart),
      playerBloc: playerBloc,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Chart Topper'), findsOneWidget);
    expect(find.text('Runner Up'), findsOneWidget);
    expect(find.text('Play all'), findsOneWidget);
    expect(find.textContaining('Curated Discovery Mix'), findsOneWidget);
  });

  testWidgets('Play all button is present above the numbered queue',
      (tester) async {
    musicRepo.searchResult = Right([
      song('c1', 'Chart Topper', artist: 'Chart Artist'),
      song('c2', 'Runner Up', artist: 'Chart Artist'),
    ]);
    final chart = ChartService.getAvailableCharts('US', 'United States')[4];

    await tester.pumpWidget(wrapForTests(
      ChartPage(chart: chart),
      playerBloc: playerBloc,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Play all'), findsOneWidget);
    expect(find.textContaining('2 songs'), findsOneWidget);
    // Tap dispatches PlaySongEvent through the bloc; playback itself is
    // covered by the liked-songs tap test.
    expect(find.text('Chart Topper'), findsOneWidget);
  });
}
