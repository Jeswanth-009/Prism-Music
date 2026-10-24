import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/services/chart_service.dart';
import '../../core/services/curated_playlists.dart';
import '../../core/services/recommendation_service.dart';
import '../../core/services/settings_service.dart';
import '../../domain/entities/album.dart';
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
import 'album_page.dart';
import 'chart_page.dart';
import 'charts_hub_page.dart';
import 'curated_playlist_page.dart';
import 'recently_played_page.dart';
import 'settings_page.dart';
import '../widgets/home/home_sections_sheet.dart';

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
  List<Song> _recommended = const [];
  List<Album> _newAlbums = const [];
  bool _loading = true;
  bool _loadingRecs = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadRecommendations();
    _loadNewAlbums();
  }

  Future<void> _refreshAll() =>
      Future.wait([_load(), _loadRecommendations(), _loadNewAlbums()]);

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

  /// Personalised picks. Loads independently of trending so a slow
  /// recommendation fetch never blocks the main feed; empty on failure.
  Future<void> _loadRecommendations() async {
    setState(() => _loadingRecs = true);
    try {
      final songs = await getIt<RecommendationService>().getRecommendations(
        limit: 12,
      );
      if (!mounted) return;
      setState(() {
        _recommended = songs;
        _loadingRecs = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingRecs = false);
    }
  }

  Future<void> _loadNewAlbums() async {
    try {
      final result = await getIt<MusicRepository>().getNewReleases(limit: 12);
      if (!mounted) return;
      result.fold(
        (_) {}, // Albums are a bonus rail; silently omit on failure.
        (albums) => setState(() => _newAlbums = albums),
      );
    } catch (_) {}
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

  String get _recommendationSubtitle =>
      getIt<RecommendationService>().mode == RecommendationMode.discover
          ? 'Discover something new'
          : 'Because of what you play';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _refreshAll,
        child: CustomScrollView(
          key: const PageStorageKey('prism_home'),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              sliver: SliverToBoxAdapter(
                child: _TopBar(
                  onSettings: _openSettings,
                  onCustomize: _openCustomizeSections,
                ),
              ),
            ),
            if (_settings.isHomeSectionEnabled(HomeSectionId.hero))
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: BlocBuilder<LibraryBloc, LibraryState>(
                  builder: (context, library) {
                    final fromHistory = library.recentlyPlayed.isNotEmpty;
                    final song = fromHistory
                        ? library.recentlyPlayed.first
                        : (_songs.isEmpty ? null : _songs.first);
                    return _Entrance(
                      child: _Hero(
                        greeting: _greeting,
                        song: song,
                        isLoading: _loading,
                        onPlay: song == null
                            ? null
                            : () {
                                if (fromHistory) {
                                  _play(song,
                                      queue: library.recentlyPlayed, index: 0);
                                } else {
                                  _play(song, queue: _songs, index: 0);
                                }
                              },
                        onShuffle: (fromHistory
                                    ? library.recentlyPlayed
                                    : _songs)
                                .isEmpty
                            ? null
                            : () {
                                final source = fromHistory
                                    ? library.recentlyPlayed
                                    : _songs;
                                final shuffled = [...source]..shuffle();
                                _play(shuffled.first,
                                    queue: shuffled, index: 0);
                              },
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_loading) ...[
              const SliverToBoxAdapter(
                child: PrismSectionHeader(title: 'Recommended for you'),
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
              if (_settings.isHomeSectionEnabled(HomeSectionId.jumpBackIn))
                BlocBuilder<LibraryBloc, LibraryState>(
                  builder: (context, library) {
                    final heroSong = library.recentlyPlayed.isNotEmpty
                        ? library.recentlyPlayed.first
                        : (_songs.isEmpty ? null : _songs.first);
                    // Exclude hero song so we never duplicate covers above the fold
                    final continueSongs = library.recentlyPlayed
                        .where((s) => s.id != heroSong?.id)
                        .take(10)
                        .toList();
                    if (continueSongs.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: SizedBox.shrink(),
                      );
                    }
                    return _sliverSection(
                      title: 'Jump back in',
                      subtitle: 'Continue listening from your recent tracks',
                      child: SizedBox(
                        height: 190,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          scrollDirection: Axis.horizontal,
                          itemCount: continueSongs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                          itemBuilder: (_, index) {
                            final song = continueSongs[index];
                            return PrismMediaCard(
                              url: song.thumbnailUrl,
                              title: song.title,
                              subtitle: song.artist,
                              onTap: () => _play(song,
                                  index: index + 1, queue: library.recentlyPlayed),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              // Recommended for you — omitted entirely when the service
              // has nothing to offer.
              if (_settings.isHomeSectionEnabled(HomeSectionId.recommended)) ...[
                if (_loadingRecs) ...[
                  const SliverToBoxAdapter(
                    child: PrismSectionHeader(title: 'Recommended for you'),
                  ),
                  const SliverToBoxAdapter(child: PrismRailSkeleton()),
                ] else if (_recommended.length >= 3)
                  _sliverSection(
                    title: 'Recommended for you',
                    subtitle: _recommendationSubtitle,
                    child: SizedBox(
                      height: 194,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        itemCount: _recommended.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (_, index) {
                          final song = _recommended[index];
                          return PrismMediaCard(
                            url: song.thumbnailUrl,
                            title: song.title,
                            subtitle: song.artist,
                            onTap: () => _play(
                              song,
                              index: index,
                              queue: _recommended,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
              if (_settings.isHomeSectionEnabled(HomeSectionId.newAlbums) &&
                  _newAlbums.isNotEmpty)
                _sliverSection(
                  title: 'From your artists',
                  subtitle: 'Albums to dig into from your rotation',
                  child: SizedBox(
                    height: 194,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: _newAlbums.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (_, index) {
                        final album = _newAlbums[index];
                        return PrismMediaCard(
                          url: album.thumbnails.high ??
                              album.thumbnails.medium ??
                              '',
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
                ),
              if (_settings.isHomeSectionEnabled(HomeSectionId.trending))
                BlocBuilder<LibraryBloc, LibraryState>(
                  builder: (context, library) {
                    final fromHistory = library.recentlyPlayed.isNotEmpty;
                    final startIndex = fromHistory ? 0 : 1;
                    final displayTrending = _songs.skip(startIndex).take(8).toList();
                    return _sliverSection(
                      title: 'Trending now',
                      subtitle:
                          '${_settings.selectedCountry.flag} ${_settings.selectedCountry.name}',
                      actionLabel: 'Refresh',
                      onAction: _load,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: [
                            for (var i = 0; i < displayTrending.length; i++)
                              PrismSongTile(
                                song: displayTrending[i],
                                index: startIndex + i,
                                numbered: true,
                                onTap: () => _play(displayTrending[i], index: startIndex + i),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              if (_settings.isHomeSectionEnabled(HomeSectionId.charts))
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
              if (_settings.isHomeSectionEnabled(HomeSectionId.curatedMoods))
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
              if (_settings.isHomeSectionEnabled(HomeSectionId.historyPrompt))
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ChartsHubPage(),
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

  void _openCustomizeSections() {
    HomeSectionsCustomizerSheet.show(
      context,
      onChanged: () => setState(() {}),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSettings, required this.onCustomize});
  final VoidCallback onSettings;
  final VoidCallback onCustomize;

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
        onPressed: onCustomize,
        tooltip: 'Customize Home',
        icon: const Icon(Icons.tune_rounded, size: 21),
      ),
      IconButton(
        onPressed: onSettings,
        tooltip: 'Settings',
        icon: const Icon(Icons.settings_outlined, size: 22),
      ),
    ],
  );
}

class _Entrance extends StatelessWidget {
  const _Entrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: PrismMotion.curve,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.greeting,
    required this.song,
    required this.isLoading,
    required this.onPlay,
    required this.onShuffle,
  });

  final String greeting;
  final Song? song;
  final bool isLoading;
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onPlay,
      child: Container(
        height: 152,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PrismRadius.lg),
          color: theme.colorScheme.surfaceContainerHigh,
          border: Border.all(color: context.prismSpec.hairline),
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
                  size: 40,
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
                    Colors.black.withValues(alpha: .90),
                    Colors.black.withValues(alpha: .45),
                    Colors.black.withValues(alpha: .15),
                  ],
                  stops: const [0, .6, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      greeting.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    song == null
                        ? (isLoading
                            ? 'Finding music for you…'
                            : 'Find your next favourite')
                        : song!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    song?.artist ?? 'Search millions of songs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: .80),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: onPlay,
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Play'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _HeroIconButton(
                        icon: Icons.shuffle_rounded,
                        tooltip: 'Shuffle all',
                        onPressed: onShuffle,
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


/// Translucent white icon button used on the dark hero scrim.
class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: .18),
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white24),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 44,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
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
