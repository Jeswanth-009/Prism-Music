import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../blocs/player/player.dart';
import '../theme/prism_theme.dart';
import '../widgets/prism/prism_artwork.dart';
import '../widgets/prism/prism_sheet.dart';
import '../widgets/prism/prism_skeleton.dart';
import '../widgets/prism/prism_song_tile.dart';
import '../widgets/prism/prism_states.dart';

/// Album detail: artwork header, track list, play/shuffle all.
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

  @override
  void initState() {
    super.initState();
    _album = widget.album;
    if (_album.songs == null || _album.songs!.isEmpty) _load();
  }

  bool get _needsLoad =>
      _album.songs == null ||
      _album.songs!.isEmpty ||
      _album.songs!.length < (_album.trackCount ?? 1);

  Future<void> _load() async {
    if (_album.id.isEmpty || !_needsLoad) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await getIt<MusicRepository>().getAlbumDetails(_album.id);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _error = failure.message;
        _loading = false;
      }),
      (album) => setState(() {
        _album = album;
        _loading = false;
      }),
    );
  }

  List<Song> get _songs => _album.songs ?? const [];

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
    final scheme = theme.colorScheme;
    final songs = _songs;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            expandedHeight: 320,
            title: Text(
              _album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            leading: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Hero(
                      tag: 'album_art_${_album.id}',
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(PrismRadius.lg),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .25),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(PrismRadius.lg),
                          child: PrismArtwork(
                            url: _album.thumbnails.high ??
                                _album.thumbnails.medium ??
                                '',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          Text(
                            _album.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _album.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_loading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: PrismListSkeleton(count: 6),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: PrismErrorState(message: _error, onRetry: _load),
            )
          else if (songs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: PrismEmptyState(
                icon: Icons.album_rounded,
                message: 'No tracks in this album',
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _playAt(0),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      onPressed: _playShuffled,
                      tooltip: 'Shuffle',
                      icon: const Icon(Icons.shuffle_rounded),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 40),
              sliver: SliverList.builder(
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];
                  return BlocBuilder<PlayerBloc, PlayerState>(
                    builder: (context, playerState) => PrismSongTile(
                      song: song,
                      index: index,
                      numbered: true,
                      isPlaying: playerState.currentSong?.id == song.id,
                      isPlayingPaused: !playerState.isPlaying,
                      onTap: () => _playAt(index),
                      onLongPress: () => _showSongActions(song),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSongActions(Song song) {
    showPrismSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrismSheetAction(
              icon: Icons.play_arrow_rounded,
              label: 'Play now',
              onTap: () {
                final index = _songs.indexOf(song);
                Navigator.pop(context);
                if (index >= 0) _playAt(index);
              },
            ),
            PrismSheetAction(
              icon: Icons.playlist_add_rounded,
              label: 'Add to queue',
              onTap: () {
                context.read<PlayerBloc>().add(AddToQueueEvent(song: song));
                Navigator.pop(context);
                showPrismToast(context, 'Added to queue');
              },
            ),
          ],
        ),
      ),
    );
  }
}
