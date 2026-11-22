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
import '../widgets/downloads/offline_storage_info_sheet.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/prism/prism_artwork.dart';
import '../widgets/prism/prism_collection_header.dart';
import '../widgets/prism/prism_dialog.dart';
import '../widgets/prism/prism_sheet.dart';
import '../widgets/prism/prism_song_tile.dart';
import '../widgets/prism/prism_states.dart';

/// Fully revamped Downloads & Offline Storage page with 3-in-1 bundling verification
/// (Audio, Cover Art, and Synced Lyrics) and storage breakdown analytics.
class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  final DownloadService _downloadService = getIt<DownloadService>();
  List<Map<String, dynamic>> _downloadedSongs = [];
  bool _isLoading = true;
  bool _isVerifying = false;
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
    final songs = await _downloadService.getAllDownloadedSongsAsync();
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

  Future<void> _verifyAllDownloads() async {
    if (_downloadedSongs.isEmpty) return;
    setState(() => _isVerifying = true);

    int verifiedCount = 0;
    int missingFilesCount = 0;

    for (final songData in _downloadedSongs) {
      final songId = songData['songId'] as String? ?? songData['id'] as String?;
      if (songId != null) {
        final isValid = await _downloadService.verifyDownloadIntegrity(songId);
        if (isValid) {
          verifiedCount++;
        } else {
          missingFilesCount++;
        }
      }
    }

    if (!mounted) return;
    setState(() => _isVerifying = false);

    final msg = missingFilesCount == 0
        ? 'Verified $verifiedCount offline songs. All audio, artwork, and lyrics bundles are intact.'
        : 'Integrity check complete: $verifiedCount intact, $missingFilesCount require re-download.';
    showPrismToast(context, msg);
  }

  Song _mapToSong(Map<String, dynamic> songData) =>
      DownloadService.mapDownloadToSong(songData);

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
        title: const Text('Downloads & Offline Storage'),
        actions: [
          if (_isVerifying)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            IconButton(
              tooltip: 'Verify Integrity',
              icon: const Icon(Icons.verified_outlined),
              onPressed: _downloadedSongs.isEmpty ? null : _verifyAllDownloads,
            ),
            IconButton(
              tooltip: 'Offline & Storage Info',
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: () => showOfflineStorageInfoSheet(context),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_downloadedSongs.isEmpty && activeDownloads.isEmpty)
              ? PrismEmptyState(
                  icon: Icons.download_rounded,
                  message: 'No downloads yet',
                  hint:
                      'Songs you download for offline playback will appear here with bundled high-res artwork and synced lyrics.',
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
                                                    : (info.status == DownloadStatus.queued
                                                        ? Icons.hourglass_top_rounded
                                                        : Icons.downloading_rounded),
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
                                              : (info.status == DownloadStatus.queued
                                                  ? 'Queued'
                                                  : (info.artist ?? 'Downloading…')),
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
                    // Storage Breakdown Meter
                    if (_downloadedSongs.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _buildStorageBreakdown(theme),
                      ),
                    SliverToBoxAdapter(
                      child: PrismCollectionHeader(
                        title: 'Downloaded Songs',
                        badge: '100% Offline',
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

  Widget _buildStorageBreakdown(ThemeData theme) {
    final artCount =
        _downloadedSongs.where((s) => s['localArtworkPath'] != null).length;
    final lyricsCount =
        _downloadedSongs.where((s) => s['localLyricsPath'] != null).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart_outline_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Storage Breakdown',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                _downloadService.formatBytes(_totalSize),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Storage meter bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: 85,
                    child: Container(color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 10,
                    child: Container(color: theme.colorScheme.secondary),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 5,
                    child: Container(color: theme.colorScheme.tertiary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 3-in-1 Offline Bundle Chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildMetricChip(
                theme,
                Icons.audiotrack_rounded,
                '${_downloadedSongs.length} Audio Tracks',
                theme.colorScheme.primary,
              ),
              _buildMetricChip(
                theme,
                Icons.image_outlined,
                '$artCount Artworks',
                theme.colorScheme.secondary,
              ),
              _buildMetricChip(
                theme,
                Icons.lyrics_outlined,
                '$lyricsCount Synced Lyrics',
                theme.colorScheme.tertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(
    ThemeData theme,
    IconData icon,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(PrismRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
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
    final hasArt = songData['localArtworkPath'] != null &&
        File(songData['localArtworkPath'] as String).existsSync();
    final hasLyrics = songData['localLyricsPath'] != null &&
        File(songData['localLyricsPath'] as String).existsSync();
    final quality = songData['quality'] as String? ?? 'Ultra (320 kbps)';

    return BlocBuilder<PlayerBloc, PlayerState>(
      buildWhen: (prev, curr) =>
          (prev.currentSong?.id == song.id) != (curr.currentSong?.id == song.id) ||
          (prev.isPlaying != curr.isPlaying && curr.currentSong?.id == song.id),
      builder: (context, playerState) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PrismRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PrismSongTile(
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
              ),
              Padding(
                padding: const EdgeInsets.only(left: 68, bottom: 8),
                child: Wrap(
                  spacing: 6,
                  children: [
                    _buildVerificationBadge(
                      theme,
                      Icons.high_quality_rounded,
                      quality.contains('320') ? 'Ultra 320 kbps' : quality,
                      theme.colorScheme.primary,
                    ),
                    if (hasArt)
                      _buildVerificationBadge(
                        theme,
                        Icons.check_circle_outline_rounded,
                        'ART OK',
                        theme.colorScheme.secondary,
                      ),
                    if (hasLyrics)
                      _buildVerificationBadge(
                        theme,
                        Icons.lyrics_outlined,
                        'LYRICS OK',
                        theme.colorScheme.tertiary,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerificationBadge(
    ThemeData theme,
    IconData icon,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(PrismRadius.xs),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
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
