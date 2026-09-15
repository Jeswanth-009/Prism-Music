import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../blocs/player/player.dart';
import '../theme/prism_theme.dart';
import '../widgets/prism/prism_skeleton.dart';
import '../widgets/prism/prism_song_tile.dart';
import '../widgets/prism/prism_states.dart';

/// Detail view for a remote (YouTube/Spotify) playlist discovered via
/// search. Loads full track data through [MusicRepository].
class RemotePlaylistPage extends StatefulWidget {
  const RemotePlaylistPage({super.key, required this.playlist});

  final Playlist playlist;

  @override
  State<RemotePlaylistPage> createState() => _RemotePlaylistPageState();
}

class _RemotePlaylistPageState extends State<RemotePlaylistPage> {
  List<Song> _songs = const [];
  bool _loading = true;
  String? _error;

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
      final result =
          await getIt<MusicRepository>().getPlaylistDetails(widget.playlist.id);
      if (!mounted) return;
      result.fold(
        (failure) => setState(() {
          _error = failure.message;
          _loading = false;
        }),
        (playlist) {
          final songs = playlist.songs ?? const <Song>[];
          setState(() {
            _songs = songs;
            _error = songs.isEmpty
                ? 'No tracks could be loaded for this playlist.'
                : null;
            _loading = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _playAt(int index) {
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
              onPressed: _playShuffled,
              icon: const Icon(Icons.shuffle_rounded),
            ),
            IconButton(
              tooltip: 'Play all',
              onPressed: () => _playAt(0),
              icon: const Icon(Icons.play_arrow_rounded),
            ),
          ],
        ],
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: PrismListSkeleton(count: 8),
            )
          : _error != null
              ? PrismErrorState(message: _error, onRetry: _load)
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
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
                              child: widget.playlist.thumbnails?.medium !=
                                      null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        PrismRadius.md,
                                      ),
                                      child: Image.network(
                                        widget.playlist.thumbnails!.medium!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.queue_music_rounded,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.queue_music_rounded,
                                      color: theme.colorScheme.primary,
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                '${_songs.length} songs · from search',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 100),
                      sliver: SliverList.builder(
                        itemCount: _songs.length,
                        itemBuilder: (context, index) {
                          final song = _songs[index];
                          return BlocBuilder<PlayerBloc, PlayerState>(
                            builder: (context, playerState) => PrismSongTile(
                              song: song,
                              index: index,
                              numbered: true,
                              isPlaying:
                                  playerState.currentSong?.id == song.id,
                              isPlayingPaused: !playerState.isPlaying,
                              onTap: () => _playAt(index),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
