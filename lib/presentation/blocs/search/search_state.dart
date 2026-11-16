import 'package:equatable/equatable.dart';
import '../../../domain/entities/search_results_bundle.dart';
import '../../../domain/repositories/music_repository.dart';
import 'search_event.dart';

/// Search state status
enum SearchStatus {
  initial,
  loading,
  success,
  loadingMore,
  error,
}

/// Entity suggestion for search (songs, artists, albums suggested while typing)
class EntitySuggestion extends Equatable {
  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final EntityType type;

  const EntitySuggestion({
    required this.id,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    required this.type,
  });

  @override
  List<Object?> get props => [id, title, subtitle, imageUrl, type];
}

enum EntityType { song, artist, album, playlist }

/// Represents the complete search state
class SearchState extends Equatable {
  /// Current status of search
  final SearchStatus status;

  /// Current search query
  final String query;

  /// Current filter
  final SearchFilter filter;

  /// Search results
  final SearchResults results;

  /// Entity suggestions (songs, artists, etc. while typing)
  final List<EntitySuggestion> entitySuggestions;

  /// Search history from database
  final List<Map<String, String>> historyEntries;

  /// Legacy: search history (just strings)
  final List<String> history;

  /// Whether there are more results to load
  final bool hasMore;

  /// Current search page for pagination
  final int page;

  /// Error message if status is error
  final String? errorMessage;

  /// Whether current results were resolved offline from downloads
  final bool isOfflineResults;

  /// Top result selected by ranking engine
  final SearchTopResult? topResult;

  /// Cached universal bundle for instant chip slicing without network delays
  final SearchResults? cachedAllResults;

  /// Whether ambient song recognition is actively listening
  final bool isListening;

  const SearchState({
    this.status = SearchStatus.initial,
    this.query = '',
    this.filter = SearchFilter.songs,
    this.results = const SearchResults(),
    this.entitySuggestions = const [],
    this.historyEntries = const [],
    this.history = const [],
    this.hasMore = false,
    this.page = 1,
    this.errorMessage,
    this.isOfflineResults = false,
    this.topResult,
    this.cachedAllResults,
    this.isListening = false,
  });

  /// Whether search is in progress
  bool get isLoading =>
      status == SearchStatus.loading || status == SearchStatus.loadingMore;

  /// Whether loading additional search results page
  bool get isLoadingMore => status == SearchStatus.loadingMore;

  /// Whether there are any results
  bool get hasResults => !results.isEmpty;

  /// Whether top match result is available
  bool get hasTopResult => topResult != null;

  /// Whether we have any suggestions to show
  bool get hasSuggestions =>
      entitySuggestions.isNotEmpty || historyEntries.isNotEmpty;

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    SearchFilter? filter,
    SearchResults? results,
    List<EntitySuggestion>? entitySuggestions,
    List<Map<String, String>>? historyEntries,
    List<String>? history,
    bool? hasMore,
    int? page,
    String? errorMessage,
    bool? isOfflineResults,
    SearchTopResult? topResult,
    bool clearTopResult = false,
    SearchResults? cachedAllResults,
    bool? isListening,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      results: results ?? this.results,
      entitySuggestions: entitySuggestions ?? this.entitySuggestions,
      historyEntries: historyEntries ?? this.historyEntries,
      history: history ?? this.history,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      errorMessage: errorMessage ?? this.errorMessage,
      isOfflineResults: isOfflineResults ?? this.isOfflineResults,
      topResult: clearTopResult ? null : (topResult ?? this.topResult),
      cachedAllResults: cachedAllResults ?? this.cachedAllResults,
      isListening: isListening ?? this.isListening,
    );
  }

  @override
  List<Object?> get props => [
        status,
        query,
        filter,
        results,
        entitySuggestions,
        historyEntries,
        history,
        hasMore,
        page,
        errorMessage,
        isOfflineResults,
        topResult,
        cachedAllResults,
        isListening,
      ];
}
