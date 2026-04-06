import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../../core/di/injection.dart';
import '../../core/services/lastfm_service.dart';
import '../../core/services/recommendation_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/curated_playlists.dart';
import '../../core/services/download_service.dart';
import 'package:share_plus/share_plus.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../blocs/player/player_state.dart';
import '../blocs/library/library_bloc.dart';
import '../blocs/library/library_event.dart' hide DownloadSongEvent;
import '../blocs/library/library_state.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/lastfm_login_dialog.dart';
import '../../domain/repositories/library_repository.dart';
import 'downloads_page.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'curated_playlist_page.dart';

const double _kNavBarHeight = 64;
const double _kNavBarBottomPadding = 16;

/// Main home page with bottom navigation
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 1;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);

    return Scaffold(
      extendBody: true,
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: const [_DiscoverTab(), _HomeTab(), _LibraryTab()],
            ),
          ),
          BlocBuilder<PlayerBloc, PlayerState>(
            builder: (context, state) {
              if (state.currentSong == null) return const SizedBox.shrink();
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  _kNavBarHeight + _kNavBarBottomPadding + 8,
                ),
                child: const MiniPlayer(),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: _buildNavBar(shadTheme),
    );
  }

  Widget _buildNavBar(ShadThemeData shadTheme) {
    final items = [
      _NavItem(icon: LucideIcons.compass, label: 'Discover'),
      _NavItem(icon: LucideIcons.house, label: 'Home'),
      _NavItem(icon: LucideIcons.libraryBig, label: 'Library'),
      _NavItem(icon: LucideIcons.settings, label: 'Settings'),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, _kNavBarBottomPadding),
        child: ShadCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isSelected = i == _currentIndex;
              return Expanded(
                child: ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: () {
                    if (i == 3) {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                      return;
                    }
                    setState(() => _currentIndex = i);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: 18,
                        color: isSelected
                            ? shadTheme.colorScheme.primary
                            : shadTheme.colorScheme.mutedForeground,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? shadTheme.colorScheme.primary
                              : shadTheme.colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ─────────────────────────────────────────────
// HOME TAB
// ─────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with AutomaticKeepAliveClientMixin {
  final SettingsService _settingsService = SettingsService.instance;
  List<Song> _trendingSongs = [];
  List<Song> _topSongsToday = [];
  bool _isLoading = true;
  bool _isLoadingTopSongs = true;
  String? _error;
  String? _topSongsError;

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    await _settingsService.initialize();
    _loadTrending();
    _loadTopSongsToday();
  }

  bool _isLikelyPlaylist(Song song) {
    final titleLower = song.title.toLowerCase();
    final artistLower = song.artist.toLowerCase();
    if (titleLower.contains('playlist')) return true;
    if (titleLower.contains('top 50')) return true;
    if (titleLower.contains('top 100')) return true;
    if (titleLower.contains('best of')) return true;
    if (titleLower.contains('mix 20')) return true;
    if (titleLower.contains('hits 20')) return true;
    if (titleLower.contains('mashup')) return true;
    if (titleLower.contains('megamix')) return true;
    if (titleLower.contains('nonstop')) return true;
    if (titleLower.contains('non-stop')) return true;
    if (titleLower.contains('compilation')) return true;
    if (titleLower.contains('top songs')) return true;
    if (titleLower.contains('songs playlist')) return true;
    if (titleLower.contains('chill playlist')) return true;
    if (titleLower.contains('music playlist')) return true;
    if (RegExp(r'top \d+ songs').hasMatch(titleLower)) return true;
    if (RegExp(r'\d+ hour').hasMatch(titleLower)) return true;
    if (artistLower.contains('various')) return true;
    if (artistLower.contains('playlist')) return true;
    if (artistLower.contains('spotify')) return true;
    return false;
  }

  bool _isValidSongDuration(Song song) {
    final seconds = song.duration.inSeconds;
    return seconds >= 120 && seconds <= 420;
  }

  Future<void> _loadTopSongsToday() async {
    if (!mounted) return;
    setState(() {
      _isLoadingTopSongs = true;
      _topSongsError = null;
    });

    try {
      final musicRepository = getIt<MusicRepository>();
      final countryName = _settingsService.selectedCountry.name;
      final currentYear = DateTime.now().year;
      final query = 'new $countryName songs $currentYear official';
      final allSongs = <Song>[];
      final seen = <String>{};

      final result = await musicRepository.searchSongs(query, limit: 20);
      result.fold((failure) => null, (songs) {
        for (final song in songs) {
          final key =
              '${song.title.toLowerCase()}|${song.artist.toLowerCase()}';
          if (seen.contains(key)) continue;
          if (!_isValidSongDuration(song)) continue;
          if (_isLikelyPlaylist(song)) continue;
          seen.add(key);
          allSongs.add(song);
        }
      });

      if (!mounted) return;
      setState(() {
        _topSongsToday = allSongs.take(15).toList();
        _isLoadingTopSongs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _topSongsError = e.toString();
        _isLoadingTopSongs = false;
      });
    }
  }

  Future<void> _loadTrending() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final musicRepository = getIt<MusicRepository>();
      final countryCode = _settingsService.countryCode;
      final result = await musicRepository.getTrending(
        limit: 30,
        region: countryCode,
      );

      if (!mounted) return;
      result.fold(
        (failure) => setState(() {
          _error = failure.message;
          _isLoading = false;
        }),
        (songs) {
          final filtered = songs
              .where((s) => _isValidSongDuration(s) && !_isLikelyPlaylist(s))
              .toList();
          setState(() {
            _trendingSongs = filtered.take(20).toList();
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadTrending(), _loadTopSongsToday()]);
    if (mounted) {
      context.read<LibraryBloc>().add(const LoadLibraryEvent());
    }
  }

  void _playSong(Song song, {List<Song>? queue, int? queueIndex}) {
    context.read<PlayerBloc>().add(
      PlaySongEvent(song: song, queue: queue, queueIndex: queueIndex ?? 0),
    );
    // Refresh history after a short delay to allow addToHistory to complete
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.read<LibraryBloc>().add(const LoadLibraryEvent());
      }
    });
  }

  void _openSearch() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SearchPage()));
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final shadTheme = ShadTheme.of(context);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        edgeOffset: 120,
        onRefresh: _refreshAll,
        child: CustomScrollView(
          key: const PageStorageKey('home_scroll'),
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header + Search
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getGreeting(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: shadTheme.colorScheme.mutedForeground,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Prism Music',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                  color: shadTheme.colorScheme.foreground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ShadIconButton.outline(
                          icon: const Icon(LucideIcons.search, size: 18),
                          onPressed: _openSearch,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Search shortcut
                    GestureDetector(
                      onTap: _openSearch,
                      child: ShadCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.search,
                              size: 18,
                              color: shadTheme.colorScheme.mutedForeground,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Search Prism Music',
                              style: TextStyle(
                                color: shadTheme.colorScheme.mutedForeground,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Recently Played
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: _SectionHeader(
                  title: 'Keep listening',
                  subtitle: 'Jump back into your latest sessions',
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _RecentlyPlayedList(),
              ),
            ),

            // Trending
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: _SectionHeader(
                  title: 'Trending near you',
                  subtitle:
                      '${_settingsService.selectedCountry.flag} ${_settingsService.selectedCountry.name}',
                  actionLabel: _isLoading ? null : 'Refresh',
                  onAction: _isLoading ? null : _loadTrending,
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildTrendingSection()),

            // Fresh picks
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: _SectionHeader(
                  title: 'Fresh picks today',
                  subtitle: 'New drops tuned to your region',
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildTopSongsSection(),
              ),
            ),

            // Curated Playlists – one horizontal section per category
            ...CuratedPlaylists.categories.expand(
              (category) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: _SectionHeader(
                      title: category,
                      subtitle: _curatedSubtitle(category),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 160,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: CuratedPlaylists.forCategory(category).length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final playlist = CuratedPlaylists.forCategory(
                          category,
                        )[index];
                        return _CuratedPlaylistCard(
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
              ],
            ),

            const SliverToBoxAdapter(
              child: SizedBox(
                height: _kNavBarHeight + _kNavBarBottomPadding + 32,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingSection() {
    if (_isLoading) return _buildLoadingCard(height: 230);
    if (_error != null) return _buildErrorCard(_error!, _loadTrending);
    if (_trendingSongs.isEmpty) {
      return _buildEmptyCard('No trending songs available');
    }

    final songs = _trendingSongs.take(10).toList();
    return SizedBox(
      height: 280,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: songs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final song = songs[index];
          return _TrendingCard(
            song: song,
            index: index + 1,
            onTap: () => _playSong(song, queue: songs, queueIndex: index),
          );
        },
      ),
    );
  }

  Widget _buildTopSongsSection() {
    if (_isLoadingTopSongs) {
      return Column(
        children: List.generate(
          3,
          (i) => Padding(
            padding: EdgeInsets.only(bottom: i == 2 ? 0 : 10),
            child: _buildLoadingCard(height: 72),
          ),
        ),
      );
    }
    if (_topSongsError != null) {
      return _buildErrorCard(_topSongsError!, _loadTopSongsToday);
    }
    if (_topSongsToday.isEmpty) {
      return _buildEmptyCard('Queue feels quiet right now.');
    }

    final songs = _topSongsToday.take(6).toList();
    return Column(
      children: [
        for (var i = 0; i < songs.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == songs.length - 1 ? 0 : 10),
            child: _SongListTile(
              song: songs[i],
              index: i + 1,
              onTap: () => _playSong(songs[i], queue: songs, queueIndex: i),
              onLongPress: () => _showSongOptions(context, songs[i]),
            ),
          ),
      ],
    );
  }

  String _curatedSubtitle(String category) {
    switch (category) {
      case 'Global':
        return 'Worldwide hits & trends';
      case 'India':
        return 'Top charts across India';
      case 'Pop & Bollywood':
        return 'Chart-topping pop & Bollywood picks';
      case 'Tollywood':
        return 'Telugu cinema & indie vibes';
      default:
        return '';
    }
  }

  Widget _buildLoadingCard({required double height}) {
    final shadTheme = ShadTheme.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: shadTheme.colorScheme.muted,
      ),
    );
  }

  Widget _buildErrorCard(String message, VoidCallback retry) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ShadAlert.destructive(
        icon: const Icon(LucideIcons.circleAlert, size: 18),
        title: const Text('Something went wrong'),
        description: Text(message),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    final shadTheme = ShadTheme.of(context);
    return ShadCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(
            LucideIcons.clock,
            size: 20,
            color: shadTheme.colorScheme.mutedForeground,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }

  void _showSongOptions(BuildContext context, Song song) {
    showShadSheet(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (ctx) {
        return ShadSheet(
          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          description: Text(song.artist),
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetAction(
                  icon: LucideIcons.play,
                  label: 'Play now',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.read<PlayerBloc>().add(PlaySongEvent(song: song));
                  },
                ),
                _SheetAction(
                  icon: LucideIcons.download,
                  label: 'Download',
                  onTap: () async {
                    Navigator.pop(ctx);
                    context.read<PlayerBloc>().add(DownloadSongEvent(song));
                    final downloadService = getIt<DownloadService>();
                    final downloadPath = await downloadService
                        .getDownloadDirectoryPath();
                    if (!context.mounted) return;
                    ShadToaster.of(context).show(
                      ShadToast(
                        title: const Text('Downloading'),
                        description: Text(
                          'Saving "${song.title}" to $downloadPath',
                        ),
                      ),
                    );

                    Future.delayed(const Duration(seconds: 2), () {
                      if (context.mounted) {
                        context.read<LibraryBloc>().add(
                          const LoadLibraryEvent(),
                        );
                      }
                    });
                  },
                ),
                _SheetAction(
                  icon: LucideIcons.listPlus,
                  label: 'Add to playlist',
                  onTap: () {
                    Navigator.pop(ctx);
                    ShadToaster.of(
                      context,
                    ).show(const ShadToast(title: Text('Coming soon!')));
                  },
                ),
                _SheetAction(
                  icon: LucideIcons.share2,
                  label: 'Share',
                  onTap: () {
                    Navigator.pop(ctx);
                    final videoId = song.youtubeId ?? song.id;
                    final url = 'https://music.youtube.com/watch?v=$videoId';
                    Share.share('${song.title} - ${song.artist}\n$url');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

// ─────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ShadButton.ghost(
      onPressed: onTap,
      width: double.infinity,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: shadTheme.colorScheme.foreground,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      color: shadTheme.colorScheme.mutedForeground,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (actionLabel != null)
          ShadButton.ghost(
            size: ShadButtonSize.sm,
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// RECENTLY PLAYED
// ─────────────────────────────────────────────

class _RecentlyPlayedList extends StatelessWidget {
  const _RecentlyPlayedList();

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    return BlocBuilder<LibraryBloc, LibraryState>(
      builder: (context, state) {
        if (state.recentlyPlayed.isEmpty) {
          return ShadCard(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No recently played songs',
                style: TextStyle(color: shadTheme.colorScheme.mutedForeground),
              ),
            ),
          );
        }

        return SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: state.recentlyPlayed.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final song = state.recentlyPlayed[index];
              return _SongCard(
                song: song,
                onTap: () => context.read<PlayerBloc>().add(
                  PlaySongEvent(
                    song: song,
                    queue: state.recentlyPlayed,
                    queueIndex: index,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// SONG CARD (horizontal)
// ─────────────────────────────────────────────

class _SongCard extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _SongCard({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 148,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShadCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 148,
                  height: 148,
                  child: song.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          song.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallbackArt(shadTheme),
                        )
                      : _fallbackArt(shadTheme),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: shadTheme.colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackArt(ShadThemeData shadTheme) {
    return Container(
      color: shadTheme.colorScheme.muted,
      child: Icon(
        LucideIcons.music,
        size: 40,
        color: shadTheme.colorScheme.mutedForeground,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TRENDING CARD
// ─────────────────────────────────────────────

class _TrendingCard extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;

  const _TrendingCard({
    required this.song,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 168,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [shadTheme.colorScheme.primary, shadTheme.colorScheme.ring],
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShadBadge(child: Text(index.toString().padLeft(2, '0'))),
                const Spacer(),
                Icon(
                  LucideIcons.trendingUp,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: song.thumbnailUrl.isNotEmpty
                    ? Image.network(
                        song.thumbnailUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.black26,
                          child: const Icon(
                            LucideIcons.music,
                            color: Colors.white54,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.black26,
                        child: const Icon(
                          LucideIcons.music,
                          color: Colors.white54,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SONG LIST TILE (vertical list)
// ─────────────────────────────────────────────

class _SongListTile extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SongListTile({
    required this.song,
    required this.index,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ShadCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                index.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: shadTheme.colorScheme.mutedForeground,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 48,
                height: 48,
                child: song.thumbnailUrl.isNotEmpty
                    ? Image.network(
                        song.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: shadTheme.colorScheme.muted,
                          child: Icon(
                            LucideIcons.music,
                            size: 20,
                            color: shadTheme.colorScheme.mutedForeground,
                          ),
                        ),
                      )
                    : Container(
                        color: shadTheme.colorScheme.muted,
                        child: Icon(
                          LucideIcons.music,
                          size: 20,
                          color: shadTheme.colorScheme.mutedForeground,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: shadTheme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  song.durationFormatted,
                  style: TextStyle(
                    fontSize: 12,
                    color: shadTheme.colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  LucideIcons.play,
                  size: 18,
                  color: shadTheme.colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CURATED PLAYLIST CARD
// ─────────────────────────────────────────────

class _CuratedPlaylistCard extends StatelessWidget {
  final CuratedPlaylist playlist;
  final VoidCallback onTap;

  const _CuratedPlaylistCard({required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 190,
        height: 150,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: playlist.gradient,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: playlist.gradient.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background icon watermark
            Positioned(
              right: -14,
              bottom: -14,
              child: Icon(
                playlist.icon,
                size: 80,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      playlist.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Icon + Name
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(playlist.icon, color: Colors.white, size: 22),
                      const SizedBox(height: 6),
                      Text(
                        playlist.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

// ─────────────────────────────────────────────
// DISCOVER TAB
// ─────────────────────────────────────────────

class _DiscoverTab extends StatefulWidget {
  const _DiscoverTab();

  @override
  State<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<_DiscoverTab>
    with AutomaticKeepAliveClientMixin {
  final LastFmService _lastFmService = LastFmService();
  bool _isInitialized = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _recommendations = [];
  RecommendationService? _recommendationService;
  RecommendationMode _activeMode = RecommendationMode.discover;
  bool _isLoadingModeRecommendations = false;
  List<Song> _modeRecommendations = [];
  Song? _recommendationSeedSong;
  String? _modeRecommendationError;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _lastFmService.initialize();
    final musicRepository = getIt<MusicRepository>();
    final libraryRepository = getIt<LibraryRepository>();
    _recommendationService = RecommendationService(
      musicRepository,
      libraryRepository,
    );
    await _recommendationService?.initialize();
    _activeMode = _recommendationService?.mode ?? RecommendationMode.discover;

    setState(() => _isInitialized = true);
    if (_lastFmService.isAuthenticated) _loadRecommendations();
    _loadModeRecommendations(refreshSeed: true);
  }

  Future<void> _loadRecommendations() async {
    setState(() => _isLoading = true);
    try {
      final recommendations = await _lastFmService.getTopTracks(
        limit: 20,
        period: '7day',
      );
      setState(() {
        _recommendations = recommendations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showLoginDialog() async {
    await showDialog(
      context: context,
      builder: (context) => LastFmLoginDialog(
        onLogin: (username, password) async {
          final success = await _lastFmService.authenticate(username, password);
          if (!context.mounted) return;
          Navigator.pop(context);
          if (!mounted) return;
          if (success) {
            ShadToaster.of(
              context,
            ).show(const ShadToast(title: Text('Connected to Last.fm!')));
            _loadRecommendations();
          } else {
            ShadToaster.of(context).show(
              ShadToast.destructive(
                title: const Text('Login failed. Check credentials.'),
              ),
            );
          }
        },
      ),
    );
  }

  Future<Song?> _resolveRecommendationSeedSong() async {
    final playerSong = context.read<PlayerBloc>().state.currentSong;
    if (playerSong != null) return playerSong;

    final historyResult = await getIt<LibraryRepository>().getListeningHistory(
      limit: 1,
    );
    return historyResult.fold((_) => null, (songs) => songs.firstOrNull);
  }

  Future<void> _setRecommendationMode(RecommendationMode mode) async {
    if (_activeMode == mode) return;

    await _recommendationService?.setMode(mode);
    if (!mounted) return;
    setState(() => _activeMode = mode);

    await _loadModeRecommendations(refreshSeed: true);
  }

  Future<void> _loadModeRecommendations({bool refreshSeed = false}) async {
    final recommendationService = _recommendationService;
    if (recommendationService == null) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoadingModeRecommendations = true;
      _modeRecommendationError = null;
    });

    try {
      Song? seedSong = _recommendationSeedSong;
      if (refreshSeed || seedSong == null) {
        seedSong = await _resolveRecommendationSeedSong();
      }

      if (seedSong == null) {
        if (!mounted) return;
        setState(() {
          _recommendationSeedSong = null;
          _modeRecommendations = [];
          _isLoadingModeRecommendations = false;
          _modeRecommendationError =
              'Play at least one song to unlock Similar recommendations.';
        });
        return;
      }

      final songs = await recommendationService.getRecommendations(
        currentSong: seedSong,
        limit: 20,
      );

      if (!mounted) return;
      setState(() {
        _recommendationSeedSong = seedSong;
        _modeRecommendations = songs;
        _isLoadingModeRecommendations = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingModeRecommendations = false;
        _modeRecommendations = [];
        _modeRecommendationError = e.toString();
      });
    }
  }

  void _playModeRecommendationQueue(int index) {
    if (_modeRecommendations.isEmpty ||
        index < 0 ||
        index >= _modeRecommendations.length) {
      return;
    }

    context.read<PlayerBloc>().add(
      PlaySongEvent(
        song: _modeRecommendations[index],
        queue: _modeRecommendations,
        queueIndex: index,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final shadTheme = ShadTheme.of(context);

    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: CustomScrollView(
        key: const PageStorageKey('discover_scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Discover',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: shadTheme.colorScheme.foreground,
                      ),
                    ),
                  ),
                  if (_lastFmService.isAuthenticated)
                    ShadTooltip(
                      builder: (_) =>
                          Text('Last.fm: ${_lastFmService.username}'),
                      child: ShadBadge.destructive(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.circleCheck,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            const Text('Last.fm'),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search shortcut
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchPage()),
                    ),
                    child: ShadCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.search,
                            size: 18,
                            color: shadTheme.colorScheme.mutedForeground,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Songs, artists, albums...',
                            style: TextStyle(
                              color: shadTheme.colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Last.fm connect card
                  if (!_lastFmService.isAuthenticated)
                    ShadCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                LucideIcons.radio,
                                size: 20,
                                color: shadTheme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Personalize your feed',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Link Last.fm to unlock tailored discoveries and scrobble tracking.',
                            style: TextStyle(
                              color: shadTheme.colorScheme.mutedForeground,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ShadButton(
                            leading: const Icon(LucideIcons.link, size: 16),
                            onPressed: _showLoginDialog,
                            child: const Text('Connect Last.fm'),
                          ),
                        ],
                      ),
                    ),

                  if (!_lastFmService.isAuthenticated)
                    const SizedBox(height: 20),

                  // Top Tracks
                  if (_lastFmService.isAuthenticated) ...[
                    const _SectionHeader(title: 'Your Top Tracks'),
                    const SizedBox(height: 12),
                    if (_recommendations.isEmpty && !_isLoading)
                      ShadCard(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No recommendations yet. Start listening!',
                            style: TextStyle(
                              color: shadTheme.colorScheme.mutedForeground,
                            ),
                          ),
                        ),
                      ),
                    if (_recommendations.isNotEmpty)
                      SizedBox(
                        height: 210,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _recommendations.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final track = _recommendations[index];
                            return _LastFmTrackCard(
                              track: track,
                              onTap: () => _searchAndPlay(
                                track['name'],
                                track['artist'],
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],

                  const _SectionHeader(
                    title: 'Smart Recommendations',
                    subtitle: 'Switch between Similar and Discover modes',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ShadButton.outline(
                          onPressed: () => _setRecommendationMode(
                            RecommendationMode.similar,
                          ),
                          child: Text(
                            _activeMode == RecommendationMode.similar
                                ? 'Similar (Active)'
                                : 'Similar',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ShadButton.outline(
                          onPressed: () => _setRecommendationMode(
                            RecommendationMode.discover,
                          ),
                          child: Text(
                            _activeMode == RecommendationMode.discover
                                ? 'Discover (Active)'
                                : 'Discover',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_recommendationSeedSong != null)
                    Text(
                      'Seed: ${_recommendationSeedSong!.artist} - ${_recommendationSeedSong!.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: shadTheme.colorScheme.mutedForeground,
                      ),
                    ),
                  const SizedBox(height: 10),
                  if (_isLoadingModeRecommendations)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_modeRecommendationError != null)
                    ShadCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.info, size: 16),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_modeRecommendationError!)),
                        ],
                      ),
                    )
                  else if (_modeRecommendations.isEmpty)
                    ShadCard(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _activeMode == RecommendationMode.similar
                            ? 'No similar songs found yet. Try playing a track first.'
                            : 'No discovery songs found yet. Try refreshing after a few plays.',
                        style: TextStyle(
                          color: shadTheme.colorScheme.mutedForeground,
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_modeRecommendations.length} tracks ready in queue',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: shadTheme.colorScheme.mutedForeground,
                                ),
                              ),
                            ),
                            ShadButton.ghost(
                              size: ShadButtonSize.sm,
                              onPressed: () => _playModeRecommendationQueue(0),
                              child: const Text('Play All'),
                            ),
                            ShadButton.ghost(
                              size: ShadButtonSize.sm,
                              onPressed: () =>
                                  _loadModeRecommendations(refreshSeed: true),
                              child: const Text('Refresh'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (
                          var i = 0;
                          i < _modeRecommendations.length && i < 8;
                          i++
                        )
                          Padding(
                            padding: EdgeInsets.only(
                              bottom:
                                  i ==
                                      ((_modeRecommendations.length < 8
                                              ? _modeRecommendations.length
                                              : 8) -
                                          1)
                                  ? 0
                                  : 8,
                            ),
                            child: _SongListTile(
                              song: _modeRecommendations[i],
                              index: i + 1,
                              onTap: () => _playModeRecommendationQueue(i),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 20),

                  // Browse by Genre
                  const _SectionHeader(title: 'Browse by Genre'),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
              ),
              delegate: SliverChildListDelegate([
                const _GenreCard(
                  title: 'Pop',
                  color: Colors.pink,
                  query: 'Pop music',
                ),
                const _GenreCard(
                  title: 'Hip-Hop',
                  color: Colors.orange,
                  query: 'Hip-Hop music',
                ),
                const _GenreCard(
                  title: 'Rock',
                  color: Colors.red,
                  query: 'Rock music',
                ),
                const _GenreCard(
                  title: 'Electronic',
                  color: Colors.purple,
                  query: 'Electronic music',
                ),
                const _GenreCard(
                  title: 'R&B',
                  color: Colors.blue,
                  query: 'R&B music',
                ),
                const _GenreCard(
                  title: 'Indie',
                  color: Colors.teal,
                  query: 'Indie music',
                ),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Future<void> _searchAndPlay(String trackName, String artistName) async {
    final query = '$trackName $artistName';
    try {
      final musicRepository = getIt<MusicRepository>();
      final result = await musicRepository.searchSongs(query, limit: 1);
      result.fold(
        (failure) {
          if (mounted) {
            ShadToaster.of(context).show(
              ShadToast.destructive(
                title: Text('Failed to find track: ${failure.message}'),
              ),
            );
          }
        },
        (songs) {
          if (songs.isNotEmpty && mounted) {
            context.read<PlayerBloc>().add(PlaySongEvent(song: songs.first));
          } else if (mounted) {
            ShadToaster.of(
              context,
            ).show(const ShadToast(title: Text('Track not found')));
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ShadToaster.of(
          context,
        ).show(ShadToast.destructive(title: Text('Error: $e')));
      }
    }
  }

  @override
  bool get wantKeepAlive => true;
}

// ─────────────────────────────────────────────
// LASTFM TRACK CARD
// ─────────────────────────────────────────────

class _LastFmTrackCard extends StatelessWidget {
  final Map<String, dynamic> track;
  final VoidCallback onTap;

  const _LastFmTrackCard({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final imageUrl = track['image'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 148,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShadCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 148,
                  height: 148,
                  child: (imageUrl != null && imageUrl.isNotEmpty)
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: shadTheme.colorScheme.muted,
                            child: Icon(
                              LucideIcons.music,
                              size: 40,
                              color: shadTheme.colorScheme.mutedForeground,
                            ),
                          ),
                        )
                      : Container(
                          color: shadTheme.colorScheme.muted,
                          child: Icon(
                            LucideIcons.music,
                            size: 40,
                            color: shadTheme.colorScheme.mutedForeground,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              track['name'] as String? ?? 'Unknown Track',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              track['artist'] as String? ?? 'Unknown Artist',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: shadTheme.colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GENRE CARD
// ─────────────────────────────────────────────

class _GenreCard extends StatelessWidget {
  final String title;
  final Color color;
  final String query;

  const _GenreCard({
    required this.title,
    required this.color,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _CategorySearchPage(query: query)),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withValues(alpha: 0.7)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(14),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CATEGORY SEARCH PAGE
// ─────────────────────────────────────────────

class _CategorySearchPage extends StatefulWidget {
  final String query;
  const _CategorySearchPage({required this.query});

  @override
  State<_CategorySearchPage> createState() => _CategorySearchPageState();
}

class _CategorySearchPageState extends State<_CategorySearchPage> {
  List<Song> _songs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final musicRepository = getIt<MusicRepository>();
      final result = await musicRepository.searchSongs(widget.query, limit: 30);
      result.fold(
        (failure) => setState(() {
          _error = failure.message;
          _isLoading = false;
        }),
        (songs) => setState(() {
          _songs = songs;
          _isLoading = false;
        }),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.query.replaceAll(' music', ''))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: $_error'),
                  const SizedBox(height: 12),
                  ShadButton.outline(
                    onPressed: _loadSongs,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _songs.isEmpty
          ? const Center(child: Text('No songs found'))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _songs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final song = _songs[index];
                return _SongListTile(
                  song: song,
                  index: index + 1,
                  onTap: () {
                    context.read<PlayerBloc>().add(
                      PlaySongEvent(
                        song: song,
                        queue: _songs,
                        queueIndex: index,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────
// LIBRARY TAB
// ─────────────────────────────────────────────

class _LibraryTab extends StatefulWidget {
  const _LibraryTab();

  @override
  State<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<_LibraryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final shadTheme = ShadTheme.of(context);

    return SafeArea(
      child: CustomScrollView(
        key: const PageStorageKey('library_scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your Library',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: shadTheme.colorScheme.foreground,
                      ),
                    ),
                  ),
                  ShadIconButton.outline(
                    icon: const Icon(LucideIcons.plus, size: 18),
                    onPressed: () {
                      ShadToaster.of(context).show(
                        const ShadToast(
                          title: Text('Create playlist coming soon!'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: BlocBuilder<LibraryBloc, LibraryState>(
                builder: (context, state) {
                  if (state.status == LibraryStatus.loading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Library items as cards
                      _LibraryItemCard(
                        icon: LucideIcons.clock,
                        title: 'Recently Played',
                        subtitle: '${state.recentlyPlayed.length} songs',
                        gradient: const [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
                        onTap: () {
                          if (state.recentlyPlayed.isEmpty) {
                            ShadToaster.of(context).show(
                              const ShadToast(
                                title: Text('No recently played songs'),
                              ),
                            );
                          } else {
                            context.read<PlayerBloc>().add(
                              PlaySongEvent(
                                song: state.recentlyPlayed.first,
                                queue: state.recentlyPlayed,
                                queueIndex: 0,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      _LibraryItemCard(
                        icon: LucideIcons.heart,
                        title: 'Liked Songs',
                        subtitle: '${state.likedSongs.length} songs',
                        gradient: const [Color(0xFF614385), Color(0xFF516395)],
                        onTap: () {
                          ShadToaster.of(
                            context,
                          ).show(const ShadToast(title: Text('Liked Songs')));
                        },
                      ),
                      const SizedBox(height: 10),
                      _LibraryItemCard(
                        icon: LucideIcons.download,
                        title: 'Downloads',
                        subtitle: '${state.downloads.length} songs',
                        gradient: const [Color(0xFF11998e), Color(0xFF38ef7d)],
                        showArrow: true,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DownloadsPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      const ShadSeparator.horizontal(),
                      const SizedBox(height: 16),

                      if (state.playlists.isEmpty)
                        ShadCard(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  LucideIcons.listMusic,
                                  size: 40,
                                  color: shadTheme.colorScheme.mutedForeground,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No playlists yet',
                                  style: TextStyle(
                                    color:
                                        shadTheme.colorScheme.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...state.playlists.map(
                          (playlist) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ShadCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: playlist.thumbnailUrl != null
                                          ? Image.network(
                                              playlist.thumbnailUrl!,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              color:
                                                  shadTheme.colorScheme.muted,
                                              child: Icon(
                                                LucideIcons.listMusic,
                                                color: shadTheme
                                                    .colorScheme
                                                    .mutedForeground,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          playlist.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${playlist.trackCount} songs',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: shadTheme
                                                .colorScheme
                                                .mutedForeground,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    LucideIcons.chevronRight,
                                    size: 18,
                                    color:
                                        shadTheme.colorScheme.mutedForeground,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 100),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _LibraryItemCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  final bool showArrow;

  const _LibraryItemCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    this.showArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: ShadCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: shadTheme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            if (showArrow)
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: shadTheme.colorScheme.mutedForeground,
              ),
          ],
        ),
      ),
    );
  }
}
