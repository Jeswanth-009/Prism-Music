import 'package:equatable/equatable.dart';
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

  /// Error message if status is error
  final String? errorMessage;

  const SearchState({
    this.status = SearchStatus.initial,
    this.query = '',
    this.filter = SearchFilter.all,
    this.results = const SearchResults(),
    this.entitySuggestions = const [],
    this.historyEntries = const [],
    this.history = const [],
    this.hasMore = false,
    this.errorMessage,
  });

  /// Whether search is in progress
  bool get isLoading =>
      status == SearchStatus.loading || status == SearchStatus.loadingMore;

  /// Whether there are any results
  bool get hasResults => !results.isEmpty;

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
    String? errorMessage,
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
      errorMessage: errorMessage ?? this.errorMessage,
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
        errorMessage,
      ];
}
