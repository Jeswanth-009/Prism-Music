import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';
import '../../../core/utils/unicode_search_matcher.dart';
import '../../../data/datasources/local/local_datasource.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/repositories.dart';
import 'search_event.dart';
import 'search_state.dart';

/// Custom event transformer for restartable debouncing
EventTransformer<E> _restartableDebounce<E>(Duration duration) {
  return (events, mapper) => events.debounceTime(duration).switchMap(mapper);
}

/// BLoC for managing search functionality
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final MusicRepository _musicRepository;
  final LocalDataSource _localDataSource;
  int _searchGeneration = 0;

  SearchBloc({
    required MusicRepository musicRepository,
    required LocalDataSource localDataSource,
  })  : _musicRepository = musicRepository,
        _localDataSource = localDataSource,
        super(const SearchState()) {
    on<SearchQueryEvent>(
      _onSearchQuery,
      transformer: _restartableDebounce(const Duration(milliseconds: 300)),
    );
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
      transformer: _restartableDebounce(const Duration(milliseconds: 350)),
    );

    // Load search history on init
    add(const LoadSearchHistoryEvent());
  }

  Future<void> _onSearchQuery(
    SearchQueryEvent event,
    Emitter<SearchState> emit,
  ) async {
    final generation = ++_searchGeneration;
    final query = event.query.trim();
    Logger.root.info('SearchBloc: _onSearchQuery (queryLength=${query.length}) filter=${event.filter}');
    if (query.length < 2) {
      emit(state.copyWith(
        status: SearchStatus.initial,
        query: query,
        results: const SearchResults(),
        entitySuggestions: [],
        errorMessage: null,
      ));
      return;
    }

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
            'SearchBloc: searchSongs filter=${event.filter}',
          );
          final result = await _musicRepository.searchSongs(query, limit: 30);
          if (emit.isDone || generation != _searchGeneration) return;
          result.fold(
            (failure) {
              if (emit.isDone || generation != _searchGeneration) return;
              emit(state.copyWith(
                status: SearchStatus.error,
                errorMessage: failure.message,
              ));
            },
            (songs) {
              if (emit.isDone || generation != _searchGeneration) return;
              final rankedSongs = List<Song>.from(songs);
              rankedSongs.sort((a, b) {
                final scoreA = max(
                  UnicodeSearchMatcher.computeSimilarity(a.title, query),
                  UnicodeSearchMatcher.computeSimilarity(a.artist, query),
                );
                final scoreB = max(
                  UnicodeSearchMatcher.computeSimilarity(b.title, query),
                  UnicodeSearchMatcher.computeSimilarity(b.artist, query),
                );
                return scoreB.compareTo(scoreA);
              });
              emit(state.copyWith(
                status: SearchStatus.success,
                results: SearchResults(songs: rankedSongs),
                hasMore: songs.length >= 30,
                page: 1,
                entitySuggestions: [],
              ));
              add(AddToHistoryEvent(query));
            },
          );
          break;
        case SearchFilter.artists:
          final result = await _musicRepository.searchArtists(query, limit: 30);
          if (emit.isDone || generation != _searchGeneration) return;
          result.fold(
            (failure) {
              if (emit.isDone || generation != _searchGeneration) return;
              emit(state.copyWith(
                status: SearchStatus.error,
                errorMessage: failure.message,
              ));
            },
            (artists) {
              if (emit.isDone || generation != _searchGeneration) return;
              emit(state.copyWith(
                status: SearchStatus.success,
                results: SearchResults(artists: artists),
                hasMore: artists.length >= 30,
                page: 1,
                entitySuggestions: [],
              ));
              add(AddToHistoryEvent(query));
            },
          );
          break;
        case SearchFilter.albums:
          final result = await _musicRepository.searchAlbums(query, limit: 30);
          if (emit.isDone || generation != _searchGeneration) return;
          result.fold(
            (failure) {
              if (emit.isDone || generation != _searchGeneration) return;
              emit(state.copyWith(
                status: SearchStatus.error,
                errorMessage: failure.message,
              ));
            },
            (albums) {
              if (emit.isDone || generation != _searchGeneration) return;
              emit(state.copyWith(
                status: SearchStatus.success,
                results: SearchResults(albums: albums),
                hasMore: albums.length >= 30,
                page: 1,
                entitySuggestions: [],
              ));
              add(AddToHistoryEvent(query));
            },
          );
          break;
        case SearchFilter.playlists:
          final result = await _musicRepository.searchPlaylists(query, limit: 30);
          if (emit.isDone || generation != _searchGeneration) return;
          result.fold(
            (failure) {
              if (emit.isDone || generation != _searchGeneration) return;
              emit(state.copyWith(
                status: SearchStatus.error,
                errorMessage: failure.message,
              ));
            },
            (playlists) {
              if (emit.isDone || generation != _searchGeneration) return;
              emit(state.copyWith(
                status: SearchStatus.success,
                results: SearchResults(playlists: playlists),
                hasMore: playlists.length >= 30,
                page: 1,
                entitySuggestions: [],
              ));
              add(AddToHistoryEvent(query));
            },
          );
          break;
        case SearchFilter.all:
          Logger.root.info(
            'SearchBloc: searchAll filter=${event.filter}',
          );
          final result = await _musicRepository.searchAll(query, limit: 30);
          if (emit.isDone || generation != _searchGeneration) return;
          result.fold(
            (failure) {
              if (emit.isDone || generation != _searchGeneration) return;
              emit(state.copyWith(
                status: SearchStatus.error,
                errorMessage: failure.message,
              ));
            },
            (searchResults) {
              if (emit.isDone || generation != _searchGeneration) return;
              final rankedSongs = List<Song>.from(searchResults.songs);
              rankedSongs.sort((a, b) {
                final scoreA = max(
                  UnicodeSearchMatcher.computeSimilarity(a.title, query),
                  UnicodeSearchMatcher.computeSimilarity(a.artist, query),
                );
                final scoreB = max(
                  UnicodeSearchMatcher.computeSimilarity(b.title, query),
                  UnicodeSearchMatcher.computeSimilarity(b.artist, query),
                );
                return scoreB.compareTo(scoreA);
              });
              emit(state.copyWith(
                status: SearchStatus.success,
                results: searchResults.copyWith(songs: rankedSongs),
                hasMore: false,
                page: 1,
                entitySuggestions: [],
              ));
              add(AddToHistoryEvent(query));
            },
          );
          break;
      }
    } catch (e) {
      if (emit.isDone || generation != _searchGeneration) return;
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
    _searchGeneration++;
    emit(SearchState(
      filter: state.filter,
      history: state.history,
      historyEntries: state.historyEntries,
      page: 1,
      hasMore: false,
    ));
  }

  Future<void> _onLoadMoreResults(
    LoadMoreResultsEvent event,
    Emitter<SearchState> emit,
  ) async {
    if (!state.hasMore || state.isLoadingMore || state.query.trim().isEmpty) return;

    final generation = _searchGeneration;
    final nextPage = state.page + 1;
    final query = state.query.trim();
    emit(state.copyWith(status: SearchStatus.loadingMore));

    try {
      switch (state.filter) {
        case SearchFilter.songs:
          final offset = state.results.songs.length;
          final result = await _musicRepository.searchSongs(query, limit: 30, offset: offset);
          if (emit.isDone || generation != _searchGeneration) return;
          result.fold(
            (failure) => emit(state.copyWith(status: SearchStatus.success, hasMore: false)),
            (moreSongs) {
              if (emit.isDone || generation != _searchGeneration) return;
              final existingIds = state.results.songs.map((s) => s.playableId).toSet();
              final newSongs = moreSongs.where((s) => !existingIds.contains(s.playableId)).toList();
              final combined = [...state.results.songs, ...newSongs];
              emit(state.copyWith(
                status: SearchStatus.success,
                results: state.results.copyWith(songs: combined),
                hasMore: moreSongs.length >= 30,
                page: nextPage,
              ));
            },
          );
          break;
        case SearchFilter.artists:
          final offset = state.results.artists.length;
          final result = await _musicRepository.searchArtists(query, limit: 30, offset: offset);
          if (emit.isDone || generation != _searchGeneration) return;
          result.fold(
            (failure) => emit(state.copyWith(status: SearchStatus.success, hasMore: false)),
            (moreArtists) {
              if (emit.isDone || generation != _searchGeneration) return;
              final existingIds = state.results.artists.map((a) => a.id).toSet();
              final newArtists = moreArtists.where((a) => !existingIds.contains(a.id)).toList();
              final combined = [...state.results.artists, ...newArtists];
              emit(state.copyWith(
                status: SearchStatus.success,
                results: state.results.copyWith(artists: combined),
                hasMore: moreArtists.length >= 30,
                page: nextPage,
              ));
            },
          );
          break;
        case SearchFilter.albums:
          final offset = state.results.albums.length;
          final result = await _musicRepository.searchAlbums(query, limit: 30, offset: offset);
          if (emit.isDone || generation != _searchGeneration) return;
          result.fold(
            (failure) => emit(state.copyWith(status: SearchStatus.success, hasMore: false)),
            (moreAlbums) {
              if (emit.isDone || generation != _searchGeneration) return;
              final existingIds = state.results.albums.map((a) => a.id).toSet();
              final newAlbums = moreAlbums.where((a) => !existingIds.contains(a.id)).toList();
              final combined = [...state.results.albums, ...newAlbums];
              emit(state.copyWith(
                status: SearchStatus.success,
                results: state.results.copyWith(albums: combined),
                hasMore: moreAlbums.length >= 30,
                page: nextPage,
              ));
            },
          );
          break;
        case SearchFilter.playlists:
          final offset = state.results.playlists.length;
          final result = await _musicRepository.searchPlaylists(query, limit: 30, offset: offset);
          if (emit.isDone || generation != _searchGeneration) return;
          result.fold(
            (failure) => emit(state.copyWith(status: SearchStatus.success, hasMore: false)),
            (morePlaylists) {
              if (emit.isDone || generation != _searchGeneration) return;
              final existingIds = state.results.playlists.map((p) => p.id).toSet();
              final newPlaylists = morePlaylists.where((p) => !existingIds.contains(p.id)).toList();
              final combined = [...state.results.playlists, ...newPlaylists];
              emit(state.copyWith(
                status: SearchStatus.success,
                results: state.results.copyWith(playlists: combined),
                hasMore: morePlaylists.length >= 30,
                page: nextPage,
              ));
            },
          );
          break;
        case SearchFilter.all:
          emit(state.copyWith(status: SearchStatus.success, hasMore: false));
          break;
      }
    } catch (_) {
      if (emit.isDone || generation != _searchGeneration) return;
      emit(state.copyWith(status: SearchStatus.success, hasMore: false));
    }
  }

  Future<void> _onUpdateFilter(
    UpdateFilterEvent event,
    Emitter<SearchState> emit,
  ) async {
    final effectiveQuery =
        (event.query != null && event.query!.trim().isNotEmpty)
            ? event.query!.trim()
            : state.query.trim();
    emit(state.copyWith(filter: event.filter));
    if (effectiveQuery.length >= 2) {
      add(SearchQueryEvent(query: effectiveQuery, filter: event.filter));
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
          .where((entry) => entry['id'] != event.id && entry['query'] != event.id)
          .toList();

      final updatedHistory = state.history
          .where((q) => q != event.id)
          .toList();

      emit(state.copyWith(
        history: updatedHistory,
        historyEntries: updatedEntries,
      ));
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
    final generation = ++_searchGeneration;
    final query = event.query.trim();

    // If query is empty, show recent history
    if (query.isEmpty) {
      try {
        final historyEntries = await _localDataSource.getSearchHistory(limit: 10);
        if (emit.isDone || generation != _searchGeneration) return;
        emit(state.copyWith(
          status: SearchStatus.initial,
          query: '',
          results: const SearchResults(),
          historyEntries: historyEntries,
          entitySuggestions: [],
        ));
      } catch (e) {
        debugPrint('SearchBloc: Error loading history for suggestions: $e');
      }
      return;
    }

    // If query is too short, just show matching history and clear older search results
    if (query.length < 2) {
      try {
        final pastSearches = await _localDataSource.getSimilarSearches(query, limit: 5);
        if (emit.isDone || generation != _searchGeneration) return;
        emit(state.copyWith(
          status: SearchStatus.initial,
          query: query,
          results: const SearchResults(),
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

      if (emit.isDone || generation != _searchGeneration) return;

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
