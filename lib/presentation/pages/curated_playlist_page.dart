import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/di/injection.dart';
import '../../core/services/curated_playlists.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';

/// Page that displays songs from a curated YouTube playlist.
class CuratedPlaylistPage extends StatefulWidget {
  final CuratedPlaylist playlist;

  const CuratedPlaylistPage({super.key, required this.playlist});

  @override
  State<CuratedPlaylistPage> createState() => _CuratedPlaylistPageState();
}

class _CuratedPlaylistPageState extends State<CuratedPlaylistPage> {
  List<Song> _songs = [];
  bool _isLoading = true;
  String? _error;
  String? _playlistAuthor;
  Duration? _totalDuration;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = getIt<MusicRepository>();
      final result =
          await repo.getPlaylistDetails(widget.playlist.playlistId);

      if (!mounted) return;
      result.fold(
        (failure) {
          // If direct playlist fetch fails (e.g. RDCLAK radio IDs),
          // fall back to searching by the playlist name.
          _fallbackSearch();
        },
        (playlist) {
          setState(() {
            _songs = playlist.songs ?? [];
            _playlistAuthor = playlist.author;
            _totalDuration = playlist.totalDuration;
            _isLoading = false;
          });
        },
      );
    } catch (_) {
      if (!mounted) return;
      _fallbackSearch();
    }
  }

  Future<void> _fallbackSearch() async {
    try {
      final repo = getIt<MusicRepository>();
      final result = await repo.searchSongs(
        widget.playlist.name,
        limit: 30,
      );
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _playAll() {
    if (_songs.isEmpty) return;
    context.read<PlayerBloc>().add(
          PlaySongEvent(song: _songs.first, queue: _songs, queueIndex: 0),
        );
  }

  void _shufflePlay() {
    if (_songs.isEmpty) return;
    final shuffled = List<Song>.from(_songs)..shuffle();
    context.read<PlayerBloc>().add(
          PlaySongEvent(
              song: shuffled.first, queue: shuffled, queueIndex: 0),
        );
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Hero header
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            stretch: true,
            backgroundColor: widget.playlist.gradient.first,
            leading: ShadIconButton.ghost(
              icon:
                  const Icon(LucideIcons.arrowLeft, size: 20, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (_songs.isNotEmpty) ...[
                ShadIconButton.ghost(
                  icon: const Icon(LucideIcons.shuffle,
                      size: 18, color: Colors.white),
                  onPressed: _shufflePlay,
                ),
                ShadIconButton.ghost(
                  icon: const Icon(LucideIcons.circlePlay,
                      size: 20, color: Colors.white),
                  onPressed: _playAll,
                ),
              ],
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.playlist.gradient,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Playlist icon
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(widget.playlist.icon,
                              size: 28, color: Colors.white),
                        ),
                        const SizedBox(height: 16),

                        // Name
                        Text(
                          widget.playlist.name,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),

                        // Metadata row
                        Row(
                          children: [
                            ShadBadge.secondary(
                              child: Text(widget.playlist.category),
                            ),
                            const SizedBox(width: 8),
                            if (_songs.isNotEmpty)
                              Text(
                                '${_songs.length} songs',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                ),
                              ),
                            if (_totalDuration != null) ...[
                              Text(' · ',
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.6))),
                              Text(
                                _formatDuration(_totalDuration!),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              collapseMode: CollapseMode.parallax,
            ),
          ),

          // Action bar
          if (_songs.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ShadButton(
                        onPressed: _playAll,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.play, size: 16),
                            SizedBox(width: 8),
                            Text('Play All'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ShadButton.outline(
                        onPressed: _shufflePlay,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.shuffle, size: 16),
                            SizedBox(width: 8),
                            Text('Shuffle'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Song list
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.circleAlert,
                          size: 48,
                          color: shadTheme.colorScheme.destructive),
                      const SizedBox(height: 12),
                      Text('Failed to load playlist',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: 16),
                      ShadButton.outline(
                        onPressed: _loadPlaylist,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_songs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.music,
                        size: 48,
                        color: shadTheme.colorScheme.mutedForeground),
                    const SizedBox(height: 12),
                    Text('No songs found',
                        style: TextStyle(
                            color: shadTheme.colorScheme.mutedForeground)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              sliver: SliverList.separated(
                itemCount: _songs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final song = _songs[index];
                  return _PlaylistSongTile(
                    song: song,
                    index: index + 1,
                    onTap: () {
                      context.read<PlayerBloc>().add(PlaySongEvent(
                            song: song,
                            queue: _songs,
                            queueIndex: index,
                          ));
                    },
                  );
                },
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final mins = d.inMinutes % 60;
    if (hours > 0) return '$hours hr $mins min';
    return '$mins min';
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Song tile for the playlist detail page
// ─────────────────────────────────────────────────────────────────────────

class _PlaylistSongTile extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;

  const _PlaylistSongTile({
    required this.song,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: ShadCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Index
            SizedBox(
              width: 28,
              child: Text(
                index.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: shadTheme.colorScheme.mutedForeground,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 46,
                height: 46,
                child: song.thumbnailUrl.isNotEmpty
                    ? Image.network(
                        song.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: shadTheme.colorScheme.muted,
                          child: Icon(LucideIcons.music,
                              size: 18,
                              color: shadTheme.colorScheme.mutedForeground),
                        ),
                      )
                    : Container(
                        color: shadTheme.colorScheme.muted,
                        child: Icon(LucideIcons.music,
                            size: 18,
                            color: shadTheme.colorScheme.mutedForeground),
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Title / Artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
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

            // Duration + play icon
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  song.durationFormatted,
                  style: TextStyle(
                    fontSize: 11,
                    color: shadTheme.colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(LucideIcons.play,
                    size: 16, color: shadTheme.colorScheme.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
