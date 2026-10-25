import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/services/smart_playlist_service.dart';
import '../../core/utils/formatters.dart';
import '../blocs/library/library_bloc.dart';
import '../blocs/library/library_event.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../theme/prism_theme.dart';
import '../widgets/prism/prism_sheet.dart';
import '../widgets/prism/prism_song_tile.dart';

/// Detail page for exploring, playing, and saving dynamic smart playlists.
class SmartPlaylistPage extends StatefulWidget {
  final SmartPlaylist smartPlaylist;

  const SmartPlaylistPage({super.key, required this.smartPlaylist});

  @override
  State<SmartPlaylistPage> createState() => _SmartPlaylistPageState();
}

class _SmartPlaylistPageState extends State<SmartPlaylistPage> {
  bool _saving = false;

  int get _totalDurationSeconds => widget.smartPlaylist.songs
      .fold(0, (sum, song) => sum + song.duration.inSeconds);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playlist = widget.smartPlaylist;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      playlist.gradientColors.first.withValues(alpha: 0.8),
                      playlist.gradientColors.last.withValues(alpha: 0.3),
                      theme.colorScheme.surface,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                playlist.icon,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius:
                                          BorderRadius.circular(PrismRadius.xs),
                                    ),
                                    child: Text(
                                      'SMART PLAYLIST',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    playlist.title,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          playlist.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${playlist.trackCount} tracks · ${Formatters.formatDuration(Duration(seconds: _totalDurationSeconds))} · ${playlist.ruleSummary}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: playlist.songs.isEmpty
                          ? null
                          : () {
                              context.read<PlayerBloc>().add(
                                    PlaySongEvent(
                                      song: playlist.songs.first,
                                      queue: playlist.songs,
                                      queueIndex: 0,
                                      userInitiated: true,
                                    ),
                                  );
                            },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Play All'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.shuffle_rounded),
                    tooltip: 'Shuffle',
                    onPressed: playlist.songs.isEmpty
                        ? null
                        : () {
                            final shuffled = List.of(playlist.songs)
                              ..shuffle();
                            context.read<PlayerBloc>().add(
                                  PlaySongEvent(
                                    song: shuffled.first,
                                    queue: shuffled,
                                    queueIndex: 0,
                                    userInitiated: true,
                                  ),
                                );
                          },
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bookmark_add_outlined),
                    tooltip: 'Save as Static Playlist',
                    onPressed: _saving || playlist.songs.isEmpty
                        ? null
                        : _saveAsStatic,
                  ),
                ],
              ),
            ),
          ),
          if (playlist.songs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        playlist.icon,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No tracks in ${playlist.title} yet',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Keep listening to more music to automatically populate this playlist.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = playlist.songs[index];
                    return PrismSongTile(
                      song: song,
                      index: index + 1,
                      onTap: () {
                        context.read<PlayerBloc>().add(
                              PlaySongEvent(
                                song: song,
                                queue: playlist.songs,
                                queueIndex: index,
                                userInitiated: true,
                              ),
                            );
                      },
                    );
                  },
                  childCount: playlist.songs.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _saveAsStatic() async {
    setState(() => _saving = true);
    try {
      final service = getIt<SmartPlaylistService>();
      final savedPlaylist =
          await service.saveAsStaticPlaylist(widget.smartPlaylist);
      if (!mounted) return;
      context.read<LibraryBloc>().add(const LoadLibraryEvent());
      showPrismToast(
        context,
        'Saved "${savedPlaylist.name}" (${savedPlaylist.trackCount} tracks) to your Library',
      );
    } catch (e) {
      if (!mounted) return;
      showPrismToast(context, 'Failed to save playlist: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
