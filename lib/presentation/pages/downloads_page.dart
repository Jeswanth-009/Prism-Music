import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/services/download_service.dart';
import '../../domain/entities/song.dart';
import '../blocs/library/library_bloc.dart';
import '../blocs/library/library_event.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../theme/prism_theme.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/prism/prism_artwork.dart';
import '../widgets/prism/prism_dialog.dart';
import '../widgets/prism/prism_sheet.dart';
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
      thumbnails: songData['thumbnailUrl'] != null
          ? Thumbnails.fromUrl(songData['thumbnailUrl'])
          : Thumbnails.empty(),
      album: songData['album'],
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
              ? const PrismEmptyState(
                  icon: Icons.download_rounded,
                  message: 'No downloads yet',
                  hint:
                      'Songs you download for offline playback will appear here.',
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
                              const SizedBox(height: 6),
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
                                  Icon(
                                    isFailed
                                        ? Icons.error_outline_rounded
                                        : Icons.downloading_rounded,
                                    color: isFailed
                                        ? theme.colorScheme.error
                                        : theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          info.songId,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 4),
                                        LinearProgressIndicator(
                                          value: isFailed
                                              ? 0
                                              : (info.progress > 0
                                                  ? info.progress
                                                  : null),
                                          backgroundColor: theme
                                              .colorScheme.surfaceContainerHighest,
                                          color: isFailed
                                              ? theme.colorScheme.error
                                              : theme.colorScheme.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        size: 18),
                                    tooltip: 'Cancel',
                                    onPressed: () => _downloadService
                                        .cancelDownload(info.songId),
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
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_downloadedSongs.length} ${_downloadedSongs.length == 1 ? 'song' : 'songs'}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color:
                                        theme.colorScheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _downloadService.formatBytes(_totalSize),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_downloadedSongs.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: () => _playAll(),
                                      icon: const Icon(Icons.play_arrow_rounded,
                                          size: 22),
                                      label: const Text('Play all'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  IconButton.filledTonal(
                                    onPressed: () => _playAll(shuffle: true),
                                    tooltip: 'Shuffle downloads',
                                    icon: const Icon(Icons.shuffle_rounded),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
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
    final title = songData['title'] ?? 'Unknown';
    final artist = songData['artist'] ?? 'Unknown Artist';
    final size = songData['fileSize'] as int?;
    final thumbUrl = songData['thumbnailUrl'] as String?;

    return ListTile(
      onTap: () => _playSong(songData),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PrismRadius.md),
      ),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(PrismRadius.sm),
        child: SizedBox(
          width: 48,
          height: 48,
          child: thumbUrl != null && thumbUrl.isNotEmpty
              ? PrismArtwork(url: thumbUrl, fit: BoxFit.cover)
              : Container(
                  color: theme.colorScheme.surfaceContainerHigh,
                  child: Icon(
                    Icons.music_note_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '$artist${size != null ? ' · ${_downloadService.formatBytes(size)}' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline_rounded, size: 20),
        tooltip: 'Delete download',
        onPressed: () => _showDeleteDialog(songData['songId'], title),
      ),
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
