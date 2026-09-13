import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/di/injection.dart';
import '../../core/services/settings_service.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/music_repository.dart';
import '../blocs/library/library.dart';
import '../blocs/player/player.dart';
import '../blocs/search/search.dart';
import '../theme/prism_theme.dart';
import '../widgets/player/mini_player.dart';
import 'album_detail_page.dart';
import 'artist_page.dart';
import 'downloads_page.dart';
import 'liked_songs_page.dart';
import 'playlist_detail_page.dart';
import 'recently_played_page.dart';
import 'settings_page.dart';

class PrismShell extends StatefulWidget {
  const PrismShell({super.key});

  @override
  State<PrismShell> createState() => _PrismShellState();
}

class _PrismShellState extends State<PrismShell> {
  int _index = 0;

  void _select(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  void _searchFor(String query) {
    context.read<SearchBloc>().add(
      SearchQueryEvent(query: query, filter: SearchFilter.all),
    );
    _select(1);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(child: _PrismBackdrop()),
          IndexedStack(
            index: _index,
            children: [
              _PrismHome(
                onOpenSearch: () => _select(1),
                onSearchFor: _searchFor,
              ),
              const _PrismSearch(),
              const _PrismLibrary(),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset + 78,
            child: BlocBuilder<PlayerBloc, PlayerState>(
              buildWhen: (before, after) =>
                  before.currentSong?.id != after.currentSong?.id ||
                  before.status != after.status ||
                  before.position != after.position,
              builder: (_, state) => state.currentSong == null
                  ? const SizedBox()
                  : const MiniPlayer(),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: math.max(10, bottomInset),
            child: _PrismDock(index: _index, onSelect: _select),
          ),
        ],
      ),
    );
  }
}

class _PrismBackdrop extends StatelessWidget {
  const _PrismBackdrop();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.9, -1.05),
          radius: 1.25,
          colors: [
            scheme.primary.withValues(alpha: 0.13),
            scheme.surface.withValues(alpha: 0.98),
            scheme.surface,
          ],
          stops: const [0, 0.42, 1],
        ),
      ),
    );
  }
}

