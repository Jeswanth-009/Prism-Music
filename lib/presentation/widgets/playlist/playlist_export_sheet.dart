import 'package:flutter/material.dart';

import '../../../core/services/playlist_export_service.dart';
import '../../../domain/entities/playlist.dart';
import '../../theme/prism_theme.dart';
import '../prism/prism_dialog.dart';
import '../prism/prism_sheet.dart';

/// Interactive modal sheet to export or share a playlist.
class PlaylistExportSheet extends StatefulWidget {
  const PlaylistExportSheet({super.key, required this.playlist});

  final Playlist playlist;

  static Future<void> show(BuildContext context, Playlist playlist) {
    return showPrismSheet<void>(
      context: context,
      builder: (_) => PlaylistExportSheet(playlist: playlist),
    );
  }

  @override
  State<PlaylistExportSheet> createState() => _PlaylistExportSheetState();
}

class _PlaylistExportSheetState extends State<PlaylistExportSheet> {
  bool _isExporting = false;

  Future<void> _exportM3u8() async {
    setState(() => _isExporting = true);
    try {
      final file = await PlaylistExportService.instance.exportM3u8(widget.playlist);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (file == null) {
        showPrismToast(context, 'Failed to generate M3U8 file');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportJson() async {
    setState(() => _isExporting = true);
    try {
      final file = await PlaylistExportService.instance.exportJson(widget.playlist);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (file == null) {
        showPrismToast(context, 'Failed to generate JSON archive');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _shareText() async {
    setState(() => _isExporting = true);
    try {
      Navigator.of(context).pop();
      await PlaylistExportService.instance.shareText(widget.playlist);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = widget.playlist.songs?.length ?? 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Export Playlist',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.playlist.name} • $count tracks',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_isExporting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              PrismSheetAction(
                icon: Icons.queue_music_rounded,
                label: 'M3U8 Playlist (.m3u8)',
                subtitle: 'Universal audio playlist with YouTube & stream URLs',
                onTap: _exportM3u8,
              ),
              PrismSheetAction(
                icon: Icons.data_object_rounded,
                label: 'JSON Archive (.json)',
                subtitle: 'Structured metadata and complete song catalog',
                onTap: _exportJson,
              ),
              PrismSheetAction(
                icon: Icons.format_list_numbered_rounded,
                label: 'Share Tracklist (Text)',
                subtitle: 'Plain text with track titles, artists, and durations',
                onTap: _shareText,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
