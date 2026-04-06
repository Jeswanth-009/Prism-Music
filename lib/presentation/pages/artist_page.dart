import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/di/injection.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';

class ArtistPage extends StatefulWidget {
  final String artistName;
  final String? artistId;
  final String? heroTag;
  final String? thumbnailUrl;

  const ArtistPage({
    super.key,
    required this.artistName,
    this.artistId,
    this.heroTag,
    this.thumbnailUrl,
  });

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  final MusicRepository _musicRepository = getIt<MusicRepository>();

  bool _loading = true;
  String? _error;
  Artist? _artist;
  List<Song> _topSongs = const [];
  List<Album> _albums = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Returns true if the string looks like a YouTube channel ID rather than a name
  bool _isChannelId(String? value) {
    if (value == null || value.isEmpty) return true;
    // YouTube channel IDs start with UC and are 24 characters
    if (value.startsWith('UC') && value.length >= 20 && !value.contains(' ')) return true;
    return false;
  }

  Artist _mergeArtist({
    Artist? base,
    Artist? details,
    Thumbnails? fallbackThumbnail,
  }) {
    final primary = details ?? base;
    final thumbnail =
        details?.thumbnails ?? base?.thumbnails ?? fallbackThumbnail;

    // Pick the best name: prefer one that is NOT a channel ID
    String resolvedName = widget.artistName;
    if (!_isChannelId(details?.name)) {
      resolvedName = details!.name;
    } else if (!_isChannelId(base?.name)) {
      resolvedName = base!.name;
    }

    final resolved = primary ??
        Artist(
          id: widget.artistId ?? widget.artistName,
          name: resolvedName,
          thumbnails: fallbackThumbnail,
        );

    return resolved.copyWith(
      name: resolvedName,
      thumbnails: thumbnail,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final fallbackThumb = widget.thumbnailUrl != null
          ? Thumbnails.fromUrl(widget.thumbnailUrl!)
          : null;
      Artist? artist;

      if (widget.artistId != null) {
        final details =
            await _musicRepository.getArtistDetails(widget.artistId!);
        details.fold((failure) => _error = failure.message, (data) {
          artist = _mergeArtist(
              base: artist,
              details: data.artist,
              fallbackThumbnail: fallbackThumb);
          _topSongs = data.topSongs;
          _albums = data.albums;
        });
      }

      if (artist == null) {
        final searchResult = await _musicRepository
            .searchArtists(widget.artistName, limit: 1);
        searchResult.fold((failure) => _error = failure.message,
            (artists) {
          if (artists.isNotEmpty) {
            artist = _mergeArtist(
                base: artists.first,
                details: null,
                fallbackThumbnail: fallbackThumb);
          }
        });

        if (artist != null) {
          final details =
              await _musicRepository.getArtistDetails(artist!.id);
          details.fold((failure) => _error = failure.message,
              (data) {
            artist = _mergeArtist(
                base: artist,
                details: data.artist,
                fallbackThumbnail: fallbackThumb);
            _topSongs = data.topSongs;
            _albums = data.albums;
          });
        }
      }

      if (_topSongs.isEmpty) {
        final songsResult = await _musicRepository
            .searchSongs('${widget.artistName} top songs', limit: 15);
        songsResult.fold(
            (failure) =>
                logError('Top songs search failed', failure.message),
            (songs) => _topSongs = songs);
      }

      if (_albums.isEmpty) {
        final albumsResult = await _musicRepository
            .searchAlbums(widget.artistName, limit: 6);
        albumsResult.fold(
            (failure) =>
                logError('Albums search failed', failure.message),
            (albums) => _albums = albums);
      }

      setState(() {
        _artist = _mergeArtist(
            base: artist, details: null, fallbackThumbnail: fallbackThumb);
        _loading = false;
      });
    } catch (e, stack) {
      logError('Artist load failed', e, stack);
      setState(() {
        _error = 'Failed to load artist';
        _loading = false;
      });
    }
  }

