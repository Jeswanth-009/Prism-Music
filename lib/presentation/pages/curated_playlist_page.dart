import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/services/curated_playlists.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../blocs/player/player_state.dart';
import '../theme/prism_theme.dart';
import '../widgets/prism/prism_skeleton.dart';
import '../widgets/prism/prism_song_tile.dart';
import '../widgets/prism/prism_states.dart';

/// Page that displays songs from a curated YouTube playlist.
class CuratedPlaylistPage extends StatefulWidget {
  const CuratedPlaylistPage({super.key, required this.playlist});

  final CuratedPlaylist playlist;

  @override
  State<CuratedPlaylistPage> createState() => _CuratedPlaylistPageState();
}

class _CuratedPlaylistPageState extends State<CuratedPlaylistPage> {
  List<Song> _songs = [];
  bool _isLoading = true;
  String? _error;
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
      final result = await repo.getPlaylistDetails(widget.playlist.playlistId);

      if (!mounted) return;
      result.fold(
        // If official fetch fails (RD/OLAK IDs), go to fallback.
        (failure) => _fallbackSearch(),
        (playlist) {
          // Even if it "succeeds", check if the list is actually empty.
          if (playlist.songs == null || playlist.songs!.isEmpty) {
            _fallbackSearch();
          } else {
            setState(() {
              _songs = playlist.songs!;
              _totalDuration = playlist.totalDuration;
              _isLoading = false;
            });
          }
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

      // Adding "official playlist" prevents showing random user-uploaded
      // videos for the same name.
      final query = '"${widget.playlist.name}" official playlist';

      final result = await repo.searchSongs(query, limit: 30);

      if (!mounted) return;
      result.fold(
        (failure) => setState(() {
          _error = failure.message;
          _isLoading = false;
        }),
        (songs) {
          // Only show songs when the API found a real playlist worth of
          // them; 1-2 results are probably unrelated.
          if (songs.length < 3) {
            setState(() {
              _error = 'Official playlist tracks are currently unavailable.';
              _isLoading = false;
            });
          } else {
            setState(() {
              _songs = songs;
              _isLoading = false;
            });
          }
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
      PlaySongEvent(song: shuffled.first, queue: shuffled, queueIndex: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.playlist.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_songs.isNotEmpty) ...[
            IconButton(
              tooltip: 'Shuffle',
              onPressed: _shufflePlay,
              icon: const Icon(Icons.shuffle_rounded),
            ),
            IconButton(
              tooltip: 'Play all',
              onPressed: _playAll,
              icon: const Icon(Icons.play_arrow_rounded),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: PrismListSkeleton(count: 8),
            )
          : _error != null
              ? PrismErrorState(message: _error, onRetry: _loadPlaylist)
              : _songs.isEmpty
                  ? const PrismEmptyState(
                      icon: Icons.music_note_rounded,
                      message: 'No songs found',
                    )
                  : CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: context.prismSpec.accentSoft,
                                    borderRadius:
                                        BorderRadius.circular(PrismRadius.md),
                                  ),
                                  child: Icon(
                                    widget.playlist.icon,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.playlist.category,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      if (_totalDuration != null)
                                        Text(
                                          '${_songs.length} songs · ${_formatDuration(_totalDuration!)}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: _playAll,
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('Play'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 100),
                          sliver: SliverList.builder(
                            itemCount: _songs.length,
                            itemBuilder: (context, index) {
                              final song = _songs[index];
                              return BlocBuilder<PlayerBloc, PlayerState>(
                                builder: (context, playerState) =>
                                    PrismSongTile(
                                  song: song,
                                  index: index,
                                  numbered: true,
                                  isPlaying:
                                      playerState.currentSong?.id == song.id,
                                  isPlayingPaused: !playerState.isPlaying,
                                  onTap: () {
                                    context.read<PlayerBloc>().add(
                                      PlaySongEvent(
                                        song: song,
                                        queue: _songs,
                                        queueIndex: index,
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
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
