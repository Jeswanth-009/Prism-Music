

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/di/injection.dart';
import '../../core/services/download_service.dart';
import '../../domain/entities/song.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../widgets/common/bouncing_tap_widget.dart';

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
    _loadDownloads();
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
      ShadToaster.of(context).show(
        ShadToast(title: Text('Deleted $title')),
      );
      _loadDownloads();
    }
  }

  void _playSong(Map<String, dynamic> songData) {
    final song = Song(
      id: songData['songId'],
      title: songData['title'],
      artist: songData['artist'],
      duration: Duration(seconds: songData['duration'] ?? 0),
      thumbnails: songData['thumbnailUrl'] != null 
          ? Thumbnails.fromUrl(songData['thumbnailUrl'])
          : Thumbnails.empty(),
      album: songData['album'],
      streamUrl: songData['localPath'],
      source: MusicSource.local,
    );

    context.read<PlayerBloc>().add(PlaySongEvent(song: song));
    ShadToaster.of(context).show(
      ShadToast(title: Text('Playing ${song.title}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _downloadedSongs.isEmpty
              ? _buildEmptyState(theme)
              : _buildList(theme),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.download,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No downloads yet',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Songs you download will appear here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_downloadedSongs.length} songs',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _downloadService.formatBytes(_totalSize),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _downloadedSongs.length,
            itemBuilder: (context, index) {
              final songData = _downloadedSongs[index];
              return _buildSongItem(context, theme, songData);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSongItem(BuildContext context, ThemeData theme, Map<String, dynamic> songData) {
    final title = songData['title'] ?? 'Unknown';
    final artist = songData['artist'] ?? 'Unknown Artist';
    final thumbnailUrl = songData['thumbnailUrl'];
    final size = songData['fileSize'] as int?;

    return BouncingTapWidget(
      onTap: () => _playSong(songData),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),
            const SizedBox(width: 16),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(LucideIcons.hardDriveDownload, size: 12, color: Colors.green),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$artist${size != null ? ' • ${_downloadService.formatBytes(size)}' : ''}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Options
            ShadIconButton.ghost(
              icon: const Icon(LucideIcons.trash2, size: 20),
              onPressed: () => _showDeleteDialog(songData['songId'], title),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.withValues(alpha: 0.2),
      child: const Center(
        child: Icon(LucideIcons.music, color: Colors.grey),
      ),
    );
  }

  void _showDeleteDialog(String songId, String title) {
    showShadDialog(
      context: context,
      builder: (ctx) => ShadDialog(
        title: const Text('Delete Download'),
        description: Text('Are you sure you want to delete "$title" from your device?'),
        actions: [
          ShadButton.ghost(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ShadButton.destructive(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteSong(songId, title);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