  void _playSong(Song song, List<Song> queue) {
    final bloc = context.read<PlayerBloc>();
    bloc.add(PlaySongEvent(
        song: song, queue: queue, queueIndex: queue.indexOf(song)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: _loading
          ? const Center(child: ShadProgress())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShadAlert.destructive(
                        icon: const Icon(LucideIcons.circleAlert),
                        title: Text(_error!),
                      ),
                      const SizedBox(height: 12),
                      ShadButton.outline(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      _buildHeroHeader(theme),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              _buildStatsRow(theme),
                              const SizedBox(height: 18),
                              if (_albums.isNotEmpty)
                                _buildAlbums(theme),
                              if (_topSongs.isNotEmpty)
                                _buildTopSongs(theme),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  SliverAppBar _buildHeroHeader(ThemeData theme) {
    final artist = _artist!;
    final image = artist.thumbnailUrl ?? widget.thumbnailUrl;

    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      stretch: true,
      backgroundColor: theme.colorScheme.surface,
      automaticallyImplyLeading: true,
      leading: ShadIconButton.ghost(
        icon: const Icon(LucideIcons.arrowLeft, size: 20),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        ShadIconButton.ghost(
          icon: const Icon(LucideIcons.share2, size: 20),
          onPressed: () {
            final url = 'https://music.youtube.com/search?q=${Uri.encodeComponent(artist.name)}';
            Share.share('Check out ${artist.name} on YouTube Music\n$url');
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (image != null)
              CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
            else
              Container(color: theme.colorScheme.surfaceContainerHighest),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.65),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 56),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Hero(
                      tag: widget.heroTag ?? 'artist_${artist.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 90,
                          height: 90,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: image != null
                              ? CachedNetworkImage(
                                  imageUrl: image,
                                  fit: BoxFit.cover)
                              : Icon(LucideIcons.user,
                                  size: 42,
                                  color: theme.colorScheme
                                      .onSurfaceVariant),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            artist.name,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (artist.description != null &&
                              artist.description!.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 4),
                              child: Text(
                                artist.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(
                                        color: Colors.white70),
                              ),
                            ),
                        ],
                      ),
                    ),
                    ShadIconButton.ghost(
                      icon: const Icon(LucideIcons.heart,
                          color: Colors.white, size: 22),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSongs(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top Songs',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ..._topSongs.asMap().entries.map((entry) {
          final idx = entry.key;
          final song = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => _playSong(song, _topSongs),
              child: ShadCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: song.thumbnailUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: song.thumbnailUrl,
                              fit: BoxFit.cover)
                          : Container(
                              color: theme.colorScheme
                                  .surfaceContainerHighest),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.w600)),
                        Text(
                            'Track ${idx + 1} · ${song.artist}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  ShadIconButton.ghost(
                    icon: const Icon(LucideIcons.play, size: 20),
                    onPressed: () =>
                        _playSong(song, _topSongs),
                  ),
                ],
              ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAlbums(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Albums',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            ShadButton.ghost(
              onPressed: () {},
              size: ShadButtonSize.sm,
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _albums.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final album = _albums[index];
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AlbumPage(
                      albumId: album.id,
                      albumTitle: album.title,
                      thumbnailUrl: album.thumbnailUrl,
                    ),
                  ),
                ),
                child: SizedBox(
                  width: 148,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: CachedNetworkImage(
                            imageUrl: album.thumbnailUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        album.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        album.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildStatsRow(ThemeData theme) {
    final albumsCount = _albums.length;
    final tracksCount = _topSongs.length;
    final favorites = _artist?.subscriberCount ?? 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _StatBubble(
            label: 'albums',
            value: albumsCount.toString(),
            icon: LucideIcons.disc),
        _StatBubble(
            label: 'tracks',
            value: tracksCount.toString(),
            icon: LucideIcons.music),
        _StatBubble(
            label: 'favorites',
            value: favorites.toString(),
            icon: LucideIcons.heart),
      ],
    );
  }
}

