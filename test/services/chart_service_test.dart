import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/di/injection.dart';
import 'package:prism_music/core/services/chart_service.dart';
import 'package:prism_music/domain/repositories/music_repository.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChartService.getAvailableCharts', () {
    test('returns six charts with unique ids', () {
      final charts = ChartService.getAvailableCharts('US', 'United States');
      expect(charts, hasLength(6));
      expect(charts.map((c) => c.id).toSet(), hasLength(6));
    });

    test('regional charts embed the country code', () {
      final charts = ChartService.getAvailableCharts('IN', 'India');
      final ids = charts.map((c) => c.id).toList();
      expect(ids, contains('youtube_trending_IN'));
      expect(ids, contains('youtube_top_music_IN'));
      // Billboard charts stay global regardless of region.
      expect(ids, contains('billboard_hot100'));
    });

    test('every definition carries a name, description and source', () {
      for (final chart
          in ChartService.getAvailableCharts('US', 'United States')) {
        expect(chart.name, isNotEmpty, reason: chart.id);
        expect(chart.description, isNotEmpty, reason: chart.id);
        expect(chart.source, isA<ChartSource>());
      }
    });
  });

  group('ChartService.getChartSongs', () {
    late FakeMusicRepository musicRepo;

    setUp(() async {
      await getIt.reset();
      musicRepo = FakeMusicRepository()
        ..searchResult = Right([song('c1', 'Chart Song')]);
      getIt.registerSingleton<MusicRepository>(musicRepo);
    });

    tearDown(() async {
      await getIt.reset();
    });

    test('serves a second request of the same chart from cache', () async {
      final chart =
          ChartService.getAvailableCharts('US', 'United States').first;

      final first = await ChartService.instance.getChartSongs(chart);
      expect(first, isNotEmpty);
      final callsAfterFirst = musicRepo.searchSongsCallCount;

      final second = await ChartService.instance.getChartSongs(chart);
      expect(second, hasLength(first.length));
      expect(musicRepo.searchSongsCallCount, callsAfterFirst,
          reason: 'second call must be served from cache');
    });

    test('a failed refresh still serves the previous cache', () async {
      final chart =
          ChartService.getAvailableCharts('US', 'United States').first;
      await ChartService.instance.getChartSongs(chart);

      musicRepo.throwOnSearch = true;
      final songs = await ChartService.instance.getChartSongs(chart);
      expect(songs, isNotEmpty, reason: 'stale cache beats an error');
    });

    test('propagates error when fetch fails with no cache', () async {
      // Use a chart no earlier test has fetched — the singleton cache
      // persists across tests in this file.
      final chart = ChartService.getAvailableCharts('US', 'United States').last;
      musicRepo.throwOnSearch = true;

      // The service rethrows search errors so caller can distinguish provider failure
      // from an empty chart.
      expect(
        () => ChartService.instance.getChartSongs(chart),
        throwsA(isA<Exception>()),
      );
    });
  });
}
