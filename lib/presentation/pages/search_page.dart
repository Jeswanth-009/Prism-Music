import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/search_results_bundle.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../blocs/player/player_state.dart';
import '../blocs/search/search_bloc.dart';
import '../blocs/search/search_event.dart';
import '../blocs/search/search_state.dart';
import '../theme/prism_theme.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/prism/prism_artwork.dart';
import '../widgets/prism/prism_section_header.dart';
import '../widgets/prism/prism_skeleton.dart';
import '../widgets/prism/prism_song_actions.dart';
import '../widgets/prism/prism_song_tile.dart';
import '../widgets/prism/prism_states.dart';
import '../widgets/search/ambient_recognition_sheet.dart';
import '../widgets/search/search_category_bar.dart';
import '../widgets/search/search_discovery_view.dart';
import '../widgets/search/search_header_bar.dart';
import '../widgets/search/search_hero_card.dart';
import 'album_page.dart';
import 'artist_page.dart';
import 'remote_playlist_page.dart';

/// Complete revamp of the Search Page featuring deterministic ranking,
/// background warm-up prefetch, pinned category slivers, top match hero card,
/// and verified stream provenance.
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

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 240) {
      final state = context.read<SearchBloc>().state;
      if (state.hasMore && !state.isLoadingMore) {
        context.read<SearchBloc>().add(const LoadMoreResultsEvent());
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Search & Filter Triggers ──────────────────────────────────────────────

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

  void _openAmbientRecognition() {
    showAmbientRecognitionSheet(
      context: context,
      onRecognized: (recognizedQuery) {
        _searchController.text = recognizedQuery;
        context
            .read<SearchBloc>()
            .add(SearchRecognizedSongEvent(title: recognizedQuery));
        _onSearch(recognizedQuery);
        setState(() {});
      },
    );
  }

  void _handleTopResultTap(SearchTopResult top) {
    if (top.song != null) {
      final song = top.song!;
      context.read<PlayerBloc>().add(
            PlaySongEvent(song: song, queue: [song], queueIndex: 0),
          );
      if (!widget.embedded) Navigator.of(context).maybePop();
    } else if (top.artist != null) {
      final artist = top.artist!;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ArtistPage(
            artistName: artist.name,
            artistId: artist.id,
            thumbnailUrl: artist.thumbnailUrl,
            heroTag: 'top_artist_${artist.id}',
          ),
        ),
      );
    } else if (top.album != null) {
      final album = top.album!;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AlbumPage(album: album),
        ),
      );
    }
  }

  // ── Build Tree ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar:
          widget.embedded ? null : const PrismPersistentMiniPlayer(),
      body: SafeArea(
        bottom: !widget.embedded,
        child: BlocBuilder<SearchBloc, SearchState>(
          builder: (context, state) {
            final hasQuery = state.query.isNotEmpty ||
                _searchController.text.trim().isNotEmpty;

            return CustomScrollView(
              key: const PageStorageKey('prism_search'),
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Floating Frosted Search Header Bar
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    widget.embedded ? 14 : 8,
                    16,
                    6,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SearchHeaderBar(
                      controller: _searchController,
                      focusNode: _focusNode,
                      embedded: widget.embedded,
                      onChanged: (value) {
                        setState(() {});
                        final trimmed = value.trim();
                        if (trimmed.isEmpty) {
                          context
                              .read<SearchBloc>()
                              .add(const ClearSearchEvent());
                        } else if (trimmed.length < 2) {
                          context
                              .read<SearchBloc>()
                              .add(FetchSuggestionsEvent(trimmed));
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
                      onClear: _clearSearch,
                      onRecognizeTap: _openAmbientRecognition,
                    ),
                  ),
                ),

                // Pinned Category Filter Bar
                SliverPersistentHeader(
                  pinned: true,
                  delegate: PinnedCategoryBarDelegate(
                    selected: state.filter,
                    onSelect: _onFilterChanged,
                  ),
                ),

                // Body: Discovery Landing vs Results
                if (!hasQuery)
                  SliverToBoxAdapter(
                    child: SearchDiscoveryView(
                      onApplyQuery: _applyQuickQuery,
                    ),
                  )
                else
                  ..._resultsSlivers(state),

                const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Results Slivers ───────────────────────────────────────────────────────

  List<Widget> _resultsSlivers(SearchState state) {
    if (state.isLoading) {
      return const [
        SliverPadding(padding: EdgeInsets.only(top: 16)),
        SliverToBoxAdapter(child: PrismListSkeleton(count: 8)),
      ];
    }

    if (state.status == SearchStatus.error) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: PrismErrorState(
            message: state.errorMessage,
            onRetry: () {
              _onSearch(
                _searchController.text.trim(),
                filter: state.filter,
              );
            },
          ),
        ),
      ];
    }

    return switch (state.filter) {
      SearchFilter.all => _allSlivers(state),
      SearchFilter.songs => _songsSlivers(state),
      SearchFilter.artists => _artistsSlivers(state),
      SearchFilter.albums => _albumsSlivers(state),
      SearchFilter.playlists => _playlistsSlivers(state),
      SearchFilter.videos => _videosSlivers(state),
      SearchFilter.downloads => _downloadsSlivers(state),
    };
  }

  // ── Universal (All) View ──────────────────────────────────────────────────

  List<Widget> _allSlivers(SearchState state) {
    final songs = state.results.songs;
    final artists = state.results.artists;
    final albums = state.results.albums;
    final playlists = state.results.playlists;
    final topResult = state.topResult;

    if (topResult == null &&
        songs.isEmpty &&
        artists.isEmpty &&
        albums.isEmpty &&
        playlists.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: PrismEmptyState(
            icon: Icons.search_off_rounded,
            message: 'No results found',
            hint: 'Try a different search or check your spelling.',
            actionLabel: 'Clear Search',
            onAction: _clearSearch,
          ),
        ),
      ];
    }

    final slivers = <Widget>[];

    // Top Match Hero Card (if identified by ranking engine)
    if (topResult != null) {
      slivers.add(
        SliverToBoxAdapter(
          child: SearchHeroCard(
            topResult: topResult,
            onTap: () => _handleTopResultTap(topResult),
          ),
        ),
      );
    }

    // Songs section
    if (songs.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: PrismSectionHeader(
            title: 'Songs',
            actionLabel: songs.length > 5 ? 'See all' : null,
            onAction: () => _onFilterChanged(SearchFilter.songs),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
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
                buildWhen: (prev, curr) =>
                    (prev.currentSong?.id == song.id) != (curr.currentSong?.id == song.id) ||
                    (prev.isPlaying != curr.isPlaying && curr.currentSong?.id == song.id),
                builder: (context, playerState) => PrismSongTile(
                  song: song,
                  index: index,
                  isPlaying: playerState.currentSong?.id == song.id,
                  isPlayingPaused: !playerState.isPlaying,
                  onTap: () {
                    context.read<PlayerBloc>().add(
                          PlaySongEvent(
                            song: song,
                            queue: [song],
                            queueIndex: 0,
                          ),
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

    // Artists section
    if (artists.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: PrismSectionHeader(
            title: 'Artists',
            actionLabel: artists.length > 3 ? 'See all' : null,
            onAction: () => _onFilterChanged(SearchFilter.artists),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
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
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subtitle: const Text('Artist'),
              );
            },
          ),
        ),
      );
    }

    // Albums section
    if (albums.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: PrismSectionHeader(
            title: 'Albums',
            actionLabel: albums.length > 4 ? 'See all' : null,
            onAction: () => _onFilterChanged(SearchFilter.albums),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          ),
        ),
      );
      final topAlbums = albums.take(4).toList();
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.builder(
            itemCount: topAlbums.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.78,
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

    // Playlists section
    if (playlists.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: PrismSectionHeader(
            title: 'Playlists',
            actionLabel: playlists.length > 3 ? 'See all' : null,
            onAction: () => _onFilterChanged(SearchFilter.playlists),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
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
                  style: Theme.of(context).textTheme.titleSmall,
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

  // ── Categorized Slivers ───────────────────────────────────────────────────

  List<Widget> _songsSlivers(SearchState state) {
    final songs = state.results.songs;
    if (songs.isEmpty) {
      final hasOtherMatches = !state.results.isEmpty;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: PrismEmptyState(
            icon: Icons.music_note_rounded,
            message: 'No songs found',
            hint: hasOtherMatches
                ? 'Try switching to All to view matches in other categories.'
                : 'Try a different search or check your spelling.',
            actionLabel: hasOtherMatches ? 'Switch to All' : 'Clear Search',
            onAction: hasOtherMatches
                ? () => _onFilterChanged(SearchFilter.all)
                : _clearSearch,
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        sliver: SliverList.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return BlocBuilder<PlayerBloc, PlayerState>(
              buildWhen: (prev, curr) =>
                  (prev.currentSong?.id == song.id) != (curr.currentSong?.id == song.id) ||
                  (prev.isPlaying != curr.isPlaying && curr.currentSong?.id == song.id),
              builder: (context, playerState) => PrismSongTile(
                song: song,
                index: index,
                isPlaying: playerState.currentSong?.id == song.id,
                isPlayingPaused: !playerState.isPlaying,
                onTap: () {
                  context.read<PlayerBloc>().add(
                        PlaySongEvent(
                          song: song,
                          queue: [song],
                          queueIndex: 0,
                        ),
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
      final hasOtherMatches = !state.results.isEmpty;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: PrismEmptyState(
            icon: Icons.person_search_rounded,
            message: 'No artists found',
            hint: hasOtherMatches
                ? 'Try switching to All to view matches in other categories.'
                : 'Try a different search or check your spelling.',
            actionLabel: hasOtherMatches ? 'Switch to All' : 'Clear Search',
            onAction: hasOtherMatches
                ? () => _onFilterChanged(SearchFilter.all)
                : _clearSearch,
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
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
                style: Theme.of(context).textTheme.titleSmall,
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
      final hasOtherMatches = !state.results.isEmpty;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: PrismEmptyState(
            icon: Icons.album_rounded,
            message: 'No albums found',
            hint: hasOtherMatches
                ? 'Try switching to All to view matches in other categories.'
                : 'Try a different search or check your spelling.',
            actionLabel: hasOtherMatches ? 'Switch to All' : 'Clear Search',
            onAction: hasOtherMatches
                ? () => _onFilterChanged(SearchFilter.all)
                : _clearSearch,
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverGrid.builder(
          itemCount: albums.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.78,
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
      final hasOtherMatches = !state.results.isEmpty;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: PrismEmptyState(
            icon: Icons.queue_music_rounded,
            message: 'No playlists found',
            hint: hasOtherMatches
                ? 'Try switching to All to view matches in other categories.'
                : 'Try a different search or check your spelling.',
            actionLabel: hasOtherMatches ? 'Switch to All' : 'Clear Search',
            onAction: hasOtherMatches
                ? () => _onFilterChanged(SearchFilter.all)
                : _clearSearch,
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
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
                style: Theme.of(context).textTheme.titleSmall,
              ),
              subtitle: Text('${playlist.trackCount} tracks'),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _videosSlivers(SearchState state) {
    final videos = state.results.songs;
    final theme = Theme.of(context);

    if (videos.isEmpty) {
      final hasOtherMatches = !state.results.isEmpty;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: PrismEmptyState(
            icon: Icons.video_library_rounded,
            message: 'No videos found',
            hint: hasOtherMatches
                ? 'Try switching to All to view matches in other categories.'
                : 'Try a different search or check your spelling.',
            actionLabel: hasOtherMatches ? 'Switch to All' : 'Clear Search',
            onAction: hasOtherMatches
                ? () => _onFilterChanged(SearchFilter.all)
                : _clearSearch,
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        sliver: SliverList.separated(
          itemCount: videos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final video = videos[index];
            return Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PrismRadius.lg),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: InkWell(
                onTap: () {
                  context.read<PlayerBloc>().add(
                        PlaySongEvent(
                          song: video,
                          queue: [video],
                          queueIndex: 0,
                        ),
                      );
                  if (!widget.embedded) Navigator.of(context).maybePop();
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            video.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: theme.colorScheme.surfaceContainerHigh,
                              child: const Icon(
                                Icons.video_collection_rounded,
                                size: 48,
                              ),
                            ),
                          ),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(PrismSpacing.md - 2),
                              decoration: const BoxDecoration(
                                color: PrismColors.scrim,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: PrismColors.onColor(PrismColors.scrim),
                                size: PrismIconSize.xl - 2,
                              ),
                            ),
                          ),
                          Positioned(
                            right: PrismSpacing.sm,
                            bottom: PrismSpacing.sm,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: PrismSpacing.xs + 2,
                                vertical: PrismSpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: PrismColors.scrimHeavy,
                                borderRadius:
                                    BorderRadius.circular(PrismRadius.xs),
                              ),
                              child: Text(
                                video.durationFormatted,
                                style: PrismText.tabular(
                                  theme.textTheme.labelSmall?.copyWith(
                                    color: PrismColors.onColor(
                                      PrismColors.scrimHeavy,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  video.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall,
                                ),
                                const SizedBox(height: PrismSpacing.xs),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        video.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color:
                                              theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer
                                            .withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(
                                          PrismRadius.xs,
                                        ),
                                      ),
                                      child: Text(
                                        'YouTube · Video',
                                        style: PrismText.tabular(
                                          theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_vert_rounded),
                            onPressed: () =>
                                showPrismSongActions(context, video),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _downloadsSlivers(SearchState state) {
    final songs = state.results.songs;
    if (songs.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: PrismEmptyState(
            icon: Icons.download_done_rounded,
            message: 'No downloaded songs found',
            hint: 'Songs saved offline will appear here.',
            actionLabel: 'Clear Search',
            onAction: _clearSearch,
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        sliver: SliverList.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return BlocBuilder<PlayerBloc, PlayerState>(
              buildWhen: (prev, curr) =>
                  (prev.currentSong?.id == song.id) != (curr.currentSong?.id == song.id) ||
                  (prev.isPlaying != curr.isPlaying && curr.currentSong?.id == song.id),
              builder: (context, playerState) => PrismSongTile(
                song: song,
                index: index,
                isDownloaded: true,
                isPlaying: playerState.currentSong?.id == song.id,
                isPlayingPaused: !playerState.isPlaying,
                onTap: () {
                  context.read<PlayerBloc>().add(
                        PlaySongEvent(
                          song: song,
                          queue: [song],
                          queueIndex: 0,
                        ),
                      );
                  if (!widget.embedded) Navigator.of(context).maybePop();
                },
              ),
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
                    color: PrismColors.scrim.withValues(alpha: .18),
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
            style: theme.textTheme.titleSmall,
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
