import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/services/download_service.dart';
import '../../domain/entities/song.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../theme/prism_theme.dart';
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
      showPrismToast(context, 'Deleted $title');
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _downloadedSongs.isEmpty
              ? const PrismEmptyState(
                  icon: Icons.download_rounded,
                  message: 'No downloads yet',
                  hint: 'Songs you download will appear here',
                )
              : _buildList(theme),
    );
  }

  Widget _buildList(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
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

  Widget _buildSongItem(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> songData,
  ) {
    final title = songData['title'] ?? 'Unknown';
    final artist = songData['artist'] ?? 'Unknown Artist';
    final size = songData['fileSize'] as int?;

    return ListTile(
      onTap: () => _playSong(songData),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PrismRadius.md),
      ),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(PrismRadius.sm),
        ),
        child: Icon(
          Icons.download_done_rounded,
          color: theme.colorScheme.primary,
          size: 22,
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
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete download?'),
        content: Text(
          'Are you sure you want to delete "$title" from your device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteSong(songId, title);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
