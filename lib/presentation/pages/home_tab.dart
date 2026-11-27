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
import '../widgets/prism/prism_chart_chip.dart';
import '../widgets/prism/prism_media_card.dart';
import '../widgets/prism/prism_section_header.dart';
import '../widgets/prism/prism_skeleton.dart';
import '../widgets/prism/prism_song_tile.dart';
import '../widgets/prism/prism_states.dart';
import 'album_page.dart';
import 'chart_page.dart';
import 'charts_hub_page.dart';
import 'curated_playlist_page.dart';
import 'genre_browse_page.dart';
import '../../core/services/user_profile_service.dart';
import '../../domain/entities/user_profile.dart';
import '../widgets/profile/profile_switcher_sheet.dart';
import 'recently_played_page.dart';
import 'settings_page.dart';
import '../widgets/home/home_sections_sheet.dart';
import '../widgets/home/home_mood_filter_bar.dart';
import '../widgets/home/home_pinned_playlists_rail.dart';
import '../widgets/home/home_smart_rules_rail.dart';
import '../widgets/home/prism_update_capsule.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/daily_mix_service.dart';
import '../../core/services/living_time_service.dart';
import '../widgets/prism/prism_daily_mix_card.dart';
import 'daily_mix_page.dart';

/// Artwork-led Home surface: calm chrome, artwork carries the colour.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab>
    with AutomaticKeepAliveClientMixin {
  final _settings = SettingsService.instance;
  HomeMoodFilter _activeMood = HomeMoodFilter.all;
  List<Song> _songs = const [];
  List<Song> _recommended = const [];
  List<Album> _newAlbums = const [];
  bool _loading = true;
  bool _loadingRecs = false;
  String? _error;
  AppUpdateInfo? _updateInfo;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadRecommendations();
    _loadNewAlbums();
    _checkAppUpdate();
  }

  Future<void> _checkAppUpdate({bool force = false}) async {
    try {
      final info = await AppUpdateService.instance.checkForUpdate(force: force);
      if (mounted) {
        setState(() {
          _updateInfo = (info != null &&
                  info.hasUpdate &&
                  !AppUpdateService.instance.isDismissed(info.latestVersion))
              ? info
              : null;
        });
      }
    } catch (_) {}
  }

  Future<void> _refreshAll() => Future.wait([
        _load(),
        _loadRecommendations(),
        _loadNewAlbums(),
        _checkAppUpdate(force: true),
      ]);

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
    return LivingTimeService.instance.getSoundscape().greeting;
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
              padding: const EdgeInsets.fromLTRB(
                PrismSpacing.gutter,
                PrismSpacing.lg,
                PrismSpacing.md,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: _TopBar(
                  onSettings: _openSettings,
                  onCustomize: _openCustomizeSections,
                ),
              ),
            ),
            BlocBuilder<LibraryBloc, LibraryState>(
              builder: (context, library) {
                if (_loading) {
                  return SliverMainAxisGroup(
                    slivers: [
                      if (_settings.isHomeSectionEnabled(HomeSectionId.moodChips))
                        SliverPadding(
                          padding: const EdgeInsets.only(top: 12, bottom: 4),
                          sliver: SliverToBoxAdapter(
                            child: HomeMoodFilterBar(
                              selected: _activeMood,
                              onSelect: (m) => setState(() => _activeMood = m),
                            ),
                          ),
                        ),
                      if (_settings.isHomeSectionEnabled(HomeSectionId.hero))
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                PrismSpacing.gutter,
                PrismSpacing.lg,
                PrismSpacing.gutter,
                0,
              ),
                          sliver: SliverToBoxAdapter(
                            child: _Entrance(
                              child: _Hero(
                                greeting: _greeting,
                                song: null,
                                isLoading: true,
                                onPlay: null,
                                onShuffle: null,
                              ),
                            ),
                          ),
                        ),
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
                    ],
                  );
                }

                if (_error != null) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: PrismErrorState(
                      title: 'Could not load home feed',
                      message: _error,
                      onRetry: _load,
                    ),
                  );
                }

                final sectionSlivers = <Widget>[];
                sectionSlivers.add(
                  SliverToBoxAdapter(
                    child: ValueListenableBuilder<AppUpdateInfo?>(
                      valueListenable: AppUpdateService.instance.latestUpdate,
                      builder: (context, notifierInfo, _) {
                        final effectiveUpdate = notifierInfo ?? _updateInfo;
                        if (effectiveUpdate == null ||
                            !effectiveUpdate.hasUpdate ||
                            AppUpdateService.instance
                                .isDismissed(effectiveUpdate.latestVersion)) {
                          return const SizedBox.shrink();
                        }
                        return PrismUpdateCapsule(
                          updateInfo: effectiveUpdate,
                          onDismiss: () {
                            AppUpdateService.instance
                                .dismissVersion(effectiveUpdate.latestVersion);
                            setState(() => _updateInfo = null);
                          },
                        );
                      },
                    ),
                  ),
                );
                for (final sectionId in _settings.homeSectionsOrder) {
                  if (!_settings.isHomeSectionEnabled(sectionId)) continue;
                  final sliver = _buildSectionSliver(sectionId, library);
                  if (sliver != null) {
                    sectionSlivers.add(sliver);
                  }
                }

                return SliverMainAxisGroup(
                  slivers: [
                    ...sectionSlivers,
                    const SliverPadding(padding: EdgeInsets.only(bottom: 140)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildSectionSliver(HomeSectionId sectionId, LibraryState library) {
    switch (sectionId) {
      case HomeSectionId.moodChips:
        return SliverPadding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          sliver: SliverToBoxAdapter(
            child: HomeMoodFilterBar(
              selected: _activeMood,
              onSelect: (mood) => setState(() => _activeMood = mood),
            ),
          ),
        );

      case HomeSectionId.hero:
        final fromHistory = library.recentlyPlayed.isNotEmpty;
        final song = fromHistory
            ? library.recentlyPlayed.first
            : (_songs.isEmpty ? null : _songs.first);
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(
                PrismSpacing.gutter,
                PrismSpacing.lg,
                PrismSpacing.gutter,
                0,
              ),
          sliver: SliverToBoxAdapter(
            child: _Entrance(
              child: _Hero(
                greeting: _greeting,
                song: song,
                isLoading: false,
                onPlay: song == null
                    ? null
                    : () {
                        if (fromHistory) {
                          _play(song, queue: library.recentlyPlayed, index: 0);
                        } else {
                          _play(song, queue: _songs, index: 0);
                        }
                      },
                onShuffle: (fromHistory ? library.recentlyPlayed : _songs).isEmpty
                    ? null
                    : () {
                        final source = fromHistory
                            ? library.recentlyPlayed
                            : _songs;
                        final shuffled = [...source]..shuffle();
                        _play(shuffled.first, queue: shuffled, index: 0);
                      },
              ),
            ),
          ),
        );

      case HomeSectionId.livingPhase:
        final soundscape = LivingTimeService.instance.getSoundscape();
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                PrismSpacing.gutter,
                PrismSpacing.lg,
                PrismSpacing.gutter,
                PrismSpacing.xs,
              ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    soundscape.primaryAccent.withValues(alpha: 0.18),
                    Theme.of(context).colorScheme.surfaceContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(PrismRadius.lg),
                border: Border.all(
                  color: soundscape.primaryAccent.withValues(alpha: 0.28),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        soundscape.icon,
                        size: PrismIconSize.sm,
                        color: soundscape.primaryAccent,
                      ),
                      const SizedBox(width: PrismSpacing.xs + 2),
                      Expanded(
                        child: Text(
                          soundscape.uppercaseTagline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PrismText.overline(context)?.copyWith(
                            color: soundscape.primaryAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: PrismSpacing.xs + 2),
                  Text(
                    soundscape.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: PrismSpacing.xxs),
                  Text(
                    soundscape.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        );

      case HomeSectionId.dailyMixes:
        final mixes = DailyMixService.instance.generateDailyMixes(
          history: library.recentlyPlayed,
          likedSongs: library.likedSongs,
          seedTracks: _songs,
        );
        if (mixes.isEmpty) return null;
        return _sliverSection(
          title: 'Made for you',
          subtitle: 'Made on your phone from what you play',
          child: SizedBox(
            height: 224,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.gutter),
              scrollDirection: Axis.horizontal,
              itemCount: mixes.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: PrismSpacing.railGap),
              itemBuilder: (context, index) {
                final mix = mixes[index];
                return PrismDailyMixCard(
                  mix: mix,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DailyMixPage(mix: mix),
                    ),
                  ),
                );
              },
            ),
          ),
        );

      case HomeSectionId.pinnedPlaylists:
        final pinnedPlaylists = library.playlists.where(
          (p) => _settings.pinnedPlaylistIds.contains(p.id),
        ).toList();
        if (pinnedPlaylists.isEmpty) {
          return null;
        }
        return SliverToBoxAdapter(
          child: HomePinnedPlaylistsRail(
            pinnedIds: _settings.pinnedPlaylistIds,
          ),
        );

      case HomeSectionId.jumpBackIn:
        final heroSong = library.recentlyPlayed.isNotEmpty
            ? library.recentlyPlayed.first
            : (_songs.isEmpty ? null : _songs.first);
        final continueSongs = library.recentlyPlayed
            .where((s) => s.id != heroSong?.id)
            .take(10)
            .toList();
        if (continueSongs.isEmpty) {
          return null;
        }
        return _sliverSection(
          title: 'Jump back in',
          subtitle: 'Continue listening from your recent tracks',
          child: SizedBox(
            height: 190,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.gutter),
              scrollDirection: Axis.horizontal,
              itemCount: continueSongs.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: PrismSpacing.railGap),
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

      case HomeSectionId.recommended:
        if (_loadingRecs) {
          return const SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: PrismSectionHeader(title: 'Recommended for you'),
              ),
              SliverToBoxAdapter(child: PrismRailSkeleton()),
            ],
          );
        }
        final displayRecs = _filteredRecommended();
        if (displayRecs.isEmpty) return null;
        return _sliverSection(
          title: 'Recommended for you',
          subtitle: _activeMood != HomeMoodFilter.all
              ? '${_activeMood.label} picks · $_recommendationSubtitle'
              : _recommendationSubtitle,
          child: SizedBox(
            height: 194,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.gutter),
              scrollDirection: Axis.horizontal,
              itemCount: displayRecs.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: PrismSpacing.railGap),
              itemBuilder: (_, index) {
                final song = displayRecs[index];
                return PrismMediaCard(
                  url: song.thumbnailUrl,
                  title: song.title,
                  subtitle: song.artist,
                  onTap: () => _play(
                    song,
                    index: index,
                    queue: displayRecs,
                  ),
                );
              },
            ),
          ),
        );

      case HomeSectionId.newAlbums:
        if (_newAlbums.isEmpty) return null;
        return _sliverSection(
          title: 'From your artists',
          subtitle: 'Albums to dig into from your rotation',
          child: SizedBox(
            height: 194,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.gutter),
              scrollDirection: Axis.horizontal,
              itemCount: _newAlbums.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: PrismSpacing.railGap),
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
        );

      case HomeSectionId.trending:
        final fromHistory = library.recentlyPlayed.isNotEmpty;
        final startIndex = fromHistory ? 0 : 1;
        final displayTrending = _songs.skip(startIndex).take(8).toList();
        if (displayTrending.isEmpty) return null;
        return _sliverSection(
          title: 'Trending now',
          subtitle: 'Trending in ${_settings.selectedCountry.name}',
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

      case HomeSectionId.charts:
        final charts = ChartService.getAvailableCharts(
          _settings.countryCode,
          _settings.selectedCountry.name,
        );
        return _sliverSection(
          title: 'Top charts',
          subtitle: 'What everyone is playing',
          actionLabel: 'See all',
          onAction: _openCharts,
          child: SizedBox(
            height: 132,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.gutter),
              scrollDirection: Axis.horizontal,
              itemCount: charts.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: PrismSpacing.railGap),
              itemBuilder: (context, index) {
                final chart = charts[index];
                return _ChartTile(
                  chart: chart,
                  onTap: () => _pushChart(chart),
                );
              },
            ),
          ),
        );

      case HomeSectionId.likedThisMonth:
        return const SliverToBoxAdapter(
          child: HomeLikedThisMonthRail(),
        );

      case HomeSectionId.unplayedDownloads:
        return const SliverToBoxAdapter(
          child: HomeUnplayedDownloadsRail(),
        );

      case HomeSectionId.curatedMoods:
        final curated = _filteredCuratedPlaylists();
        if (curated.isEmpty) return null;
        return _sliverSection(
          title: 'Made for your mood',
          subtitle: _activeMood != HomeMoodFilter.all
              ? '${_activeMood.label} mixes'
              : 'Start a mix and keep it moving',
          actionLabel: 'Browse all',
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const GenreBrowsePage(),
            ),
          ),
          child: SizedBox(
            height: 116,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.gutter),
              scrollDirection: Axis.horizontal,
              itemCount: curated.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: PrismSpacing.railGap),
              itemBuilder: (context, index) {
                final playlist = curated[index];
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
        );

      case HomeSectionId.historyPrompt:
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(
                PrismSpacing.gutter,
                PrismSpacing.xl,
                PrismSpacing.gutter,
                PrismSpacing.xxxl,
              ),
          sliver: SliverToBoxAdapter(
            child: _HistoryPrompt(
              hasHistory: library.recentlyPlayed.isNotEmpty,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RecentlyPlayedPage(),
                ),
              ),
            ),
          ),
        );
    }
  }

  List<CuratedPlaylist> _filteredCuratedPlaylists() {
    if (_activeMood == HomeMoodFilter.all) {
      return CuratedPlaylists.all;
    }
    final term = _activeMood.name.toLowerCase();
    final matches = CuratedPlaylists.all.where((p) {
      final name = p.name.toLowerCase();
      final cat = p.category.toLowerCase();
      final tag = p.seasonalTag?.toLowerCase() ?? '';
      if (term == 'focus') {
        return name.contains('focus') ||
            name.contains('study') ||
            name.contains('lo-fi') ||
            tag.contains('lofi') ||
            tag.contains('lo-fi');
      }
      if (term == 'chill') {
        return name.contains('chill') ||
            name.contains('coffee') ||
            name.contains('relax') ||
            tag.contains('autumn');
      }
      if (term == 'workout') {
        return name.contains('workout') ||
            name.contains('dance') ||
            name.contains('party') ||
            name.contains('hitlist');
      }
      if (term == 'energy') {
        return name.contains('energy') ||
            name.contains('hit') ||
            name.contains('trending') ||
            name.contains('hotlist');
      }
      if (term == 'relax') {
        return name.contains('relax') ||
            name.contains('ragas') ||
            name.contains('calm') ||
            name.contains('lo-fi');
      }
      if (term == 'commute') {
        return name.contains('drive') ||
            name.contains('commute') ||
            name.contains('synthwave');
      }
      return name.contains(term) || cat.contains(term);
    }).toList();
    return matches.isNotEmpty ? matches : CuratedPlaylists.all;
  }

  List<Song> _filteredRecommended() {
    if (_activeMood == HomeMoodFilter.all) {
      return _recommended;
    }
    final term = _activeMood.name.toLowerCase();
    final filtered = _recommended.where((song) {
      final title = song.title.toLowerCase();
      final artist = song.artist.toLowerCase();
      final album = song.album?.toLowerCase() ?? '';
      if (term == 'focus') {
        return title.contains('focus') ||
            title.contains('chill') ||
            title.contains('lofi') ||
            artist.contains('lo-fi');
      }
      if (term == 'chill') {
        return title.contains('chill') ||
            title.contains('slow') ||
            title.contains('acoustic') ||
            album.contains('chill');
      }
      if (term == 'workout') {
        return title.contains('workout') ||
            title.contains('beat') ||
            title.contains('remix') ||
            title.contains('dance');
      }
      if (term == 'energy') {
        return title.contains('remix') ||
            title.contains('party') ||
            title.contains('bass') ||
            title.contains('club');
      }
      if (term == 'relax') {
        return title.contains('relax') ||
            title.contains('sleep') ||
            title.contains('piano') ||
            title.contains('calm');
      }
      if (term == 'commute') {
        return title.contains('drive') ||
            title.contains('road') ||
            title.contains('trip');
      }
      return false;
    }).toList();
    return filtered.isNotEmpty ? filtered : _recommended;
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
              padding: const EdgeInsets.fromLTRB(
                PrismSpacing.gutter,
                0,
                PrismSpacing.gutter,
                PrismSpacing.md,
              ),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = context.prismSpec;
    return Row(
    children: [
      const PrismLogoMark(size: 34),
      const SizedBox(width: PrismSpacing.md),
      Text(
        'Prism',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const Spacer(),
      IconButton(
        onPressed: onCustomize,
        tooltip: 'Customize Home',
        icon: const Icon(Icons.tune_rounded, size: PrismIconSize.md),
      ),
      IconButton(
        onPressed: onSettings,
        tooltip: 'Settings',
        icon: const Icon(Icons.settings_rounded, size: PrismIconSize.md),
      ),
      GestureDetector(
        onTap: () => ProfileSwitcherSheet.show(context),
        child: StreamBuilder<UserProfile>(
          stream: UserProfileService.instance.activeProfileStream,
          initialData: UserProfileService.instance.getActiveProfile(),
          builder: (context, snapshot) {
            final profile = snapshot.data ?? UserProfileService.instance.getActiveProfile();
            return Semantics(
              button: true,
              label: 'Profile: ${profile.name}',
              child: Tooltip(
                message: 'Profile: ${profile.name}',
                child: Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: Color(profile.avatarColorValue),
                    shape: BoxShape.circle,
                    border: Border.all(color: spec.hairline, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      profile.avatarEmoji,
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
  }
}

class _Entrance extends StatelessWidget {
  const _Entrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: PrismMotion.slowOf(context),
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

  static String _authenticBadge(Song song) {
    switch (song.source) {
      case MusicSource.local:
        return 'Offline';
      case MusicSource.jiosaavn:
        return 'JioSaavn · 320 kbps AAC';
      case MusicSource.youtube:
      case MusicSource.youtubeMusic:
        return 'YouTube · 160 kbps Opus';
      case MusicSource.spotify:
        return 'Spotify · Matched';
      case MusicSource.appleMusic:
        return 'Apple Music · Matched';
      case MusicSource.unknown:
        return 'Verified Audio';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
                    PrismColors.scrimHeavy,
                    PrismColors.scrim,
                    Colors.transparent,
                  ],
                  stops: const [0, .55, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          greeting.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PrismText.overline(context)?.copyWith(
                            color: PrismColors.onColor(PrismColors.scrim),
                          ),
                        ),
                      ),
                      if (song != null) ...[
                        const SizedBox(width: PrismSpacing.sm),
                        Flexible(
                          child: Text(
                            _authenticBadge(song!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PrismText.overline(context)?.copyWith(
                              color: PrismColors.onColor(PrismColors.scrim)
                                  .withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ],
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
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: PrismColors.onColor(PrismColors.scrim),
                    ),
                  ),
                  const SizedBox(height: PrismSpacing.xxs),
                  Text(
                    song?.artist ?? 'Search millions of songs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: PrismColors.onColor(PrismColors.scrim)
                          .withValues(alpha: .80),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: onPlay,
                        icon: const Icon(
                          Icons.play_arrow_rounded,
                          size: PrismIconSize.md,
                        ),
                        label: const Text('Play'),
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.onSurface,
                          foregroundColor: scheme.surface,
                          padding: const EdgeInsets.symmetric(
                            horizontal: PrismSpacing.md + 2,
                            vertical: PrismSpacing.xs + 2,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: PrismSpacing.sm),
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
            padding: const EdgeInsets.all(PrismSpacing.md + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PrismChartChip(type: chart.iconType, size: 34),
                const Spacer(),
                Text(
                  chart.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: PrismSpacing.xxs),
                Text(
                  chartSourceLabel(chart.source),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PrismText.tabular(
                    theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
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
            padding: const EdgeInsets.all(PrismSpacing.md + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: spec.accentSoft,
                        borderRadius: BorderRadius.circular(PrismRadius.sm),
                      ),
                      child: Icon(
                        playlist.icon,
                        size: PrismIconSize.sm + 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (playlist.seasonalTag != null) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: PrismSpacing.xs + 2,
                            vertical: PrismSpacing.xxs),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(PrismRadius.xs),
                          border: Border.all(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          playlist.seasonalTag!,
                          style: PrismText.overline(context)?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: PrismSpacing.xxs),
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
          padding: const EdgeInsets.all(PrismSpacing.lg),
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: PrismIconSize.lg,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: PrismSpacing.md),
              Expanded(
                child: Text(
                  hasHistory
                      ? 'Open your recently played songs'
                      : 'Your listening history will appear here',
                  style: theme.textTheme.titleSmall,
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