class _PrismDock extends StatelessWidget {
  const _PrismDock({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const items = [
      (LucideIcons.house, 'Home'),
      (LucideIcons.search, 'Search'),
      (LucideIcons.libraryBig, 'Library'),
    ];
    return Container(
      height: 68,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final selected = i == index;
          return Expanded(
            child: Semantics(
              selected: selected,
              button: true,
              label: items[i].$2,
              child: InkWell(
                onTap: () => onSelect(i),
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary.withValues(alpha: 0.13)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[i].$1,
                        size: 20,
                        color: selected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].$2,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PrismHome extends StatefulWidget {
  const _PrismHome({required this.onOpenSearch, required this.onSearchFor});

  final VoidCallback onOpenSearch;
  final ValueChanged<String> onSearchFor;

  @override
  State<_PrismHome> createState() => _PrismHomeState();
}

class _PrismHomeState extends State<_PrismHome>
    with AutomaticKeepAliveClientMixin {
  final _settings = SettingsService.instance;
  List<Song> _trending = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _settings.initialize();
    final result = await getIt<MusicRepository>().getTrending(
      region: _settings.countryCode,
      limit: 18,
    );
    if (!mounted) return;
    result.fold(
      (_) => setState(() => _loading = false),
      (songs) => setState(() {
        _trending = songs
            .where((song) {
              final seconds = song.duration.inSeconds;
              return seconds == 0 || (seconds >= 90 && seconds <= 600);
            })
            .take(12)
            .toList();
        _loading = false;
      }),
    );
  }

  void _play(Song song, List<Song> queue) {
    context.read<PlayerBloc>().add(
      PlaySongEvent(
        song: song,
        queue: queue,
        queueIndex: math.max(0, queue.indexWhere((item) => item.id == song.id)),
      ),
    );
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          key: const PageStorageKey('prism_home'),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _PageHeader(
                  eyebrow: _greeting.toUpperCase(),
                  title: 'Find your frequency.',
                  actionIcon: LucideIcons.settings2,
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              sliver: SliverToBoxAdapter(
                child: InkWell(
                  onTap: widget.onOpenSearch,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    height: 58,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.search, color: scheme.primary),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Text(
                            'Song, artist, album or mood',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Icon(
                          LucideIcons.arrowUpRight,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            BlocBuilder<LibraryBloc, LibraryState>(
              builder: (context, state) {
                final recent = state.recentlyPlayed;
                final hero = recent.isNotEmpty
                    ? recent.first
                    : _trending.isNotEmpty
                    ? _trending.first
                    : null;
                if (hero == null) {
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _HeroSkeleton(loading: _loading),
                    ),
                  );
                }
                final queue = recent.isNotEmpty ? recent : _trending;
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _ListeningHero(
                      song: hero,
                      eyebrow: recent.isNotEmpty
                          ? 'CONTINUE LISTENING'
                          : 'START HERE',
                      onPlay: () => _play(hero, queue),
                    ),
                  ),
                );
              },
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 30, 20, 14),
              sliver: SliverToBoxAdapter(
                child: _SectionTitle(
                  title: 'In your orbit',
                  subtitle: 'Trending around you',
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 205,
                child: _loading
                    ? const _HorizontalSkeleton()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        itemCount: math.min(7, _trending.length),
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final song = _trending[index];
                          return _EditorialCover(
                            song: song,
                            width: 146,
                            onTap: () => _play(song, _trending),
                          );
                        },
                      ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 26, 20, 12),
              sliver: SliverToBoxAdapter(
                child: _SectionTitle(
                  title: 'The pulse',
                  subtitle: 'Five tracks moving now',
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.separated(
                itemCount: math.min(5, _trending.length),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final song = _trending[index];
                  return _ChartTrack(
                    index: index,
                    song: song,
                    onTap: () => _play(song, _trending),
                  );
                },
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 30, 20, 14),
              sliver: SliverToBoxAdapter(
                child: _SectionTitle(
                  title: 'Choose a wavelength',
                  subtitle: 'Start with a feeling',
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.55,
                children: [
                  _MoodTile(
                    label: 'Slow glow',
                    colors: const [Color(0xFF123B38), PrismColors.cyan],
                    onTap: () => widget.onSearchFor('chill'),
                  ),
                  _MoodTile(
                    label: 'High voltage',
                    colors: const [Color(0xFF522018), PrismColors.coral],
                    onTap: () => widget.onSearchFor('workout'),
                  ),
                  _MoodTile(
                    label: 'Deep focus',
                    colors: const [Color(0xFF24340D), PrismColors.lime],
                    onTap: () => widget.onSearchFor('focus'),
                  ),
                  _MoodTile(
                    label: 'After dark',
                    colors: const [Color(0xFF25153D), Color(0xFF9667E0)],
                    onTap: () => widget.onSearchFor('night'),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 180)),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _PrismSearch extends StatefulWidget {
  const _PrismSearch();

  @override
  State<_PrismSearch> createState() => _PrismSearchState();
}

class _PrismSearchState extends State<_PrismSearch>
    with AutomaticKeepAliveClientMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final query = value.trim();
    if (query.length < 2) return;
    context.read<SearchBloc>().add(
      SearchQueryEvent(
        query: query,
        filter: context.read<SearchBloc>().state.filter,
      ),
    );
    _focusNode.unfocus();
  }

  void _quickSearch(String query) {
    _controller.text = query;
    _submit(query);
  }

  void _clear() {
    _controller.clear();
    context.read<SearchBloc>().add(const ClearSearchEvent());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      bottom: false,
      child: BlocBuilder<SearchBloc, SearchState>(
        builder: (context, state) {
          if (_controller.text.isEmpty && state.query.isNotEmpty) {
            _controller.text = state.query;
            _controller.selection = TextSelection.collapsed(
              offset: state.query.length,
            );
          }
          return CustomScrollView(
            key: const PageStorageKey('prism_search'),
            slivers: [
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _PageHeader(
                    eyebrow: 'EXPLORE',
                    title: 'Search without limits.',
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _focusNode.hasFocus
                            ? scheme.primary
                            : scheme.outlineVariant,
                        width: _focusNode.hasFocus ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.search, color: scheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            textInputAction: TextInputAction.search,
                            onTap: () => setState(() {}),
                            onSubmitted: _submit,
                            onChanged: (value) {
                              setState(() {});
                              if (value.trim().length >= 2) {
                                context.read<SearchBloc>().add(
                                  FetchSuggestionsEvent(value.trim()),
                                );
                              }
                            },
                            decoration: const InputDecoration(
                              hintText: 'Songs, artists, albums or moods...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        if (_controller.text.isNotEmpty)
                          IconButton(
                            tooltip: 'Clear search',
                            onPressed: _clear,
                            icon: const Icon(LucideIcons.x, size: 18),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (state.status != SearchStatus.initial ||
                  state.query.isNotEmpty)
                SliverToBoxAdapter(
                  child: _SearchFilters(
                    selected: state.filter,
                    onSelect: (filter) {
                      context.read<SearchBloc>().add(UpdateFilterEvent(filter));
                      final query = _controller.text.trim();
                      if (query.length >= 2) {
                        context.read<SearchBloc>().add(
                          SearchQueryEvent(query: query, filter: filter),
                        );
                      }
                    },
                  ),
                ),
              ..._searchBody(context, state),
              const SliverToBoxAdapter(child: SizedBox(height: 180)),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _searchBody(BuildContext context, SearchState state) {
    if (state.status == SearchStatus.initial && state.query.isEmpty) {
      return [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 12),
          sliver: SliverToBoxAdapter(
            child: _SectionTitle(
              title: 'Browse by energy',
              subtitle: 'No algorithm required',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.28,
            children: [
              _MoodTile(
                label: 'Chill',
                colors: const [Color(0xFF0A5850), PrismColors.cyan],
                onTap: () => _quickSearch('chill'),
              ),
              _MoodTile(
                label: 'Party',
                colors: const [Color(0xFF6B2417), PrismColors.coral],
                onTap: () => _quickSearch('party'),
              ),
              _MoodTile(
                label: 'Focus',
                colors: const [Color(0xFF36510A), PrismColors.lime],
                onTap: () => _quickSearch('focus'),
              ),
              _MoodTile(
                label: 'Indie',
                colors: const [Color(0xFF40265C), Color(0xFFB487E8)],
                onTap: () => _quickSearch('indie'),
              ),
              _MoodTile(
                label: 'Hip-hop',
                colors: const [Color(0xFF4D3A06), Color(0xFFFFC83D)],
                onTap: () => _quickSearch('hip hop'),
              ),
              _MoodTile(
                label: 'Electronic',
                colors: const [Color(0xFF12315F), Color(0xFF62A8FF)],
                onTap: () => _quickSearch('electronic'),
              ),
            ],
          ),
        ),
        if (state.history.isNotEmpty) ...[
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 28, 20, 8),
            sliver: SliverToBoxAdapter(
              child: _SectionTitle(title: 'Recent signals'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: math.min(5, state.history.length),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.history, size: 19),
                title: Text(state.history[index]),
                trailing: const Icon(LucideIcons.arrowUpRight, size: 18),
                onTap: () => _quickSearch(state.history[index]),
              ),
            ),
          ),
        ],
      ];
    }
    if (state.status == SearchStatus.loading) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (state.status == SearchStatus.error) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _MessageState(
            icon: LucideIcons.circleAlert,
            title: 'The signal dropped',
            message: state.errorMessage ?? 'Search could not be completed.',
            action: 'Try again',
            onAction: () => _submit(_controller.text),
          ),
        ),
      ];
    }
    final songs = state.results.songs;
    final hasOtherResults =
        state.results.artists.isNotEmpty ||
        state.results.albums.isNotEmpty ||
        state.results.playlists.isNotEmpty;
    if (songs.isEmpty && !hasOtherResults) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _MessageState(
            icon: LucideIcons.searchX,
            title: 'Nothing on this frequency',
            message: 'Try another title, artist, or mood.',
          ),
        ),
      ];
    }
    return [
      if (songs.isNotEmpty) ...[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          sliver: SliverToBoxAdapter(
            child: _SectionTitle(
              title: 'Songs',
              subtitle: '${songs.length} matches',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemCount: songs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final song = songs[index];
              return _SongRow(
                song: song,
                onTap: () => context.read<PlayerBloc>().add(
                  PlaySongEvent(song: song, queue: songs, queueIndex: index),
                ),
              );
            },
          ),
        ),
      ],
      if (state.results.artists.isNotEmpty) ...[
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
          sliver: SliverToBoxAdapter(child: _SectionTitle(title: 'Artists')),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 134,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: state.results.artists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 18),
              itemBuilder: (context, index) {
                final artist = state.results.artists[index];
                return _ArtistBubble(
                  artist: artist,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ArtistPage(
                        artistName: artist.name,
                        artistId: artist.id,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
      if (state.results.albums.isNotEmpty) ...[
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
          sliver: SliverToBoxAdapter(child: _SectionTitle(title: 'Albums')),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 18,
              crossAxisSpacing: 14,
              childAspectRatio: 0.76,
            ),
            itemCount: state.results.albums.length,
            itemBuilder: (context, index) {
              final album = state.results.albums[index];
              return _NamedCover(
                imageUrl: album.thumbnailUrl,
                title: album.title,
                subtitle: album.artist,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AlbumDetailPage(album: album),
                  ),
                ),
              );
            },
          ),
        ),
      ],
      if (state.results.playlists.isNotEmpty) ...[
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
          sliver: SliverToBoxAdapter(child: _SectionTitle(title: 'Playlists')),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemCount: state.results.playlists.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final playlist = state.results.playlists[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 5),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox.square(
                    dimension: 52,
                    child: _NetworkArtwork(url: playlist.thumbnailUrl ?? ''),
                  ),
                ),
                title: Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${playlist.trackCount} songs'),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlaylistDetailPage(playlist: playlist),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ];
  }

  @override
  bool get wantKeepAlive => true;
}

class _SearchFilters extends StatelessWidget {
  const _SearchFilters({required this.selected, required this.onSelect});

  final SearchFilter selected;
  final ValueChanged<SearchFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    const filters = [
      SearchFilter.all,
      SearchFilter.songs,
      SearchFilter.artists,
      SearchFilter.albums,
      SearchFilter.playlists,
    ];
    String label(SearchFilter value) =>
        '${value.name[0].toUpperCase()}${value.name.substring(1)}';
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final filter = filters[index];
          return ChoiceChip(
            label: Text(label(filter)),
            selected: filter == selected,
            onSelected: (_) => onSelect(filter),
          );
        },
      ),
    );
  }
}

