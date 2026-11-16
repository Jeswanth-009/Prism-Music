import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/playlist_collaboration_service.dart';
import '../../../core/services/playlist_export_service.dart';
import '../../../domain/entities/playlist.dart';
import '../../theme/prism_theme.dart';
import '../prism/prism_sheet.dart';

/// Unified sharing hub for playlists.
/// Provides QR code P2P link, web fallback, format exports (M3U8 / JSON),
/// and tracklist text copying — with pure vector iconography and zero emojis.
class PlaylistShareSheet extends StatefulWidget {
  const PlaylistShareSheet({super.key, required this.playlist});

  final Playlist playlist;

  static Future<void> show(BuildContext context, Playlist playlist) {
    return showPrismSheet<void>(
      context: context,
      builder: (_) => PlaylistShareSheet(playlist: playlist),
    );
  }

  @override
  State<PlaylistShareSheet> createState() => _PlaylistShareSheetState();
}

class _PlaylistShareSheetState extends State<PlaylistShareSheet> {
  bool _isExporting = false;

  Future<void> _exportM3u8() async {
    setState(() => _isExporting = true);
    try {
      final file = await PlaylistExportService.instance.exportM3u8(widget.playlist);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (file == null) {
        showPrismToast(context, 'Failed to generate M3U8 playlist');
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
    Navigator.of(context).pop();
    await PlaylistExportService.instance.shareText(widget.playlist);
  }

  Future<void> _shareCard() async {
    Navigator.of(context).pop();
    await PlaylistExportService.instance.sharePlaylistCard(widget.playlist);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = widget.playlist.songs?.length ?? widget.playlist.trackCount;
    final appLink =
        PlaylistCollaborationService.instance.buildAppShareLink(widget.playlist);
    final webLink =
        PlaylistCollaborationService.instance.buildWebShareLink(widget.playlist);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.share_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Share Playlist',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.playlist.name} · $count tracks',
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
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              // Scannable QR code section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(PrismRadius.lg),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: appLink,
                      version: QrVersions.auto,
                      size: 170.0,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Scan with any camera or Prism Music to import this playlist instantly.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 14),

              // Action buttons: Copy App Link, Copy Web Link, System Share
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: appLink));
                          if (context.mounted) {
                            showPrismToast(context, 'App share link copied');
                          }
                        },
                        icon: const Icon(Icons.link_rounded, size: 16),
                        label: const Text('App Link'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: webLink));
                          if (context.mounted) {
                            showPrismToast(context, 'Web fallback link copied');
                          }
                        },
                        icon: const Icon(Icons.public_rounded, size: 16),
                        label: const Text('Web Link'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Share via...',
                      icon: const Icon(Icons.send_rounded, size: 18),
                      onPressed: () => Share.share(webLink, subject: widget.playlist.name),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),

              // Export actions
              PrismSheetAction(
                icon: Icons.badge_outlined,
                label: 'Share Summary Card',
                subtitle: 'Formatted tracklist overview with audio verification metadata',
                onTap: _shareCard,
              ),
              PrismSheetAction(
                icon: Icons.queue_music_rounded,
                label: 'M3U8 Playlist (.m3u8)',
                subtitle: 'Standard audio playlist file with streaming URLs',
                onTap: _exportM3u8,
              ),
              PrismSheetAction(
                icon: Icons.data_object_rounded,
                label: 'JSON Archive (.json)',
                subtitle: 'Complete structured playlist archive for backup or transfer',
                onTap: _exportJson,
              ),
              PrismSheetAction(
                icon: Icons.format_list_numbered_rounded,
                label: 'Copy Tracklist (Text)',
                subtitle: 'Plain numbered list of track titles and artists',
                onTap: _shareText,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
