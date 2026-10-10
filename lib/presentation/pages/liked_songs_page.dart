import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/song.dart';
import '../blocs/library/library_bloc.dart';
import '../blocs/library/library_state.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../blocs/player/player_state.dart';
import '../theme/prism_theme.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/prism/prism_song_tile.dart';
import '../widgets/prism/prism_states.dart';

enum _LikedSort { recent, title, artist }

/// Full collection experience for Liked Songs with header, search, sort, and playback controls.
class LikedSongsPage extends StatefulWidget {
  const LikedSongsPage({super.key});

  @override
  State<LikedSongsPage> createState() => _LikedSongsPageState();
}

class _LikedSongsPageState extends State<LikedSongsPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  _LikedSort _sort = _LikedSort.recent;
  bool _showSearch = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Song> _filterAndSort(List<Song> source) {
    var list = source;
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((s) {
        return s.title.toLowerCase().contains(query) ||
            s.artist.toLowerCase().contains(query);
      }).toList();
    } else {
      list = List.of(list);
    }

    switch (_sort) {
      case _LikedSort.recent:
        break; // already in natural library order
      case _LikedSort.title:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case _LikedSort.artist:
        list.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
    }
    return list;
  }

  void _playAll(List<Song> songs, {bool shuffle = false}) {
    if (songs.isEmpty) return;
    final queue = shuffle ? ([...songs]..shuffle()) : songs;
    context.read<PlayerBloc>().add(
      PlaySongEvent(song: queue.first, queue: queue, queueIndex: 0),
    );
  }

  String _formatTotalDuration(List<Song> songs) {
    var totalSeconds = 0;
    for (final s in songs) {
      totalSeconds += s.duration.inSeconds;
    }
    final minutes = totalSeconds ~/ 60;
    final hours = minutes ~/ 60;
    if (hours > 0) {
      return '$hours hr ${minutes % 60} min';
    }
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      bottomNavigationBar: const PrismPersistentMiniPlayer(),
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Liked Songs'),
        actions: [
          IconButton(
            tooltip: _showSearch ? 'Hide search' : 'Search in liked songs',
            icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) _searchCtrl.clear();
              });
            },
          ),
          PopupMenuButton<_LikedSort>(
            tooltip: 'Sort by',
            icon: const Icon(Icons.sort_rounded),
            initialValue: _sort,
            onSelected: (val) => setState(() => _sort = val),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _LikedSort.recent,
                child: Text('Recently added'),
              ),
              PopupMenuItem(
                value: _LikedSort.title,
                child: Text('Title'),
              ),
              PopupMenuItem(
                value: _LikedSort.artist,
                child: Text('Artist'),
              ),
            ],
          ),
        ],
      ),
      body: BlocBuilder<LibraryBloc, LibraryState>(
        builder: (context, state) {
          final allSongs = state.likedSongs;
          if (allSongs.isEmpty) {
            return const PrismEmptyState(
              icon: Icons.favorite_outline_rounded,
              message: 'Songs you love live here',
              hint:
                  'Tap the heart while listening and Prism will keep it in your private library.',
            );
          }

          final displaySongs = _filterAndSort(allSongs);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.tertiary,
                                ],
                              ),
                              borderRadius:
                                  BorderRadius.circular(PrismRadius.lg),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.28),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${allSongs.length} ${allSongs.length == 1 ? 'song' : 'songs'}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatTotalDuration(allSongs),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _playAll(displaySongs),
                              icon: const Icon(Icons.play_arrow_rounded, size: 22),
                              label: const Text('Play all'),
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _playAll(displaySongs, shuffle: true),
                              icon: const Icon(Icons.shuffle_rounded, size: 20),
                              label: const Text('Shuffle'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_showSearch) ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Filter liked songs…',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        size: 18),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHigh
                                .withValues(alpha: 0.5),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(PrismRadius.lg),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (displaySongs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: PrismEmptyState(
                    icon: Icons.search_off_rounded,
                    message: 'No matching songs',
                    hint: 'Try a different search term.',
                    actionLabel: 'Clear filter',
                    onAction: () => setState(() => _searchCtrl.clear()),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
                  sliver: SliverList.builder(
                    itemCount: displaySongs.length,
                    itemBuilder: (context, index) {
                      final song = displaySongs[index];
                      return BlocBuilder<PlayerBloc, PlayerState>(
                        builder: (context, playerState) => PrismSongTile(
                          song: song,
                          isPlaying: playerState.currentSong?.id == song.id,
                          isPlayingPaused: !playerState.isPlaying,
                          onTap: () => context.read<PlayerBloc>().add(
                            PlaySongEvent(
                              song: song,
                              queue: displaySongs,
                              queueIndex: index,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
