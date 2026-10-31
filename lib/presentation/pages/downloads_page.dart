import 'dart:io';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/services/download_service.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/song.dart';
import '../blocs/library/library_bloc.dart';
import '../blocs/library/library_event.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../blocs/player/player_state.dart';
import '../theme/prism_theme.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/prism/prism_artwork.dart';
import '../widgets/prism/prism_collection_header.dart';
import '../widgets/prism/prism_dialog.dart';
import '../widgets/prism/prism_sheet.dart';
import '../widgets/prism/prism_song_tile.dart';
import '../widgets/prism/prism_states.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  final DownloadService _downloadService = getIt<DownloadService>();
  List<Map<String, dynamic>> _downloadedSongs = [];
  bool _isLoading = true;
  int _totalSize = 0;

  @override
  void initState() {
    super.initState();
    _downloadService.addListener(_onDownloadProgress);
    _loadDownloads();
  }

  @override
  void dispose() {
    _downloadService.removeListener(_onDownloadProgress);
    super.dispose();
  }

  void _onDownloadProgress(DownloadInfo info) {
    if (!mounted) return;
    if (info.status == DownloadStatus.completed ||
        info.status == DownloadStatus.notDownloaded) {
      _loadDownloads();
    } else {
      setState(() {});
    }
  }

  Future<void> _loadDownloads() async {
    setState(() => _isLoading = true);
    await _downloadService.reconcileStorageState();
    final songs = _downloadService.getAllDownloadedSongs();
    final size = await _downloadService.getTotalDownloadSize();

    if (mounted) {
      setState(() {
        _downloadedSongs = songs;
        _totalSize = size;
        _isLoading = false;
      });
    }
  }

  void _retryDownload(DownloadInfo info) {
    final song = Song(
      id: info.songId,
      title: info.songTitle ?? 'Unknown',
      artist: info.artist ?? 'Unknown Artist',
      duration: Duration.zero,
      thumbnails: info.thumbnailUrl != null
          ? Thumbnails.fromUrl(info.thumbnailUrl!)
          : Thumbnails.empty(),
    );
    _downloadService.retryDownload(song);
  }

  Future<void> _deleteSong(String songId, String title) async {
    final success = await _downloadService.deleteSong(songId);
    if (success && mounted) {
      context.read<LibraryBloc>().add(DeleteDownloadEvent(songId));
      showPrismToast(context, 'Deleted $title');
      _loadDownloads();
    }
  }

  Song _mapToSong(Map<String, dynamic> songData) {
    return Song(
      id: songData['songId'],
      title: songData['title'] ?? 'Unknown',
      artist: songData['artist'] ?? 'Unknown Artist',
      duration: Duration(seconds: songData['duration'] ?? 0),
      thumbnails: (songData['localArtworkPath'] != null &&
              File(songData['localArtworkPath']).existsSync())
          ? Thumbnails.fromUrl(songData['localArtworkPath'])
          : (songData['thumbnailUrl'] != null
              ? Thumbnails.fromUrl(songData['thumbnailUrl'])
              : Thumbnails.empty()),
      album: songData['album'],
      artists: (songData['artists'] is List)
          ? List<String>.from(songData['artists'])
          : [songData['artist'] ?? 'Unknown Artist'],
      isrc: songData['isrc'],
      streamUrl: songData['localPath'],
      source: MusicSource.local,
    );
  }

  void _playSong(Map<String, dynamic> songData) {
    final song = _mapToSong(songData);
    final allSongs = _downloadedSongs.map(_mapToSong).toList();
    final index = allSongs.indexWhere((s) => s.id == song.id);
    context.read<PlayerBloc>().add(
          PlaySongEvent(
            song: song,
            queue: allSongs,
            queueIndex: index >= 0 ? index : 0,
          ),
        );
  }

  void _playAll({bool shuffle = false}) {
    if (_downloadedSongs.isEmpty) return;
    final allSongs = _downloadedSongs.map(_mapToSong).toList();
    final queue = shuffle ? ([...allSongs]..shuffle()) : allSongs;
    context.read<PlayerBloc>().add(
          PlaySongEvent(
            song: queue.first,
            queue: queue,
            queueIndex: 0,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeDownloads = _downloadService.activeDownloads.values
        .where((d) =>
            d.status == DownloadStatus.queued ||
            d.status == DownloadStatus.downloading ||
            d.status == DownloadStatus.failed)
        .toList();

    return Scaffold(
      bottomNavigationBar: const PrismPersistentMiniPlayer(),
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Downloads'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_downloadedSongs.isEmpty && activeDownloads.isEmpty)
              ? PrismEmptyState(
                  icon: Icons.download_rounded,
                  message: 'No downloads yet',
                  hint:
                      'Songs you download for offline playback will appear here.',
                  actionLabel: 'Find Songs to Download',
                  onAction: () => Navigator.of(context).pop(),
                )
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    if (activeDownloads.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                          child: Text(
                            'Transfer Queue',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList.separated(
                          itemCount: activeDownloads.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final info = activeDownloads[index];
                            final isFailed =
                                info.status == DownloadStatus.failed;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHigh,
                                borderRadius:
                                    BorderRadius.circular(PrismRadius.md),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(PrismRadius.xs),
                                    child: SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: info.thumbnailUrl != null &&
                                              info.thumbnailUrl!.isNotEmpty
                                          ? PrismArtwork(
                                              url: info.thumbnailUrl!,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              color: theme.colorScheme
                                                  .surfaceContainerHighest,
                                              child: Icon(
                                                isFailed
                                                    ? Icons.error_outline_rounded
                                                    : (info.status == DownloadStatus.queued ? Icons.hourglass_top_rounded : Icons.downloading_rounded),
                                                color: isFailed
                                                    ? theme.colorScheme.error
                                                    : theme.colorScheme.primary,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          info.songTitle ?? info.songId,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isFailed
                                              ? (info.error ?? 'Download failed')
                                              : (info.status == DownloadStatus.queued ? 'Queued' : (info.artist ?? 'Downloading…')),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: isFailed
                                                ? theme.colorScheme.error
                                                : theme.colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        LinearProgressIndicator(
                                          value: isFailed
                                              ? 0
                                              : (info.status == DownloadStatus.queued
                                                  ? 0
                                                  : (info.progress > 0
                                                      ? info.progress
                                                      : null)),
                                          backgroundColor: theme.colorScheme
                                              .surfaceContainerHighest,
                                          color: isFailed
                                              ? theme.colorScheme.error
                                              : theme.colorScheme.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isFailed)
                                        IconButton(
                                          icon: const Icon(Icons.refresh_rounded,
                                              size: 18),
                                          tooltip: 'Retry',
                                          onPressed: () => _retryDownload(info),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.close_rounded,
                                            size: 18),
                                        tooltip: isFailed ? 'Dismiss' : 'Cancel',
                                        onPressed: () => _downloadService
                                            .cancelDownload(info.songId),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 16),
                      ),
                    ],
                    SliverToBoxAdapter(
                      child: PrismCollectionHeader(
                        title: 'Downloads',
                        badge: 'Offline',
                        icon: Icons.download_done_rounded,
                        iconColor: theme.colorScheme.primary,
                        metadata:
                            '${Formatters.formatCount(_downloadedSongs.length, 'song')} · ${_downloadService.formatBytes(_totalSize)}',
                        onPlayAll:
                            _downloadedSongs.isEmpty ? null : () => _playAll(),
                        onShuffle: _downloadedSongs.isEmpty
                            ? null
                            : () => _playAll(shuffle: true),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
                      sliver: SliverList.builder(
                        itemCount: _downloadedSongs.length,
                        itemBuilder: (context, index) {
                          final songData = _downloadedSongs[index];
                          return _buildSongItem(context, theme, songData);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSongItem(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> songData,
  ) {
    final song = _mapToSong(songData);
    final size = songData['fileSize'] as int?;

    return BlocBuilder<PlayerBloc, PlayerState>(
      builder: (context, playerState) {
        return PrismSongTile(
          song: song,
          isDownloaded: true,
          subtitle: size != null
              ? '${song.artist} · ${_downloadService.formatBytes(size)}'
              : song.artist,
          isPlaying: playerState.currentSong?.id == song.id,
          isPlayingPaused: !playerState.isPlaying,
          onTap: () => _playSong(songData),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            tooltip: 'Delete download',
            onPressed: () => _showDeleteDialog(song.id, song.title),
          ),
        );
      },
    );
  }

  void _showDeleteDialog(String songId, String title) {
    showPrismConfirmDialog(
      context: context,
      title: 'Delete download?',
      message: 'Are you sure you want to remove "$title" from offline storage?',
      confirmLabel: 'Delete',
      isDestructive: true,
      onConfirm: () => _deleteSong(songId, title),
    );
  }
}
