import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:prism_music/core/error/failures.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/domain/repositories/music_repository.dart';
import 'package:prism_music/presentation/blocs/search/search_bloc.dart';
import 'package:prism_music/presentation/blocs/search/search_event.dart';
import 'package:prism_music/presentation/blocs/search/search_state.dart';

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

  group('history', () {
    test('loads on creation, newest first', () async {
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(bloc.state.history, hasLength(2));
      expect(bloc.state.history.first, 'newer query');
      expect(bloc.state.historyEntries.first['id'], 'h2');
    });

    test('RemoveFromHistoryEvent drops the entry from state and storage',
        () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.historyEntries, hasLength(2));

      bloc.add(const RemoveFromHistoryEvent('h2'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.historyEntries, hasLength(1));
      expect(localDataSource.historyRows.containsKey('h2'), isFalse);
    });

    test('ClearHistoryEvent wipes state and storage', () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bloc.add(const ClearHistoryEvent());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.history, isEmpty);
      expect(bloc.state.historyEntries, isEmpty);
      expect(localDataSource.historyRows, isEmpty);
    });
  });

  group('SearchQueryEvent', () {
    test('short queries short-circuit to initial without searching',
        () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bloc.add(const SearchQueryEvent(query: 'a', filter: SearchFilter.songs));
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(bloc.state.status, SearchStatus.initial);
      expect(musicRepo.searchSongsCallCount, 0);
    });

    test('debounces rapid keystrokes to the final query', () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));

      for (final query in const ['fa', 'fad', 'fade', 'faded']) {
        bloc.add(SearchQueryEvent(query: query, filter: SearchFilter.songs));
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(musicRepo.searchSongsCallCount, 1);
      expect(musicRepo.lastSearchQuery, 'faded');
      expect(bloc.state.query, 'faded');
    });

    test('song search success emits results and records history', () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      musicRepo.searchResult = Right([song('s1', 'Fade To Black')]);

      bloc.add(const SearchQueryEvent(
        query: 'fade to black',
        filter: SearchFilter.songs,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(bloc.state.status, SearchStatus.success);
      expect(bloc.state.results.songs.single.id, 's1');
      expect(
        localDataSource.historyRows.values.contains('fade to black'),
        isTrue,
      );
      expect(bloc.state.history.first, 'fade to black');
    });

    test('repository failure surfaces the error message', () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      musicRepo.searchResult =
          const Left(SearchFailure(message: 'network down'));

      bloc.add(const SearchQueryEvent(
        query: 'anything',
        filter: SearchFilter.songs,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(bloc.state.status, SearchStatus.error);
      expect(bloc.state.errorMessage, 'network down');
    });

    test('universal filter routes through searchAll', () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      musicRepo.searchAllResult = Right(
        SearchResults(songs: [song('s1', 'Universal Hit')]),
      );

      bloc.add(const SearchQueryEvent(query: 'universal hit'));
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(bloc.state.status, SearchStatus.success);
      expect(bloc.state.results.songs.single.title, 'Universal Hit');
    });
  });

  group('UpdateFilterEvent', () {
    test('with no active query just updates the filter', () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bloc.add(const UpdateFilterEvent(SearchFilter.albums));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.filter, SearchFilter.albums);
      expect(musicRepo.searchSongsCallCount, 0);
    });

    test('with an active query re-runs the search under the new filter',
        () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      musicRepo.searchResult = Right([song('a1', 'Artist Song')]);
      musicRepo.artistsResult = const Right([]);

      bloc.add(const SearchQueryEvent(
        query: 'imagine',
        filter: SearchFilter.songs,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(bloc.state.results.songs.single.id, 'a1');

      musicRepo.artistsResult = Right([Artist(id: 'ar1', name: 'Imagine Fan')]);
      bloc.add(const UpdateFilterEvent(SearchFilter.artists));
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(bloc.state.filter, SearchFilter.artists);
      expect(bloc.state.status, SearchStatus.success);
      expect(bloc.state.results.artists.single.id, 'ar1');
    });
  });

  group('ClearSearchEvent', () {
    test('results and query reset, filter and history survive', () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      musicRepo.searchAllResult = Right(
        SearchResults(songs: [song('s1', 'Result')]),
      );

      bloc.add(const SearchQueryEvent(query: 'query one'));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(bloc.state.results.songs, isNotEmpty);

      bloc.add(const ClearSearchEvent());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.query, isEmpty);
      expect(bloc.state.results.songs, isEmpty);
      expect(bloc.state.status, SearchStatus.initial);
      expect(bloc.state.history, isNotEmpty);
    });
  });

  group('FetchSuggestionsEvent', () {
    test('empty query shows recent history entries', () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bloc.add(const FetchSuggestionsEvent(''));
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(bloc.state.historyEntries, hasLength(2));
    });

    test('long query fetches entity suggestions from the repository',
        () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      musicRepo.searchAllResult = Right(
        SearchResults(songs: [song('s1', 'Suggested Song')]),
      );

      bloc.add(const FetchSuggestionsEvent('suggested'));
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(bloc.state.entitySuggestions, isNotEmpty);
      expect(bloc.state.entitySuggestions.first.title, 'Suggested Song');
    });
  });

  group('LoadMoreResultsEvent', () {
    test('is a safe no-op while pagination is unimplemented', () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bloc.add(const LoadMoreResultsEvent());
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(bloc.state.status, isNot(SearchStatus.loadingMore));
      expect(bloc.state.hasMore, isFalse);
    });
  });
}
