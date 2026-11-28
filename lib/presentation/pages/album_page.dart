import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../blocs/library/library.dart';
import '../blocs/player/player.dart' hide DownloadSongEvent;
import '../theme/prism_theme.dart';
import '../widgets/common/bouncing_tap_widget.dart';
import '../widgets/dialogs/media_share_modal.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/prism/prism_sheet.dart';
import '../widgets/prism/prism_skeleton.dart';
import '../widgets/prism/prism_song_tile.dart';
import '../widgets/prism/prism_states.dart';

/// Album & Single detail page with hero artwork backdrop, dual transport pills,
/// library capsule toggle, and tracklist matching official streaming designs.
class AlbumPage extends StatefulWidget {
  const AlbumPage({super.key, required this.album});

  final Album album;

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  late Album _album;
  bool _loading = false;
  String? _error;
  List<Album> _moreAlbums = const [];

  @override
  void initState() {
    super.initState();
    _album = widget.album;
    if (_album.songs == null || _album.songs!.isEmpty) {
      _load();
    } else {
      _loadMoreByArtist();
    }
  }

  bool get _needsLoad =>
      _album.songs == null ||
      _album.songs!.isEmpty ||
      _album.songs!.length < (_album.trackCount ?? 1);

  Future<void> _load() async {
    final albumIdToFetch = _album.id.isNotEmpty
        ? _album.id
        : (_album.youtubePlaylistId ?? '');
    if (albumIdToFetch.isEmpty || !_needsLoad) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final repo = getIt<MusicRepository>();
    var result = await repo.getAlbumDetails(albumIdToFetch);
    if (result.isLeft() &&
        _album.youtubePlaylistId != null &&
        _album.youtubePlaylistId!.isNotEmpty &&
        _album.youtubePlaylistId != albumIdToFetch) {
      result = await repo.getAlbumDetails(_album.youtubePlaylistId!);
    }
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _error = failure.message;
        _loading = false;
      }),
      (album) {
        setState(() {
          _album = _album.copyWith(
            title: _album.title.isNotEmpty ? _album.title : album.title,
            artist: _album.artist.isNotEmpty && _album.artist != 'Unknown Artist'
                ? _album.artist
                : album.artist,
            thumbnails: _album.thumbnails.best != null
                ? _album.thumbnails
                : album.thumbnails,
            songs: album.songs,
            trackCount: album.trackCount ?? _album.trackCount,
            youtubePlaylistId:
                album.youtubePlaylistId ?? _album.youtubePlaylistId,
            year: _album.year ?? album.year,
          );
          _loading = false;
        });
        _loadMoreByArtist();
      },
    );
  }

  Future<void> _loadMoreByArtist() async {
    if (_album.artist.isEmpty || _album.artist == 'Unknown Artist') return;
    try {
      final repo = getIt<MusicRepository>();
      final res = await repo.searchAlbums(_album.artist, limit: 6);
      if (!mounted) return;
      res.fold((_) {}, (albums) {
        setState(() {
          _moreAlbums = albums.where((a) => a.id != _album.id).take(5).toList();
        });
      });
    } catch (_) {}
  }

  List<Song> get _songs => _album.songs ?? const [];

  void _playAt(int index) {
    if (_songs.isEmpty) return;
    context.read<PlayerBloc>().add(
          PlaySongEvent(
            song: _songs[index],
            queue: _songs,
            queueIndex: index,
          ),
        );
  }

  void _playShuffled() {
    if (_songs.isEmpty) return;
    final shuffled = [..._songs]..shuffle();
    context.read<PlayerBloc>().add(
          PlaySongEvent(song: shuffled.first, queue: shuffled, queueIndex: 0),
        );
  }

  String _formatTotalDuration(List<Song> songs) {
    final totalSeconds =
        songs.fold<int>(0, (sum, s) => sum + s.duration.inSeconds);
    if (totalSeconds <= 0) return '';
    final minutes = totalSeconds ~/ 60;
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remMin = minutes % 60;
    return '$hours hr $remMin min';
  }

  String get _artworkUrl =>
      _album.thumbnails.high ??
      _album.thumbnails.medium ??
      _album.thumbnails.best ??
      (_songs.isNotEmpty ? _songs.first.thumbnailUrl : '');

  String get _formatType {
    if (_songs.length <= 1) return 'Single';
    if (_songs.length <= 5) return 'EP';
    return 'Album';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final songs = _songs;
    final artworkUrl = _artworkUrl;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      bottomNavigationBar: const PrismPersistentMiniPlayer(),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero Backdrop Header ──────────────────────────────────
          SliverToBoxAdapter(
            child: Stack(
              children: [
                // Backdrop Artwork with unconditional dark scrim for white foreground contrast
                Positioned.fill(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (artworkUrl.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: artworkUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorWidget: (_, __, ___) => const SizedBox(),
                        ),
                      // Dark scrim and gradient fading downwards
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              PrismColors.scrim.withValues(alpha: artworkUrl.isNotEmpty ? 0.5 : 0.78),
                              PrismColors.scrimHeavy,
                              theme.colorScheme.surface.withValues(alpha: 0.95),
                              theme.colorScheme.surface,
                            ],
                            stops: const [0.0, 0.45, 0.85, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content Overlay
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Nav Bar Icons
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Back',
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.arrow_back_rounded,
                                  color: PrismColors.onScrim),
                            ),
                            const Spacer(),
                            if (songs.isNotEmpty) ...[
                              IconButton(
                                tooltip: 'Download All',
                                onPressed: () {
                                  for (final s in songs) {
                                    context
                                        .read<LibraryBloc>()
                                        .add(DownloadSongEvent(s));
                                  }
                                  showPrismToast(context, 'Downloading ${songs.length} tracks…');
                                },
                                icon: const Icon(Icons.download_rounded,
                                    color: PrismColors.onScrim),
                              ),
                              IconButton(
                                tooltip: 'Share',
                                onPressed: () {
                                  if (songs.isNotEmpty) {
                                    showMediaShareModal(context, songs.first);
                                  }
                                },
                                icon: const Icon(Icons.share_rounded,
                                    color: PrismColors.onScrim),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 120),

                        // Title
                        Text(
                          _album.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: PrismColors.onScrim,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Artist row with avatar
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: PrismColors.onScrim
                                  .withValues(alpha: 0.24),
                              child: Icon(
                                Icons.person_rounded,
                                size: PrismIconSize.sm - 1,
                                color: PrismColors.onScrim,
                              ),
                            ),
                            const SizedBox(width: PrismSpacing.sm),
                            Expanded(
                              child: Text(
                                _album.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: PrismColors.onScrim
                                      .withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Format & Year
                        Text(
                          '$_formatType • ${_album.year ?? 2026}',
                          style: PrismText.tabular(
                            theme.textTheme.bodySmall?.copyWith(
                              color: PrismColors.onScrim.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Library Capsule Pill Button
                        BlocBuilder<LibraryBloc, LibraryState>(
                          builder: (context, libraryState) {
                            final inLibrary = songs.isNotEmpty &&
                                libraryState.isSongLiked(songs.first.id);
                            return BouncingTapWidget(
                              onTap: () {
                                if (songs.isNotEmpty) {
                                  context
                                      .read<LibraryBloc>()
                                      .add(ToggleLikeSongEvent(songs.first));
                                  showPrismToast(
                                    context,
                                    inLibrary
                                        ? 'Removed from library'
                                        : 'Saved to library',
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: PrismColors.onScrim
                                      .withValues(alpha: 0.14),
                                  borderRadius:
                                      BorderRadius.circular(PrismRadius.pill),
                                  border: Border.all(
                                    color: PrismColors.onScrim
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      inLibrary
                                          ? Icons.bookmark_added_rounded
                                          : Icons.bookmark_add_rounded,
                                      size: PrismIconSize.sm,
                                      color: PrismColors.onScrim,
                                    ),
                                    const SizedBox(width: PrismSpacing.xs + 2),
                                    Text(
                                      inLibrary
                                          ? 'Added to library'
                                          : 'Add to library',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                        color: PrismColors.onScrim,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 18),

                        // Dual Transport Wide Capsule Buttons (Play & Shuffle)
                        Row(
                          children: [
                            // Play Capsule (Solid White)
                            Expanded(
                              child: BouncingTapWidget(
                                onTap: songs.isEmpty ? () {} : () => _playAt(0),
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: scheme.onSurface,
                                    borderRadius:
                                        BorderRadius.circular(PrismRadius.pill),
                                    boxShadow: [
                                      BoxShadow(
                                        color: PrismColors.scrim,
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.play_arrow_rounded,
                                          color: scheme.surface,
                                          size: PrismIconSize.lg),
                                      const SizedBox(width: PrismSpacing.xs + 2),
                                      Text(
                                        'Play',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(color: scheme.surface),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: PrismSpacing.md),

                            // Shuffle Capsule (Dark Translucent)
                            Expanded(
                              child: BouncingTapWidget(
                                onTap: songs.isEmpty ? () {} : _playShuffled,
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: PrismColors.onScrim
                                        .withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(PrismRadius.pill),
                                    border: Border.all(
                                      color: PrismColors.onScrim
                                          .withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.shuffle_rounded,
                                          color: PrismColors.onScrim,
                                          size: PrismIconSize.md),
                                      const SizedBox(width: PrismSpacing.xs + 2),
                                      Text(
                                        'Shuffle',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          color: PrismColors.onScrim,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Tracklist States ──────────────────────────────────────
          if (_loading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: PrismListSkeleton(count: 6),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: PrismErrorState(message: _error, onRetry: _load),
            )
          else if (songs.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: PrismEmptyState(
                icon: Icons.album_rounded,
                message: 'No tracks in this album',
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              sliver: SliverList.builder(
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];
                  return BlocBuilder<PlayerBloc, PlayerState>(
                    buildWhen: (prev, curr) =>
                        (prev.currentSong?.id == song.id) !=
                            (curr.currentSong?.id == song.id) ||
                        (prev.isPlaying != curr.isPlaying &&
                            curr.currentSong?.id == song.id),
                    builder: (context, playerState) => PrismSongTile(
                      song: song,
                      index: index + 1,
                      numbered: true,
                      showOverflowAction: true,
                      isPlaying: playerState.currentSong?.id == song.id,
                      isPlayingPaused: !playerState.isPlaying,
                      onTap: () => _playAt(index),
                    ),
                  );
                },
              ),
            ),

            // Track summary at bottom
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Text(
                  '${_album.year ?? 2026} • ${songs.length} song${songs.length > 1 ? 's' : ''}'
                  '${_formatTotalDuration(songs).isNotEmpty ? ', ${_formatTotalDuration(songs)}' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // "More by [Artist]" Section
            if (_moreAlbums.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Text(
                    'More by ${_album.artist}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 160,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: _moreAlbums.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, idx) {
                      final item = _moreAlbums[idx];
                      return BouncingTapWidget(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AlbumPage(album: item),
                          ),
                        ),
                        child: SizedBox(
                          width: 110,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(PrismRadius.md),
                                child: AspectRatio(
                                  aspectRatio: 1.0,
                                  child: CachedNetworkImage(
                                    imageUrl: item.thumbnails.medium ??
                                        item.thumbnails.high ??
                                        '',
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      color: theme.colorScheme.surfaceContainerHigh,
                                      child: const Icon(Icons.album_rounded),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${item.year ?? 2026}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ],
      ),
    );
  }
}
