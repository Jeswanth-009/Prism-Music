import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/services/chart_service.dart';
import '../../core/services/curated_playlists.dart';
import '../../core/services/settings_service.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../blocs/library/library.dart';
import '../blocs/player/player.dart';
import '../theme/prism_theme.dart';
import '../widgets/prism/prism_artwork.dart';
import '../widgets/prism/prism_media_card.dart';
import '../widgets/prism/prism_section_header.dart';
import '../widgets/prism/prism_skeleton.dart';
import '../widgets/prism/prism_song_tile.dart';
import '../widgets/prism/prism_states.dart';
import 'chart_page.dart';
import 'curated_playlist_page.dart';
import 'recently_played_page.dart';
import 'settings_page.dart';

/// Artwork-led Home surface: calm chrome, artwork carries the colour.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab>
    with AutomaticKeepAliveClientMixin {
  final _settings = SettingsService.instance;
  List<Song> _songs = const [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _settings.initialize();
      final result = await getIt<MusicRepository>().getTrending(
        limit: 24,
        region: _settings.countryCode,
      );
      if (!mounted) return;
      result.fold(
        (failure) => setState(() {
          _error = failure.message;
          _loading = false;
        }),
        (songs) => setState(() {
          _songs = songs
              .where((song) => song.duration.inSeconds >= 60)
              .toList();
          _loading = false;
        }),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  void _play(Song song, {int index = 0, List<Song>? queue}) {
    context.read<PlayerBloc>().add(
      PlaySongEvent(song: song, queue: queue ?? _songs, queueIndex: index),
    );
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              sliver: SliverToBoxAdapter(
                child: _TopBar(onSettings: _openSettings),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: BlocBuilder<LibraryBloc, LibraryState>(
                  builder: (context, library) {
                    final song = library.recentlyPlayed.isNotEmpty
                        ? library.recentlyPlayed.first
                        : (_songs.isEmpty ? null : _songs.first);
                    return _Hero(
                      greeting: _greeting,
                      song: song,
                      isLoading: _loading,
                      onPlay: song == null ? null : () => _play(song),
                    );
                  },
                ),
              ),
            ),
            if (_loading) ...[
              const SliverToBoxAdapter(
                child: PrismSectionHeader(title: 'New releases'),
              ),
              const SliverToBoxAdapter(child: PrismRailSkeleton()),
              const SliverToBoxAdapter(
                child: PrismSectionHeader(title: 'Trending now'),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: PrismListSkeleton(count: 4),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 140)),
            ] else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: PrismErrorState(message: _error, onRetry: _load),
              )
            else ...[
              BlocBuilder<LibraryBloc, LibraryState>(
                builder: (context, library) {
                  if (library.recentlyPlayed.length < 2) {
                    return const SliverToBoxAdapter(
                      child: SizedBox.shrink(),
                    );
                  }
                  return _sliverSection(
                    title: 'Jump back in',
                    child: SizedBox(
                      height: 168,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        itemCount: library.recentlyPlayed
                            .take(10)
                            .length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 14),
                        itemBuilder: (_, index) {
                          final songs = library.recentlyPlayed.take(10).toList();
                          final song = songs[index];
                          return PrismMediaCard(
                            url: song.thumbnailUrl,
                            title: song.title,
                            subtitle: song.artist,
                            onTap: () => _play(song, index: index, queue: songs),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
              _sliverSection(
                title: 'New releases',
                subtitle: 'Fresh music for you',
                child: SizedBox(
                  height: 172,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: _songs.take(10).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (_, index) {
                      final song = _songs[index];
                      return PrismMediaCard(
                        url: song.thumbnailUrl,
                        title: song.title,
                        subtitle: song.artist,
                        onTap: () => _play(song, index: index),
                      );
                    },
                  ),
                ),
              ),
              _sliverSection(
                title: 'Trending now',
                subtitle:
                    '${_settings.selectedCountry.flag} ${_settings.selectedCountry.name}',
                actionLabel: 'Refresh',
                onAction: _load,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      for (var i = 0; i < _songs.take(6).length; i++)
                        PrismSongTile(
                          song: _songs[i],
                          index: i,
                          numbered: true,
                          onTap: () => _play(_songs[i], index: i),
                        ),
                    ],
                  ),
                ),
              ),
              _sliverSection(
                title: 'Top charts',
                subtitle: 'What everyone is playing',
                actionLabel: 'See all',
                onAction: _openCharts,
                child: SizedBox(
                  height: 132,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: ChartService.getAvailableCharts(
                      _settings.countryCode,
                      _settings.selectedCountry.name,
                    ).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final chart = ChartService.getAvailableCharts(
                        _settings.countryCode,
                        _settings.selectedCountry.name,
                      )[index];
                      return _ChartTile(
                        chart: chart,
                        onTap: () => _pushChart(chart),
                      );
                    },
                  ),
                ),
              ),
              _sliverSection(
                title: 'Made for your mood',
                subtitle: 'Start a mix and keep it moving',
                child: SizedBox(
                  height: 116,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: CuratedPlaylists.all.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final playlist = CuratedPlaylists.all[index];
                      return _MixTile(
                        playlist: playlist,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                CuratedPlaylistPage(playlist: playlist),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 145),
                sliver: SliverToBoxAdapter(
                  child: BlocBuilder<LibraryBloc, LibraryState>(
                    builder: (context, state) => _HistoryPrompt(
                      hasHistory: state.recentlyPlayed.isNotEmpty,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RecentlyPlayedPage(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _pushChart(ChartDefinition chart) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChartPage(chart: chart)),
    );
  }

  void _openCharts() {
    // Charts live in tab 2; from Home the quickest path is a chart hub push
    // is not available (it is a tab), so open the first chart's hub instead.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChartPage(
          chart: ChartService.getAvailableCharts(
            _settings.countryCode,
            _settings.selectedCountry.name,
          ).first,
        ),
      ),
    );
  }

  SliverPadding _sliverSection({
    required String title,
    required Widget child,
    String? subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) => SliverPadding(
    padding: const EdgeInsets.only(top: 8),
    sliver: SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: PrismSectionHeader(
            title: title,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
        ),
        if (subtitle != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          const SliverToBoxAdapter(child: SizedBox(height: 2)),
        SliverToBoxAdapter(child: child),
      ],
    ),
  );

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSettings});
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const PrismLogoMark(size: 34),
      const SizedBox(width: 11),
      Text(
        'Prism',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -.4,
        ),
      ),
      const Spacer(),
      IconButton(
        onPressed: onSettings,
        tooltip: 'Settings',
        icon: const Icon(Icons.settings_outlined, size: 22),
      ),
    ],
  );
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.greeting,
    required this.song,
    required this.isLoading,
    required this.onPlay,
  });

  final String greeting;
  final Song? song;
  final bool isLoading;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onPlay,
      child: Container(
        height: 296,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PrismRadius.xl),
          color: theme.colorScheme.surfaceContainerHigh,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (song?.thumbnailUrl.isNotEmpty ?? false)
              CachedNetworkImage(
                imageUrl: song!.thumbnailUrl,
                fit: BoxFit.cover,
              )
            else
              Container(
                color: theme.colorScheme.surfaceContainerHigh,
                alignment: Alignment.center,
                child: Icon(
                  Icons.music_note_rounded,
                  size: 56,
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: .4),
                ),
              ),
            // Scrim: dark at the bottom-left where the text sits.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [
                    Colors.black.withValues(alpha: .88),
                    Colors.black.withValues(alpha: .35),
                    Colors.transparent,
                  ],
                  stops: const [0, .55, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: .85),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    song == null
                        ? (isLoading
                            ? 'Finding music for you…'
                            : 'Find your next favourite')
                        : song!.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    song?.artist ?? 'Search millions of songs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: .75),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: onPlay,
                        icon: const Icon(Icons.play_arrow_rounded, size: 22),
                        label: const Text('Play'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
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

/// Flat chart tile — accent icon, no gradient.
class _ChartTile extends StatelessWidget {
  const _ChartTile({required this.chart, required this.onTap});

  final ChartDefinition chart;
  final VoidCallback onTap;

  IconData get _icon => switch (chart.iconType) {
    ChartIconType.global => Icons.public_rounded,
    ChartIconType.viral => Icons.local_fire_department_rounded,
    ChartIconType.trending => Icons.trending_up_rounded,
    ChartIconType.top => Icons.emoji_events_outlined,
    ChartIconType.chart => Icons.bar_chart_rounded,
    ChartIconType.newRelease => Icons.auto_awesome_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = context.prismSpec;
    return SizedBox(
      width: 168,
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PrismRadius.lg),
          side: BorderSide(color: spec.hairline),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PrismRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: spec.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon, size: 18, color: theme.colorScheme.primary),
                ),
                const Spacer(),
                Text(
                  chart.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Open chart',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Flat mix tile for curated playlists.
class _MixTile extends StatelessWidget {
  const _MixTile({required this.playlist, required this.onTap});

  final CuratedPlaylist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = context.prismSpec;
    return SizedBox(
      width: 168,
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PrismRadius.lg),
          side: BorderSide(color: spec.hairline),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PrismRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: spec.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    playlist.icon,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  playlist.category,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryPrompt extends StatelessWidget {
  const _HistoryPrompt({required this.hasHistory, required this.onTap});

  final bool hasHistory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        side: BorderSide(color: context.prismSpec.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasHistory
                      ? 'Open your recently played songs'
                      : 'Your listening history will appear here',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
