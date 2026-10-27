import 'package:flutter/material.dart';

import '../../../domain/entities/playlist.dart';
import '../../theme/prism_theme.dart';
import '../prism/prism_artwork.dart';

/// Cover-art grid card for a library playlist.
class LibraryPlaylistCard extends StatelessWidget {
  const LibraryPlaylistCard({
    super.key,
    required this.playlist,
    required this.onTap,
    required this.onPlay,
    required this.onRename,
    required this.onExport,
    required this.onDelete,
  });

  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onRename;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = context.prismSpec;
    return Material(
      color: theme.colorScheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        side: BorderSide(color: spec.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PrismArtwork(
                    url: playlist.thumbnailUrl ?? '',
                    fit: BoxFit.cover,
                  ),
                  if (_sourceLabel != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: _badge(
                        context,
                        icon: _sourceLabel!.$2,
                        label: _sourceLabel!.$1,
                      ),
                    ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: LibraryCardMenuButton(
                      playlist: playlist,
                      onPlay: onPlay,
                      onRename: onRename,
                      onExport: onExport,
                      onDelete: onDelete,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${playlist.trackCount} songs',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// (label, icon) for imported playlists, null for user-created ones.
  (String, IconData)? get _sourceLabel {
    if (playlist.spotifyPlaylistId != null) {
      return ('Spotify', Icons.graphic_eq_rounded);
    }
    if (playlist.youtubePlaylistId != null) {
      return ('YouTube', Icons.play_circle_outline_rounded);
    }
    return null;
  }

  Widget _badge(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Overflow menu for playlist card actions (play, edit details, export, delete).
class LibraryCardMenuButton extends StatelessWidget {
  const LibraryCardMenuButton({
    super.key,
    required this.playlist,
    required this.onPlay,
    required this.onRename,
    required this.onExport,
    required this.onDelete,
  });

  final Playlist playlist;
  final VoidCallback onPlay;
  final VoidCallback onRename;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = playlist.trackCount;

    return Theme(
      data: theme.copyWith(
        splashFactory: NoSplash.splashFactory,
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Playlist options',
        padding: EdgeInsets.zero,
        icon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: .88),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.more_vert_rounded,
            size: 15,
            color: theme.colorScheme.onSurface,
          ),
        ),
        onSelected: (val) {
          if (val == 'play') {
            onPlay();
          } else if (val == 'rename') {
            onRename();
          } else if (val == 'export') {
            onExport();
          } else if (val == 'delete') {
            onDelete();
          }
        },
        itemBuilder: (_) => [
          if (count > 0)
            const PopupMenuItem(
              value: 'play',
              child: Row(
                children: [
                  Icon(Icons.play_arrow_rounded, size: 18),
                  SizedBox(width: 12),
                  Text('Play'),
                ],
              ),
            ),
          if (playlist.isUserCreated)
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 12),
                  Text('Edit details'),
                ],
              ),
            ),
          const PopupMenuItem(
            value: 'export',
            child: Row(
              children: [
                Icon(Icons.ios_share_rounded, size: 18),
                SizedBox(width: 12),
                Text('Export playlist'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, size: 18),
                SizedBox(width: 12),
                Text('Delete playlist'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
