import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/di/injection.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../widgets/prism/prism_states.dart';
import 'album_page.dart';

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
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? PrismErrorState(message: _error, onRetry: _load)
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_rounded),
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
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.65),
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
                              : Icon(Icons.person_rounded,
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
                    IconButton(
                      icon: const Icon(
                        Icons.favorite_outline_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
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
          final song = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => _playSong(song, _topSongs),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              tileColor:
                  theme.colorScheme.surfaceContainer.withValues(alpha: .6),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: song.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: song.thumbnailUrl, fit: BoxFit.cover)
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                ),
              ),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.play_arrow_rounded),
                onPressed: () => _playSong(song, _topSongs),
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
                    builder: (_) => AlbumPage(album: album),
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
            icon: Icons.album_rounded),
        _StatBubble(
            label: 'tracks',
            value: tracksCount.toString(),
            icon: Icons.music_note_rounded),
        _StatBubble(
            label: 'favorites',
            value: favorites.toString(),
            icon: Icons.favorite_rounded),
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
                  .withValues(alpha: 0.4),
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
