import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/utils/date_grouping.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../blocs/player/player_state.dart';
import '../blocs/search/search_bloc.dart';
import '../blocs/search/search_event.dart';
import '../blocs/search/search_state.dart';
import '../theme/prism_theme.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/prism/prism_artwork.dart';
import '../widgets/prism/prism_dialog.dart';
import '../widgets/prism/prism_section_header.dart';
import '../widgets/prism/prism_skeleton.dart';
import '../widgets/prism/prism_song_tile.dart';
import '../widgets/prism/prism_states.dart';
import 'album_page.dart';
import 'artist_page.dart';
import 'remote_playlist_page.dart';
import '../widgets/player/mini_player.dart';

/// Search: filter chips, full-bleed results, genre/vibe discovery.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  static const _genres = [
    'Pop', 'Rock', 'Jazz', 'Metal', 'Hip-Hop', 'Classical', 'Latin', 'Indie',
    'EDM', 'R&B',
  ];
  static const _vibes = [
    'Party', 'Chill', 'Workout', 'Focus', 'Relax', 'Sleep', 'Driving',
    'Study', 'Happy', 'Moody',
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
    _scrollController.addListener(() {
      if (_scrollController.hasClients &&
          _scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 240) {
        final state = context.read<SearchBloc>().state;
        if (state.hasMore && !state.isLoadingMore) {
          context.read<SearchBloc>().add(const LoadMoreResultsEvent());
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── actions ──────────────────────────────────────────────────────────

  void _onSearch(String query, {SearchFilter? filter}) {
    final trimmed = query.trim();
    if (trimmed.length >= 2) {
      final activeFilter = filter ?? context.read<SearchBloc>().state.filter;
      context.read<SearchBloc>().add(
        SearchQueryEvent(
          query: trimmed,
          filter: activeFilter,
        ),
      );
    }
  }

  void _onFilterChanged(SearchFilter filter) {
    final query = _searchController.text.trim();
    context.read<SearchBloc>().add(UpdateFilterEvent(filter, query: query));
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

  // ── build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      bottomNavigationBar:
          widget.embedded ? null : const PrismPersistentMiniPlayer(),
      body: SafeArea(
        bottom: !widget.embedded,
        child: BlocBuilder<SearchBloc, SearchState>(
          builder: (context, state) {
            final hasQuery = state.query.isNotEmpty ||
                _searchController.text.trim().isNotEmpty;
            final canClear = hasQuery || _searchController.text.isNotEmpty;
            return CustomScrollView(
              key: const PageStorageKey('prism_search'),
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    widget.embedded ? 18 : 8,
                    20,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _buildHeader(theme, state, canClear),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  sliver: SliverToBoxAdapter(child: _buildSearchField(theme)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _FilterChips(
                      selected: state.filter,
                      onSelect: _onFilterChanged,
                    ),
                  ),
                ),
                if (!hasQuery)
                  ..._browseSlivers(state)
                else ..._resultsSlivers(state),
                const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, SearchState state, bool canClear) {
    return Row(
      children: [
        if (!widget.embedded) ...[
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Search',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.9,
                ),
              ),
              Text(
                'Songs, artists, albums and playlists.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (canClear)
          TextButton(onPressed: _clearSearch, child: const Text('Clear')),
      ],
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return TextField(
      controller: _searchController,
      focusNode: _focusNode,
      textInputAction: TextInputAction.search,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: 'What do you want to listen to?',
        prefixIcon: const Icon(Icons.search_rounded, size: 22),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: _clearSearch,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHigh.withValues(alpha: .55),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PrismRadius.xl),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (value) {
        setState(() {});
        final trimmed = value.trim();
        if (trimmed.isEmpty) {
          context.read<SearchBloc>().add(const ClearSearchEvent());
        } else if (trimmed.length < 2) {
          context.read<SearchBloc>().add(FetchSuggestionsEvent(trimmed));
        } else {
          _onSearch(trimmed);
        }
      },
      onSubmitted: (value) {
        final trimmed = value.trim();
        if (trimmed.length >= 2) {
          _onSearch(trimmed);
        }
      },
    );
  }

  // ── browse (no query) ────────────────────────────────────────────────

  List<Widget> _browseSlivers(SearchState state) {
    final entries = state.historyEntries.isNotEmpty
        ? state.historyEntries
        : state.history.map((q) => {'query': q, 'id': q}).toList();

    DateTime getTimestamp(Map<String, String> e) {
      final tsStr = e['timestamp'];
      final ts = tsStr != null ? int.tryParse(tsStr) : null;
      return ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : DateTime.now();
    }

    final groupedHistory = DateGrouping.groupByPeriod(entries, getTimestamp);

    return [
      SliverToBoxAdapter(
        child: PrismSectionHeader(
            title: 'Browse genres',
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 10)),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverToBoxAdapter(
          child: _ChipWrap(
            items: _genres.take(6).toList(),
            onTap: _applyQuickQuery,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: PrismSectionHeader(
            title: 'Moods & vibes',
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 10)),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverToBoxAdapter(
          child: _ChipWrap(
            items: _vibes.take(6).toList(),
            onTap: _applyQuickQuery,
          ),
        ),
      ),
      if (entries.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: PrismSectionHeader(
            title: 'Recent searches',
            actionLabel: 'Clear all',
            onAction: () {
              showPrismConfirmDialog(
                context: context,
                title: 'Clear search history?',
                message:
                    'All your recent search terms will be permanently removed.',
                confirmLabel: 'Clear all',
                isDestructive: true,
                onConfirm: () =>
                    context.read<SearchBloc>().add(const ClearHistoryEvent()),
              );
            },
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
          ),
        ),
        for (final group in groupedHistory.entries) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                group.key.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverList.separated(
              itemCount: group.value.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final entry = group.value[index];
                final query = entry['query'] ?? '';
                final timeText =
                    DateGrouping.formatRelativeTime(getTimestamp(entry));
                return ListTile(
                  onTap: () => _applyQuickQuery(query),
                  leading: Icon(
                    Icons.history_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    query,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    timeText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.8),
                        ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        tooltip: 'Remove from history',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => context
                            .read<SearchBloc>()
                            .add(RemoveFromHistoryEvent(entry['id'] ?? query)),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.north_west_rounded, size: 16),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    ];
  }

  // ── results ──────────────────────────────────────────────────────────

  List<Widget> _resultsSlivers(SearchState state) {
    if (state.isLoading) {
      return const [
        SliverPadding(padding: EdgeInsets.only(top: 24)),
        SliverToBoxAdapter(child: PrismListSkeleton(count: 8)),
      ];
    }

    if (state.status == SearchStatus.error) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: PrismErrorState(message: state.errorMessage, onRetry: () {
            context.read<SearchBloc>().add(
              SearchQueryEvent(
                query: _searchController.text.trim(),
                filter: state.filter,
              ),
            );
          }),
        ),
      ];
    }

    return switch (state.filter) {
      SearchFilter.all => _allSlivers(state),
      SearchFilter.songs => _songsSlivers(state),
      SearchFilter.artists => _artistsSlivers(state),
      SearchFilter.albums => _albumsSlivers(state),
      SearchFilter.playlists => _playlistsSlivers(state),
    };
  }

  List<Widget> _allSlivers(SearchState state) {
    final songs = state.results.songs;
    final artists = state.results.artists;
    final albums = state.results.albums;
    final playlists = state.results.playlists;

    if (songs.isEmpty && artists.isEmpty && albums.isEmpty && playlists.isEmpty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: PrismEmptyState(
            icon: Icons.search_off_rounded,
            message: 'No results found',
            hint: 'Try a different search or spelling.',
          ),
        ),
      ];
    }

    final slivers = <Widget>[];

    if (songs.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: PrismSectionHeader(
            title: 'Songs',
            actionLabel: songs.length > 5 ? 'See all' : null,
            onAction: () => _onFilterChanged(SearchFilter.songs),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          ),
        ),
      );
      final topSongs = songs.take(5).toList();
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverList.builder(
            itemCount: topSongs.length,
            itemBuilder: (context, index) {
              final song = topSongs[index];
              return BlocBuilder<PlayerBloc, PlayerState>(
                builder: (context, playerState) => PrismSongTile(
                  song: song,
                  index: index,
                  isPlaying: playerState.currentSong?.id == song.id,
                  isPlayingPaused: !playerState.isPlaying,
                  onTap: () {
                    context.read<PlayerBloc>().add(
                      PlaySongEvent(song: song, queue: songs, queueIndex: index),
                    );
                    if (!widget.embedded) Navigator.of(context).maybePop();
                  },
                ),
              );
            },
          ),
        ),
      );
    }

    if (artists.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: PrismSectionHeader(
            title: 'Artists',
            actionLabel: artists.length > 3 ? 'See all' : null,
            onAction: () => _onFilterChanged(SearchFilter.artists),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          ),
        ),
      );
      final topArtists = artists.take(3).toList();
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverList.builder(
            itemCount: topArtists.length,
            itemBuilder: (context, index) {
              final artist = topArtists[index];
              return ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ArtistPage(
                      artistName: artist.name,
                      artistId: artist.id,
                      thumbnailUrl: artist.thumbnailUrl,
                      heroTag: 'artist_all_${artist.id}',
                    ),
                  ),
                ),
                leading: Hero(
                  tag: 'artist_all_${artist.id}',
                  child: PrismArtwork(
                    url: artist.thumbnailUrl ?? '',
                    width: 44,
                    height: 44,
                    isCircular: true,
                    type: ArtworkType.artist,
                  ),
                ),
                title: Text(
                  artist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text('Artist'),
              );
            },
          ),
        ),
      );
    }

    if (albums.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: PrismSectionHeader(
            title: 'Albums',
            actionLabel: albums.length > 4 ? 'See all' : null,
            onAction: () => _onFilterChanged(SearchFilter.albums),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          ),
        ),
      );
      final topAlbums = albums.take(4).toList();
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid.builder(
            itemCount: topAlbums.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: .78,
              crossAxisSpacing: 14,
              mainAxisSpacing: 18,
            ),
            itemBuilder: (context, index) {
              final album = topAlbums[index];
              return _AlbumGridCard(
                url: album.thumbnails.high ?? album.thumbnails.medium ?? '',
                title: album.title,
                subtitle: album.artist,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AlbumPage(album: album),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    if (playlists.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: PrismSectionHeader(
            title: 'Playlists',
            actionLabel: playlists.length > 3 ? 'See all' : null,
            onAction: () => _onFilterChanged(SearchFilter.playlists),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          ),
        ),
      );
      final topPlaylists = playlists.take(3).toList();
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverList.builder(
            itemCount: topPlaylists.length,
            itemBuilder: (context, index) {
              final playlist = topPlaylists[index];
              return ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RemotePlaylistPage(playlist: playlist),
                  ),
                ),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(PrismRadius.sm),
                  child: SizedBox.square(
                    dimension: 48,
                    child: playlist.thumbnails?.medium != null
                        ? Image.network(
                            playlist.thumbnails!.medium!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.queue_music_rounded),
                          )
                        : const Icon(Icons.queue_music_rounded),
                  ),
                ),
                title: Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text('${playlist.trackCount} tracks'),
              );
            },
          ),
        ),
      );
    }

    return slivers;
  }

  List<Widget> _songsSlivers(SearchState state) {
    final songs = state.results.songs;
    if (songs.isEmpty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: PrismEmptyState(
            icon: Icons.search_off_rounded,
            message: 'No songs found',
            hint: 'Try a different search or spelling.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        sliver: SliverList.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return BlocBuilder<PlayerBloc, PlayerState>(
              builder: (context, playerState) => PrismSongTile(
                song: song,
                index: index,
                isPlaying: playerState.currentSong?.id == song.id,
                isPlayingPaused: !playerState.isPlaying,
                onTap: () {
                  context.read<PlayerBloc>().add(
                    PlaySongEvent(song: song, queue: songs, queueIndex: index),
                  );
                  if (!widget.embedded) Navigator.of(context).maybePop();
                },
              ),
            );
          },
        ),
      ),
      if (state.isLoadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _artistsSlivers(SearchState state) {
    final artists = state.results.artists;
    if (artists.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: const PrismEmptyState(
            icon: Icons.search_off_rounded,
            message: 'No artists found',
            hint: 'Try a different search or spelling.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        sliver: SliverList.builder(
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            return ListTile(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ArtistPage(
                    artistName: artist.name,
                    artistId: artist.id,
                    thumbnailUrl: artist.thumbnailUrl,
                    heroTag: 'artist_${artist.id}',
                  ),
                ),
              ),
              leading: Hero(
                tag: 'artist_${artist.id}',
                child: PrismArtwork(
                  url: artist.thumbnailUrl ?? '',
                  width: 48,
                  height: 48,
                  isCircular: true,
                  type: ArtworkType.artist,
                ),
              ),
              title: Text(
                artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Artist'),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _albumsSlivers(SearchState state) {
    final albums = state.results.albums;
    if (albums.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: const PrismEmptyState(
            icon: Icons.search_off_rounded,
            message: 'No albums found',
            hint: 'Try a different search or spelling.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        sliver: SliverGrid.builder(
          itemCount: albums.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: .78,
            crossAxisSpacing: 14,
            mainAxisSpacing: 18,
          ),
          itemBuilder: (context, index) {
            final album = albums[index];
            return _AlbumGridCard(
              url: album.thumbnails.high ?? album.thumbnails.medium ?? '',
              title: album.title,
              subtitle: album.artist,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AlbumPage(album: album),
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _playlistsSlivers(SearchState state) {
    final playlists = state.results.playlists;
    if (playlists.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: const PrismEmptyState(
            icon: Icons.search_off_rounded,
            message: 'No playlists found',
            hint: 'Try a different search or spelling.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        sliver: SliverList.builder(
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return ListTile(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RemotePlaylistPage(playlist: playlist),
                ),
              ),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(PrismRadius.sm),
                child: SizedBox.square(
                  dimension: 48,
                  child: playlist.thumbnails?.medium != null
                      ? Image.network(
                          playlist.thumbnails!.medium!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.queue_music_rounded),
                        )
                      : const Icon(Icons.queue_music_rounded),
                ),
              ),
              title: Text(
                playlist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text('${playlist.trackCount} tracks'),
            );
          },
        ),
      ),
    ];
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Private helper widgets
// ════════════════════════════════════════════════════════════════════════════

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelect});

  final SearchFilter selected;
  final ValueChanged<SearchFilter> onSelect;

  static const _filters = [
    SearchFilter.all,
    SearchFilter.songs,
    SearchFilter.artists,
    SearchFilter.albums,
    SearchFilter.playlists,
  ];

  String _labelFor(SearchFilter filter) => switch (filter) {
    SearchFilter.all => 'All',
    SearchFilter.songs => 'Songs',
    SearchFilter.playlists => 'Playlists',
    SearchFilter.albums => 'Albums',
    SearchFilter.artists => 'Artists',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _filters
          .map(
            (filter) => ChoiceChip(
              label: Text(_labelFor(filter)),
              selected: filter == selected,
              onSelected: (_) => onSelect(filter),
            ),
          )
          .toList(),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.items, required this.onTap});

  final List<String> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => ActionChip(
              label: Text(item),
              onPressed: () => onTap(item),
            ),
          )
          .toList(),
    );
  }
}

class _AlbumGridCard extends StatelessWidget {
  const _AlbumGridCard({
    required this.url,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String url;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PrismRadius.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(PrismRadius.lg),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(PrismRadius.lg),
                child: url.isNotEmpty
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => _fallback(theme),
                      )
                    : _fallback(theme),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(ThemeData theme) => Container(
    color: theme.colorScheme.surfaceContainerHigh,
    child: Icon(
      Icons.album_rounded,
      size: 42,
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: .5),
    ),
  );
}
