import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/di/injection.dart';
import '../../core/services/download_service.dart';
import '../../domain/entities/song.dart';
import '../blocs/library/library_bloc.dart';
import '../blocs/library/library_event.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';

/// Downloads page showing all downloaded songs
class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  List<Song> _downloadedSongs = [];
  bool _isLoading = true;
  String? _downloadPath;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    setState(() => _isLoading = true);

    try {
      final downloadService = getIt<DownloadService>();
      await downloadService.initialize();

      final downloadedMaps = downloadService.getAllDownloadedSongs();
      final songs = downloadedMaps.map((map) {
        final thumbnailUrl = map['thumbnailUrl'] as String? ?? '';
        return Song(
          id: map['songId'] as String,
          title: map['title'] as String,
          artist: map['artist'] as String,
          artists: [map['artist'] as String],
          duration: Duration(seconds: map['duration'] as int),
          thumbnails: Thumbnails(
            low: thumbnailUrl,
            medium: thumbnailUrl,
            high: thumbnailUrl,
          ),
        );
      }).toList();

      final downloadPath =
          await downloadService.getDownloadDirectoryPath();

      if (mounted) {
        setState(() {
          _downloadedSongs = songs;
          _downloadPath = downloadPath;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        leading: ShadIconButton.ghost(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (_downloadedSongs.isNotEmpty)
            ShadIconButton.ghost(
              icon: const Icon(LucideIcons.folderOpen, size: 20),
              onPressed: () {
                showShadDialog(
                  context: context,
                  builder: (ctx) => ShadDialog(
                    title: const Text('Download Location'),
                    child: SelectableText(
                      _downloadPath ?? 'Unknown',
                      style: const TextStyle(fontSize: 14),
                    ),
                    actions: [
                      ShadButton.ghost(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ShadIconButton.ghost(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: _loadDownloads,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: ShadProgress())
          : _downloadedSongs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.download,
                          size: 64,
                          color: theme.colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('No downloads yet',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        'Downloaded songs will appear here',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Download info header
                    ShadCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.folderOpen, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _downloadPath ?? 'Default location',
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ShadBadge.secondary(
                            child: Text(
                                '${_downloadedSongs.length} songs'),
                          ),
                        ],
                      ),
                    ),
                    // Songs list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: _downloadedSongs.length,
                        itemBuilder: (context, index) {
                          final song = _downloadedSongs[index];
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: 6),
                            child: GestureDetector(
                              onTap: () {
                                context
                                    .read<PlayerBloc>()
                                    .add(PlaySongEvent(
                                      song: song,
                                      queue: _downloadedSongs,
                                      queueIndex: index,
                                    ));
                              },
                              child: ShadCard(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 52,
                                      height: 52,
                                      child: song.thumbnailUrl
                                              .isNotEmpty
                                          ? Image.network(
                                              song.thumbnailUrl,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              color: theme
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              child: const Icon(
                                                  LucideIcons
                                                      .music),
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
                                          song.title,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: theme.textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                            fontWeight:
                                                FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          song.artist,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: theme
                                              .textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(LucideIcons.circleCheck,
                                      color:
                                          Colors.green.shade600,
                                      size: 18),
                                  const SizedBox(width: 4),
                                  ShadIconButton.ghost(
                                    icon: Icon(LucideIcons.trash2,
                                        size: 18,
                                        color: theme.colorScheme
                                            .error),
                                    onPressed: () =>
                                        _confirmDelete(song),
                                  ),
                                ],
                              ),
                            ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _confirmDelete(Song song) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog(
        title: const Text('Delete Download'),
        description:
            Text('Remove "${song.title}" from offline storage?'),
        actions: [
          ShadButton.ghost(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final downloadService = getIt<DownloadService>();
        final success = await downloadService.deleteSong(song.id);

        if (success && mounted) {
          ShadToaster.of(context).show(
            ShadToast(title: const Text('Download deleted')),
          );
          context.read<LibraryBloc>().add(const LoadLibraryEvent());
          _loadDownloads();
        }
      } catch (e) {
        if (mounted) {
          ShadToaster.of(context).show(
            ShadToast.destructive(
                title: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }
}