class _StatBubble extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatBubble({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surfaceContainerHighest
                  .withOpacity(0.4),
            ),
            child: Icon(icon,
                size: 26,
                color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Album Page
// ════════════════════════════════════════════════════════════════════════

class AlbumPage extends StatefulWidget {
  final String albumTitle;
  final String? albumId;
  final String? thumbnailUrl;

  const AlbumPage({
    super.key,
    required this.albumTitle,
    this.albumId,
    this.thumbnailUrl,
  });

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  final MusicRepository _musicRepository = getIt<MusicRepository>();

  bool _loading = true;
  String? _error;
  Album? _album;
  List<Song> _songs = const [];

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
      if (widget.albumId != null) {
        final result =
            await _musicRepository.getAlbumDetails(widget.albumId!);
        result.fold((failure) => _error = failure.message, (album) {
          _album = album;
          _songs = album.songs ?? const [];
        });
      }

      if (_album == null) {
        final searchResult = await _musicRepository
            .searchAlbums(widget.albumTitle, limit: 1);
        searchResult.fold((failure) => _error = failure.message,
            (albums) {
          if (albums.isNotEmpty) _album = albums.first;
        });

        if (_album != null) {
          final details =
              await _musicRepository.getAlbumDetails(_album!.id);
          details.fold((failure) => _error = failure.message,
              (album) {
            _album = album;
            _songs = album.songs ?? const [];
          });
        }
      }

      if (_songs.isEmpty) {
        final songsResult = await _musicRepository.searchSongs(
            '${widget.albumTitle} ${_album?.artist ?? ''}',
            limit: 20);
        songsResult.fold(
            (failure) => logError(
                'Album tracks search failed', failure.message),
            (songs) => _songs = songs);
      }

      setState(() => _loading = false);
    } catch (e, stack) {
      logError('Album load failed', e, stack);
      setState(() {
        _error = 'Failed to load album';
        _loading = false;
      });
    }
  }

  void _playSong(Song song, List<Song> queue) {
    final bloc = context.read<PlayerBloc>();
    bloc.add(PlaySongEvent(
        song: song, queue: queue, queueIndex: queue.indexOf(song)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.albumTitle),
        leading: ShadIconButton.ghost(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (_songs.isNotEmpty)
            ShadIconButton.ghost(
              icon: const Icon(LucideIcons.shuffle, size: 20),
              onPressed: () {
                final queue = List<Song>.from(_songs)..shuffle();
                _playSong(queue.first, queue);
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: ShadProgress())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShadAlert.destructive(
                        icon: const Icon(LucideIcons.circleAlert),
                        title: Text(_error!),
                      ),
                      const SizedBox(height: 12),
                      ShadButton.outline(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      _buildHeader(theme),
                      const SizedBox(height: 12),
                      if (_songs.isNotEmpty) _buildTracks(theme),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final album = _album;
    final cover = album?.thumbnailUrl ?? widget.thumbnailUrl;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 120,
              height: 120,
              child: cover != null
                  ? CachedNetworkImage(
                      imageUrl: cover, fit: BoxFit.cover)
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(LucideIcons.disc,
                          size: 48,
                          color: theme
                              .colorScheme.onSurfaceVariant),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  album?.title ?? widget.albumTitle,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (album?.artist != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(album!.artist,
                        style: theme.textTheme.bodyMedium),
                  ),
                if (album?.year != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ShadBadge.secondary(
                      child: Text('Released ${album!.year}'),
                    ),
                  ),
                if (album?.description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      album!.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTracks(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tracks',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ..._songs.asMap().entries.map((entry) {
            final idx = entry.key;
            final song = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: () => _playSong(song, _songs),
                child: ShadCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text('${idx + 1}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme
                                  .colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(
                                      fontWeight:
                                          FontWeight.w600)),
                          Text(song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    ShadIconButton.ghost(
                      icon: const Icon(LucideIcons.play, size: 20),
                      onPressed: () =>
                          _playSong(song, _songs),
                    ),
                  ],
                ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
