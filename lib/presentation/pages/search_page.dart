import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../blocs/search/search_bloc.dart';
import '../blocs/search/search_event.dart';
import '../blocs/search/search_state.dart';
import 'artist_page.dart';

/// Full search page with tabbed interface for different content types
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context
          .read<SearchBloc>()
          .add(const UpdateFilterEvent(SearchFilter.songs));
    });

    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────────────────

  void _onSearch(String query) {
    Logger.root.info('SearchPage: _onSearch("$query")');
    if (query.trim().length >= 2) {
      context.read<SearchBloc>().add(
            SearchQueryEvent(
              query: query.trim(),
              filter: context.read<SearchBloc>().state.filter,
            ),
          );
    }
  }

  void _onCategorySelected(SearchFilter filter) {
    context.read<SearchBloc>().add(UpdateFilterEvent(filter));
    if (_searchController.text.trim().length >= 2) {
      _onSearch(_searchController.text.trim());
    }
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<SearchBloc>().add(const ClearSearchEvent());
    setState(() {});
  }

  void _applyQuickQuery(String value) {
    _searchController.text = value;
    _focusNode.unfocus();
    _onSearch(value);
    setState(() {});
  }

  double _resultsHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return (screenHeight * 0.55).clamp(360.0, 620.0).toDouble();
  }

  // ── chip sheet ───────────────────────────────────────────────────────

  void _showChipSheet(String title, List<String> items) {
    showShadSheet(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (context) {
        return ShadSheet(
          title: Text(title),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: items
                  .map((item) => ShadButton.outline(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _applyQuickQuery(item);
                        },
                        size: ShadButtonSize.sm,
                        child: Text(item),
                      ))
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  // ── build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    Logger.root.info('SearchPage: build called');
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<SearchBloc, SearchState>(
          builder: (context, state) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: _buildTopBar(theme, state),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSearchHeader(context, theme, state),
                        const SizedBox(height: 8),
                        ShadCard(
                          padding: EdgeInsets.zero,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              height: _resultsHeight(context),
                              child: _buildResultsBody(theme, state),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── top bar ──────────────────────────────────────────────────────────

  Widget _buildTopBar(ThemeData theme, SearchState state) {
    final canClear =
        _searchController.text.isNotEmpty || state.query.isNotEmpty;
    return Row(
      children: [
        ShadIconButton.ghost(
          icon: const Icon(LucideIcons.chevronLeft, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Search',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                'Prism Music catalog',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (canClear)
          ShadButton.ghost(
            onPressed: _clearSearch,
            size: ShadButtonSize.sm,
            child: const Text('Clear'),
          ),
      ],
    );
  }

  // ── search header ────────────────────────────────────────────────────

  Widget _buildSearchHeader(
      BuildContext context, ThemeData theme, SearchState state) {
    final recentQueries = state.history.take(5).toList();
    const genres = [
      'Pop', 'Rock', 'Jazz', 'Metal', 'Hip-Hop',
      'Classical', 'Latin', 'Indie', 'EDM', 'R&B',
    ];
    const vibes = [
      'Party', 'Chill', 'Workout', 'Focus', 'Relax',
      'Sleep', 'Driving', 'Study', 'Happy', 'Moody',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search input
        ShadInput(
          controller: _searchController,
          focusNode: _focusNode,
          placeholder: const Text('Artists, songs, podcasts...'),
          leading: const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(LucideIcons.search, size: 18),
          ),
          trailing: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (_, value, __) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return ShadIconButton.ghost(
                icon: const Icon(LucideIcons.x, size: 16),
                width: 28,
                height: 28,
                onPressed: _clearSearch,
              );
            },
          ),
          onChanged: (value) {
            setState(() {});
            if (value.trim().length >= 2) _onSearch(value);
          },
          onSubmitted: _onSearch,
        ),

        // Filter row
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 12),
          child: _FilterRow(
            selected: state.filter,
            onSelect: _onCategorySelected,
            sourceLabel: 'YouTube Music',
          ),
        ),

        // Genres
        _SectionHeader(
          title: 'Genres',
          action: 'See All',
          onAction: () => _showChipSheet('Genres', genres),
        ),
        _ChipsWrap(
          items: genres.take(4).toList(),
          onTap: _applyQuickQuery,
        ),
        const SizedBox(height: 12),

        // Vibes
        _SectionHeader(
          title: 'Vibes & Events',
          action: 'See All',
          onAction: () => _showChipSheet('Vibes & Events', vibes),
        ),
        _ChipsWrap(
          items: vibes.take(4).toList(),
          onTap: _applyQuickQuery,
        ),

        // Recent
        if (recentQueries.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionHeader(
            title: 'Recent Searches',
            action: 'Clear',
            onAction: () =>
                context.read<SearchBloc>().add(const ClearHistoryEvent()),
          ),
          ...recentQueries.map((query) => _RecentSearchTile(
                query: query,
                onTap: () => _applyQuickQuery(query),
                onPlay: () => _onSearch(query),
              )),
        ],
      ],
    );
  }

  // ── results body ─────────────────────────────────────────────────────

  Widget _buildResultsBody(ThemeData theme, SearchState state) {
    if (state.status == SearchStatus.initial) {
      return _buildInitialView(theme);
    }

    if (state.status == SearchStatus.loading) {
      return const Center(child: ShadProgress());
    }

    if (state.status == SearchStatus.error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShadAlert.destructive(
              icon: const Icon(LucideIcons.circleAlert, size: 16),
              title: Text(state.errorMessage ?? 'Search failed'),
            ),
            const SizedBox(height: 16),
            ShadButton.outline(
              onPressed: () => _onSearch(_searchController.text),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    switch (state.filter) {
      case SearchFilter.songs:
      case SearchFilter.all:
        return _buildSongsTab(state, theme);
      case SearchFilter.albums:
        return _buildAlbumsTab(state, theme);
      case SearchFilter.artists:
        return _buildArtistsTab(state, theme);
      case SearchFilter.playlists:
        return _buildPlaylistsTab(state, theme);
    }
  }

  // ── songs tab ────────────────────────────────────────────────────────

  Widget _buildSongsTab(SearchState state, ThemeData theme) {
    Logger.root.info('SearchPage: songs count = ${state.results.songs.length}');

    if (state.results.songs.isEmpty) {
      return _buildEmptyState('No songs found', theme);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: state.results.songs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final song = state.results.songs[index];
        return GestureDetector(
          onTap: () {
            context
                .read<PlayerBloc>()
                .add(PlaySongEvent(song: song));
            Navigator.pop(context);
          },
          child: ShadCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: song.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          song.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: theme.colorScheme.surface,
                            child: const Icon(LucideIcons.music, size: 20),
                          ),
                        )
                      : Container(
                          color: theme.colorScheme.surface,
                          child: const Icon(LucideIcons.music, size: 20),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(song.durationFormatted,
                      style: theme.textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Icon(LucideIcons.play,
                      size: 18, color: theme.colorScheme.primary),
                ],
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  // ── albums tab ───────────────────────────────────────────────────────

  Widget _buildAlbumsTab(SearchState state, ThemeData theme) {
    if (state.results.albums.isEmpty) {
      return _buildEmptyState('No albums found', theme);
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: state.results.albums.length,
      itemBuilder: (context, index) {
        final album = state.results.albums[index];
        return GestureDetector(
          onTap: () {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: album.thumbnails.high != null
                      ? Image.network(
                          album.thumbnails.high!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child:
                                const Icon(LucideIcons.disc, size: 48),
                          ),
                        )
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(LucideIcons.disc, size: 48),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                album.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                album.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── artists tab ──────────────────────────────────────────────────────

  Widget _buildArtistsTab(SearchState state, ThemeData theme) {
    if (state.results.artists.isEmpty) {
      return _buildEmptyState('No artists found', theme);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: state.results.artists.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final artist = state.results.artists[index];
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ArtistPage(
                  artistName: artist.name,
                  artistId: artist.id,
                  thumbnailUrl: artist.thumbnailUrl,
                  heroTag: 'artist_${artist.id}',
                ),
              ),
            );
          },
          child: ShadCard(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Hero(
                tag: 'artist_${artist.id}',
                child: artist.thumbnails?.medium != null
                    ? ShadAvatar(
                        artist.thumbnails!.medium!,
                        placeholder: const Icon(LucideIcons.user, size: 18),
                        size: const Size(48, 48),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.user, size: 18),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text('Artist',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
          ),
        );
      },
    );
  }

  // ── playlists tab ────────────────────────────────────────────────────

  Widget _buildPlaylistsTab(SearchState state, ThemeData theme) {
    if (state.results.playlists.isEmpty) {
      return _buildEmptyState('No playlists found', theme);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: state.results.playlists.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final playlist = state.results.playlists[index];
        return ShadCard(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: playlist.thumbnails?.medium != null
                      ? Image.network(
                          playlist.thumbnails!.medium!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: theme.colorScheme.surface,
                            child: const Icon(LucideIcons.listMusic,
                                size: 20),
                          ),
                        )
                      : Container(
                          color: theme.colorScheme.surface,
                          child: const Icon(LucideIcons.listMusic,
                              size: 20),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text('${playlist.trackCount} tracks',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        );
      },
    );
  }

  // ── empty / initial ──────────────────────────────────────────────────

  Widget _buildEmptyState(String message, ThemeData theme) {
    return Center(
      child: ShadCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.searchX,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.4),
            ),
            child: Icon(LucideIcons.search,
                size: 48, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 18),
          Text('Search for your favorite music',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Artists, albums, playlists and more',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Private helper widgets
// ════════════════════════════════════════════════════════════════════════════

class _FilterRow extends StatelessWidget {
  final SearchFilter selected;
  final ValueChanged<SearchFilter> onSelect;
  final String sourceLabel;

  const _FilterRow({
    required this.selected,
    required this.onSelect,
    required this.sourceLabel,
  });

  String _labelFor(SearchFilter filter) {
    switch (filter) {
      case SearchFilter.songs:
        return 'Songs';
      case SearchFilter.playlists:
        return 'Playlists';
      case SearchFilter.albums:
        return 'Albums';
      case SearchFilter.artists:
        return 'Artists';
      case SearchFilter.all:
        return 'All';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShadSelect<SearchFilter>(
          initialValue: selected,
          maxWidth: 160,
          selectedOptionBuilder: (context, value) => Text(_labelFor(value)),
          onChanged: (value) {
            if (value != null && value != selected) onSelect(value);
          },
          options: SearchFilter.values.map(
            (f) => ShadOption(value: f, child: Text(_labelFor(f))),
          ),
        ),
        const SizedBox(width: 10),
        ShadBadge.secondary(child: Text(sourceLabel)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        ShadButton.ghost(
          onPressed: onAction,
          size: ShadButtonSize.sm,
          child: Text(action),
        ),
      ],
    );
  }
}

class _ChipsWrap extends StatelessWidget {
  final List<String> items;
  final ValueChanged<String> onTap;

  const _ChipsWrap({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => ShadButton.outline(
              onPressed: () => onTap(item),
              size: ShadButtonSize.sm,
              child: Text(item),
            ),
          )
          .toList(),
    );
  }
}

class _RecentSearchTile extends StatelessWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  const _RecentSearchTile({
    required this.query,
    required this.onTap,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: ShadCard(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(LucideIcons.history,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(query,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            ShadIconButton.ghost(
              icon: const Icon(LucideIcons.play, size: 16),
              width: 32,
              height: 32,
              onPressed: onPlay,
            ),
          ],
        ),
      ),
      ),
    );
  }
}