class _PrismLibrary extends StatelessWidget {
  const _PrismLibrary();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: BlocBuilder<LibraryBloc, LibraryState>(
        builder: (context, state) {
          return CustomScrollView(
            key: const PageStorageKey('prism_library'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _PageHeader(
                    eyebrow: 'YOURS, LOCALLY',
                    title: 'Your library.',
                    actionIcon: LucideIcons.settings2,
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _LibraryHero(
                    count: state.likedSongs.length,
                    imageUrl: state.likedSongs.isEmpty
                        ? null
                        : state.likedSongs.first.thumbnailUrl,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LikedSongsPage()),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.22,
                  children: [
                    _CollectionTile(
                      icon: LucideIcons.download,
                      title: 'Downloads',
                      count: state.downloads.length,
                      accent: PrismColors.cyan,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DownloadsPage(),
                        ),
                      ),
                    ),
                    _CollectionTile(
                      icon: LucideIcons.history,
                      title: 'History',
                      count: state.recentlyPlayed.length,
                      accent: PrismColors.coral,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RecentlyPlayedPage(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (state.playlists.isNotEmpty) ...[
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 30, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: _SectionTitle(
                      title: 'Playlists',
                      subtitle: 'Your saved sequences',
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 205,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: state.playlists.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final playlist = state.playlists[index];
                        return _PlaylistCover(
                          playlist: playlist,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  PlaylistDetailPage(playlist: playlist),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
              if (state.stats != null && state.stats!.totalPlays > 0) ...[
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: _SectionTitle(title: 'Your signal'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: _StatsStrip(stats: state.stats!),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 180)),
            ],
          );
        },
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.eyebrow,
    required this.title,
    this.actionIcon,
    this.onAction,
  });

  final String eyebrow;
  final String title;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const _PrismMark(size: 44),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                ),
              ),
            ],
          ),
        ),
        if (actionIcon != null)
          IconButton.filledTonal(
            tooltip: 'Settings',
            onPressed: onAction,
            icon: Icon(actionIcon, size: 20),
          ),
      ],
    );
  }
}

