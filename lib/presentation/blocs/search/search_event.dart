import 'package:equatable/equatable.dart';

/// Base class for all search events
abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

/// Perform a search query
class SearchQueryEvent extends SearchEvent {
  final String query;
  final SearchFilter filter;

  const SearchQueryEvent({
    required this.query,
    this.filter = SearchFilter.all,
  });

  @override
  List<Object?> get props => [query, filter];
}

/// Clear search results
class ClearSearchEvent extends SearchEvent {
  const ClearSearchEvent();
}

/// Load more search results
class LoadMoreResultsEvent extends SearchEvent {
  const LoadMoreResultsEvent();
}

/// Update search filter
class UpdateFilterEvent extends SearchEvent {
  final SearchFilter filter;

  const UpdateFilterEvent(this.filter);

  @override
  List<Object?> get props => [filter];
}

/// Add query to search history
class AddToHistoryEvent extends SearchEvent {
  final String query;

  const AddToHistoryEvent(this.query);

  @override
  List<Object?> get props => [query];
}

/// Clear search history
class ClearHistoryEvent extends SearchEvent {
  const ClearHistoryEvent();
}

/// Remove specific search from history
class RemoveFromHistoryEvent extends SearchEvent {
  final String id;

  const RemoveFromHistoryEvent(this.id);

  @override
  List<Object?> get props => [id];
}

/// Fetch suggestions while typing (debounced)
class FetchSuggestionsEvent extends SearchEvent {
  final String query;

  const FetchSuggestionsEvent(this.query);

  @override
  List<Object?> get props => [query];
}

/// Load search history on init
class LoadSearchHistoryEvent extends SearchEvent {
  const LoadSearchHistoryEvent();
}

/// Search filter options
enum SearchFilter {
  all,
  songs,
  artists,
  albums,
  playlists,
}
