import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/di/injection.dart';
import '../../domain/entities/album.dart';
import '../../domain/repositories/music_repository.dart';
import '../blocs/player/player.dart';
import '../theme/prism_theme.dart';

class AlbumDetailPage extends StatefulWidget {
  const AlbumDetailPage({super.key, required this.album});
  final Album album;

  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  late Album _album;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _album = widget.album;
    if (_album.songs == null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await getIt<MusicRepository>().getAlbumDetails(_album.id);
    if (!mounted) return;
    result.fold(
      (_) => setState(() => _loading = false),
      (album) => setState(() {
        _album = album;
        _loading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final songs = _album.songs ?? const [];
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(LucideIcons.chevronLeft),
            ),
            expandedHeight: 330,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _album.thumbnailUrl.isEmpty
                      ? const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: PrismColors.spectrum,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: _album.thumbnailUrl,
                          fit: BoxFit.cover,
                        ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xDD080B12)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 22,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ALBUM',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: PrismColors.cyan,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _album.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${_album.artist}${_album.year == null ? '' : ' · ${_album.year}'}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (songs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(LucideIcons.refreshCw),
                  label: const Text('Reload album'),
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text(
                      '${songs.length} TRACKS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    IconButton.filled(
                      tooltip: 'Play album',
                      onPressed: () => context.read<PlayerBloc>().add(
                        PlaySongEvent(
                          song: songs.first,
                          queue: songs,
                          queueIndex: 0,
                        ),
                      ),
                      icon: const Icon(LucideIcons.play),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              sliver: SliverList.separated(
                itemCount: songs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final song = songs[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox(
                      width: 28,
                      child: Text('${index + 1}'.padLeft(2, '0')),
                    ),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      song.durationFormatted,
                      style: theme.textTheme.labelSmall,
                    ),
                    onTap: () => context.read<PlayerBloc>().add(
                      PlaySongEvent(
                        song: song,
                        queue: songs,
                        queueIndex: index,
                      ),
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
}