class _PrismMark extends StatelessWidget {
  const _PrismMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      padding: EdgeInsets.all(size * 0.2),
      child: CustomPaint(painter: _PrismMarkPainter()),
    );
  }
}

class _PrismMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final triangle = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      triangle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..shader = PrismColors.spectrum.createShader(Offset.zero & size),
    );
    canvas.drawLine(
      Offset(size.width * 0.28, size.height * 0.58),
      Offset(size.width * 0.83, size.height * 0.58),
      Paint()
        ..strokeWidth = 2
        ..shader = PrismColors.spectrum.createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ListeningHero extends StatelessWidget {
  const _ListeningHero({
    required this.song,
    required this.eyebrow,
    required this.onPlay,
  });

  final Song song;
  final String eyebrow;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 1.18,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _NetworkArtwork(url: song.thumbnailUrl, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x22000000),
                    Color(0xEE05070C),
                  ],
                  stops: [0.2, 0.5, 1],
                ),
              ),
            ),
            Positioned(
              left: 22,
              right: 22,
              bottom: 22,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eyebrow,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: PrismColors.cyan,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          song.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton.filled(
                    onPressed: onPlay,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: PrismColors.ink,
                      fixedSize: const Size(58, 58),
                    ),
                    icon: const Icon(LucideIcons.play, size: 25),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _EditorialCover extends StatelessWidget {
  const _EditorialCover({
    required this.song,
    required this.width,
    required this.onTap,
  });
  final Song song;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox.square(
                dimension: width,
                child: _NetworkArtwork(url: song.thumbnailUrl),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartTrack extends StatelessWidget {
  const _ChartTrack({
    required this.index,
    required this.song,
    required this.onTap,
  });
  final int index;
  final Song song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 5),
      leading: SizedBox(
        width: 28,
        child: Text(
          '${index + 1}'.padLeft(2, '0'),
          style: theme.textTheme.titleMedium?.copyWith(
            color: index == 0
                ? PrismColors.coral
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(LucideIcons.play, size: 19),
    );
  }
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.label,
    required this.colors,
    required this.onTap,
  });
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -14,
              top: -10,
              child: Icon(
                LucideIcons.audioWaveform,
                size: 76,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            Positioned(
              left: 16,
              right: 12,
              bottom: 15,
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  const _SongRow({required this.song, required this.onTap});
  final Song song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 5),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox.square(
          dimension: 52,
          child: _NetworkArtwork(url: song.thumbnailUrl),
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        song.durationFormatted,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ArtistBubble extends StatelessWidget {
  const _ArtistBubble({required this.artist, required this.onTap});
  final Artist artist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(44),
        child: Column(
          children: [
            ClipOval(
              child: SizedBox.square(
                dimension: 84,
                child: _NetworkArtwork(url: artist.thumbnailUrl ?? ''),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _NamedCover extends StatelessWidget {
  const _NamedCover({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox.expand(child: _NetworkArtwork(url: imageUrl)),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
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
}

class _LibraryHero extends StatelessWidget {
  const _LibraryHero({
    required this.count,
    required this.imageUrl,
    required this.onTap,
  });
  final int count;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        height: 184,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF642B20), PrismColors.coral],
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Stack(
          children: [
            if (imageUrl != null)
              Positioned(
                right: -20,
                top: -26,
                child: Transform.rotate(
                  angle: 0.12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: SizedBox.square(
                      dimension: 170,
                      child: Opacity(
                        opacity: 0.72,
                        child: _NetworkArtwork(url: imageUrl!),
                      ),
                    ),
                  ),
                ),
              ),
            const Positioned(
              left: 20,
              top: 20,
              child: Icon(LucideIcons.heart, color: Colors.white, size: 28),
            ),
            Positioned(
              left: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Liked Songs',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$count songs',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.icon,
    required this.title,
    required this.count,
    required this.accent,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final int count;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 25),
            const Spacer(),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$count songs',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistCover extends StatelessWidget {
  const _PlaylistCover({required this.playlist, required this.onTap});
  final Playlist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final song = playlist.songs?.isNotEmpty == true
        ? playlist.songs!.first
        : null;
    return SizedBox(
      width: 146,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox.square(
                dimension: 146,
                child: song == null
                    ? const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: PrismColors.spectrum,
                        ),
                        child: Icon(
                          LucideIcons.listMusic,
                          color: PrismColors.ink,
                          size: 36,
                        ),
                      )
                    : _NetworkArtwork(url: song.thumbnailUrl),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${playlist.trackCount} songs',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.stats});
  final ListeningStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hours = stats.totalListeningTime.inMinutes < 60
        ? '${stats.totalListeningTime.inMinutes}m'
        : '${stats.totalListeningTime.inHours}h';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(value: '${stats.totalPlays}', label: 'plays'),
          ),
          Expanded(
            child: _Stat(value: hours, label: 'listened'),
          ),
          Expanded(
            child: _Stat(value: stats.topArtist ?? '—', label: 'top artist'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 3),
      Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class _NetworkArtwork extends StatelessWidget {
  const _NetworkArtwork({required this.url, this.fit = BoxFit.cover});
  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget fallback() => DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.35),
            PrismColors.coral.withValues(alpha: 0.24),
          ],
        ),
      ),
      child: Icon(
        LucideIcons.music2,
        color: scheme.onSurface.withValues(alpha: 0.72),
      ),
    );
    if (url.isEmpty) return fallback();
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (_, __) => fallback(),
      errorWidget: (_, __, ___) => fallback(),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton({required this.loading});
  final bool loading;
  @override
  Widget build(BuildContext context) => Container(
    height: 300,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Center(
      child: loading
          ? const CircularProgressIndicator()
          : const Text('Pull down to reconnect'),
    ),
  );
}

class _HorizontalSkeleton extends StatelessWidget {
  const _HorizontalSkeleton();
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    scrollDirection: Axis.horizontal,
    itemCount: 3,
    separatorBuilder: (_, __) => const SizedBox(width: 14),
    itemBuilder: (_, __) => Container(
      width: 146,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 40),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}
