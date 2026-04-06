import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';
import '../../../data/datasources/local/local_datasource.dart';
import '../../../domain/repositories/repositories.dart';
import 'search_event.dart';
import 'search_state.dart';

/// Custom event transformer for debouncing
EventTransformer<E> _debounce<E>(Duration duration) {
  return (events, mapper) => events.debounceTime(duration).asyncExpand(mapper);
}

/// BLoC for managing search functionality
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final MusicRepository _musicRepository;
  final LocalDataSource _localDataSource;

  int _debounceToken = 0;
  int _requestToken = 0;

  SearchBloc({
    required MusicRepository musicRepository,
    required LocalDataSource localDataSource,
  })  : _musicRepository = musicRepository,
        _localDataSource = localDataSource,
        super(const SearchState()) {
    on<SearchQueryEvent>(_onSearchQuery);
    on<ClearSearchEvent>(_onClearSearch);
    on<LoadMoreResultsEvent>(_onLoadMoreResults);
    on<UpdateFilterEvent>(_onUpdateFilter);
    on<AddToHistoryEvent>(_onAddToHistory);
    on<ClearHistoryEvent>(_onClearHistory);
    on<RemoveFromHistoryEvent>(_onRemoveFromHistory);
    on<LoadSearchHistoryEvent>(_onLoadSearchHistory);
    // Use debounce transformer for suggestions to avoid excessive API calls
    on<FetchSuggestionsEvent>(
      _onFetchSuggestions,
      transformer: _debounce(const Duration(milliseconds: 350)),
    );

    // Load search history on init
    add(const LoadSearchHistoryEvent());
  }

  Future<void> _onSearchQuery(
    SearchQueryEvent event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query.trim();
    Logger.root.info('SearchBloc: _onSearchQuery("$query")');
    if (query.length < 2) {
      emit(state.copyWith(
        status: SearchStatus.initial,
        query: '',
        results: const SearchResults(),
        entitySuggestions: [],
      ));
      return;
    }

    final debounceId = ++_debounceToken;

    // Wait for debounce window; bail if a newer event arrived
    await Future.delayed(const Duration(milliseconds: 280));
    if (debounceId != _debounceToken) return;

    // If same query/filter already in progress, skip duplicate
    if (state.query == query && state.filter == event.filter && state.isLoading) {
      return;
    }

    final requestId = ++_requestToken;

    emit(state.copyWith(
      status: SearchStatus.loading,
      query: query,
      filter: event.filter,
      errorMessage: null,
    ));

    try {
      // Route to specific search methods based on active filter for better relevance
      switch (event.filter) {
        case SearchFilter.songs:
          Logger.root.info(
            'SearchBloc: searchSongs("$query") filter=${event.filter}',
          );
          final result = await _musicRepository.searchSongs(query, limit: 30);
          if (requestId != _requestToken || emit.isDone) return;
          result.fold(
            (failure) {
              if (emit.isDone) return;
              emit(state.copyWith(
                status: SearchStatus.error,
                errorMessage: failure.message,
              ));
            },
            (songs) {
              if (emit.isDone) return;
              emit(state.copyWith(
                status: SearchStatus.success,
                results: SearchResults(songs: songs),
                hasMore: false,
                entitySuggestions: [],
              ));
              add(AddToHistoryEvent(query));
            },
          );
          break;
        case SearchFilter.artists:
          final result = await _musicRepository.searchArtists(query, limit: 30);
          if (requestId != _requestToken || emit.isDone) return;
          result.fold(
            (failure) {
              if (emit.isDone) return;
              emit(state.copyWith(
                status: SearchStatus.error,
                errorMessage: failure.message,
              ));
            },
            (artists) {
              if (emit.isDone) return;
              emit(state.copyWith(
                status: SearchStatus.success,
                results: SearchResults(artists: artists),
                hasMore: false,
                entitySuggestions: [],
              ));
              add(AddToHistoryEvent(query));
            },
          );
          break;
        case SearchFilter.albums:
          final result = await _musicRepository.searchAlbums(query, limit: 30);
          if (requestId != _requestToken || emit.isDone) return;
          result.fold(
            (failure) {
              if (emit.isDone) return;
              emit(state.copyWith(
                status: SearchStatus.error,
                errorMessage: failure.message,
              ));
            },
            (albums) {
              if (emit.isDone) return;
              emit(state.copyWith(
                status: SearchStatus.success,
                results: SearchResults(albums: albums),
                hasMore: false,
                entitySuggestions: [],
              ));
              add(AddToHistoryEvent(query));
            },
          );
          break;
        case SearchFilter.playlists:
          final result = await _musicRepository.searchPlaylists(query, limit: 30);
          if (requestId != _requestToken || emit.isDone) return;
          result.fold(
            (failure) {
              if (emit.isDone) return;
              emit(state.copyWith(
                status: SearchStatus.error,
                errorMessage: failure.message,
              ));
            },
            (playlists) {
              if (emit.isDone) return;
              emit(state.copyWith(
                status: SearchStatus.success,
                results: SearchResults(playlists: playlists),
                hasMore: false,
                entitySuggestions: [],
              ));
              add(AddToHistoryEvent(query));
            },
          );
          break;
        case SearchFilter.all:
          Logger.root.info(
            'SearchBloc: searchAll("$query") filter=${event.filter}',
          );
          final result = await _musicRepository.searchAll(query, limit: 30);
          if (requestId != _requestToken || emit.isDone) return;
          result.fold(
            (failure) {
              if (emit.isDone) return;
              emit(state.copyWith(
                status: SearchStatus.error,
                errorMessage: failure.message,
              ));
            },
            (searchResults) {
              if (emit.isDone) return;
              emit(state.copyWith(
                status: SearchStatus.success,
                results: searchResults,
                hasMore: false,
                entitySuggestions: [],
              ));
              add(AddToHistoryEvent(query));
            },
          );
          break;
      }
    } catch (e) {
      if (requestId != _requestToken || emit.isDone) return;
      emit(state.copyWith(
        status: SearchStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onClearSearch(
    ClearSearchEvent event,
    Emitter<SearchState> emit,
  ) {
    emit(SearchState(
      history: state.history,
      historyEntries: state.historyEntries,
    ));
  }

  Future<void> _onLoadMoreResults(
    LoadMoreResultsEvent event,
    Emitter<SearchState> emit,
  ) async {
    if (!state.hasMore || state.isLoading) return;

    emit(state.copyWith(status: SearchStatus.loadingMore));

    // TODO: Implement pagination
    // For now, just mark as no more results
    emit(state.copyWith(
      status: SearchStatus.success,
      hasMore: false,
    ));
  }

  Future<void> _onUpdateFilter(
    UpdateFilterEvent event,
    Emitter<SearchState> emit,
  ) async {
    if (state.query.isNotEmpty) {
      add(SearchQueryEvent(query: state.query, filter: event.filter));
    } else {
      emit(state.copyWith(filter: event.filter));
    }
  }

  Future<void> _onAddToHistory(
    AddToHistoryEvent event,
    Emitter<SearchState> emit,
  ) async {
    if (event.query.trim().isEmpty) return;

    try {
      // Save to persistent storage
      await _localDataSource.addSearchHistory(event.query);

      // Reload history to reflect changes
      final historyEntries = await _localDataSource.getSearchHistory(limit: 20);

      // Also update legacy history list
      final updatedHistory = [
        event.query,
        ...state.history.where((q) => q.toLowerCase() != event.query.toLowerCase()),
      ].take(10).toList();

      emit(state.copyWith(
        history: updatedHistory,
        historyEntries: historyEntries,
      ));
    } catch (e) {
      debugPrint('SearchBloc: Error saving search history: $e');
    }
  }

  Future<void> _onClearHistory(
    ClearHistoryEvent event,
    Emitter<SearchState> emit,
  ) async {
    try {
      await _localDataSource.clearSearchHistory();
      emit(state.copyWith(
        history: [],
        historyEntries: [],
      ));
    } catch (e) {
      debugPrint('SearchBloc: Error clearing search history: $e');
    }
  }

  Future<void> _onRemoveFromHistory(
    RemoveFromHistoryEvent event,
    Emitter<SearchState> emit,
  ) async {
    try {
      await _localDataSource.removeSearchHistory(event.id);

      // Remove from current state
      final updatedEntries = state.historyEntries
          .where((entry) => entry['id'] != event.id)
          .toList();

      emit(state.copyWith(historyEntries: updatedEntries));
    } catch (e) {
      debugPrint('SearchBloc: Error removing search history: $e');
    }
  }

  Future<void> _onLoadSearchHistory(
    LoadSearchHistoryEvent event,
    Emitter<SearchState> emit,
  ) async {
    try {
      final historyEntries = await _localDataSource.getSearchHistory(limit: 20);
      final history = historyEntries.map((e) => e['query'] ?? '').where((q) => q.isNotEmpty).toList();

      emit(state.copyWith(
        historyEntries: historyEntries,
        history: history,
      ));
    } catch (e) {
      debugPrint('SearchBloc: Error loading search history: $e');
    }
  }

  Future<void> _onFetchSuggestions(
    FetchSuggestionsEvent event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query.trim();

    // If query is empty, show recent history
    if (query.isEmpty) {
      try {
        final historyEntries = await _localDataSource.getSearchHistory(limit: 10);
        emit(state.copyWith(
          historyEntries: historyEntries,
          entitySuggestions: [],
        ));
      } catch (e) {
        debugPrint('SearchBloc: Error loading history for suggestions: $e');
      }
      return;
    }

    // If query is too short, just show matching history
    if (query.length < 2) {
      try {
        final pastSearches = await _localDataSource.getSimilarSearches(query, limit: 5);
        emit(state.copyWith(
          historyEntries: pastSearches,
          entitySuggestions: [],
        ));
      } catch (e) {
        debugPrint('SearchBloc: Error loading similar searches: $e');
      }
      return;
    }

    try {
      // Fetch in parallel: past searches + entity suggestions from repository search
      final results = await Future.wait([
        _localDataSource.getSimilarSearches(query, limit: 3),
        _fetchEntitySuggestions(query),
      ]);

      final pastSearches = results[0] as List<Map<String, String>>;
      final entitySuggestions = results[1] as List<EntitySuggestion>;

      emit(state.copyWith(
        historyEntries: pastSearches,
        entitySuggestions: entitySuggestions,
      ));
    } catch (e) {
      debugPrint('SearchBloc: Error fetching suggestions: $e');
    }
  }

  /// Fetch entity suggestions (songs, artists, albums) from search API
  Future<List<EntitySuggestion>> _fetchEntitySuggestions(String query) async {
    final suggestions = <EntitySuggestion>[];

    try {
      // Use repository-backed universal search for suggestions.
      final result = await _musicRepository.searchAll(query, limit: 5);

      result.fold(
        (failure) {
          debugPrint('SearchBloc: Entity suggestion fetch failed: ${failure.message}');
        },
        (searchResults) {
          // Add top songs as suggestions
          for (final song in searchResults.songs.take(3)) {
            suggestions.add(EntitySuggestion(
              id: song.playableId,
              title: song.title,
              subtitle: song.artist,
              imageUrl: song.thumbnailUrl,
              type: EntityType.song,
            ));
          }

          // Add top artists as suggestions
          for (final artist in searchResults.artists.take(2)) {
            suggestions.add(EntitySuggestion(
              id: artist.id,
              title: artist.name,
              subtitle: 'Artist',
              imageUrl: artist.thumbnailUrl,
              type: EntityType.artist,
            ));
          }

          // Add top albums as suggestions
          for (final album in searchResults.albums.take(2)) {
            suggestions.add(EntitySuggestion(
              id: album.id,
              title: album.title,
              subtitle: album.artist,
              imageUrl: album.thumbnailUrl,
              type: EntityType.album,
            ));
          }
        },
      );
    } catch (e) {
      debugPrint('SearchBloc: Error fetching entity suggestions: $e');
    }

    return suggestions;
  }
}
