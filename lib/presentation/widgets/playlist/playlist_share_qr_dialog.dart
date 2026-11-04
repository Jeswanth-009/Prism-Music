import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/playlist_collaboration_service.dart';
import '../../../domain/entities/playlist.dart';
import '../prism/prism_sheet.dart';

/// Modal bottom sheet displaying peer-to-peer playlist QR code and link sharing options.
class PlaylistShareQrDialog extends StatelessWidget {
  const PlaylistShareQrDialog({super.key, required this.playlist});

  final Playlist playlist;

  static Future<void> show(BuildContext context, Playlist playlist) {
    return showPrismSheet<void>(
      context: context,
      builder: (_) => PlaylistShareQrDialog(playlist: playlist),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final link = PlaylistCollaborationService.instance.buildAppShareLink(playlist);
    final webLink = PlaylistCollaborationService.instance.buildWebShareLink(playlist);
    final count = playlist.songs?.length ?? playlist.trackCount;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Peer-to-Peer Playlist Share',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${playlist.name} • $count tracks',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // QR Code Container with rounded white background for high contrast
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: link,
                version: QrVersions.auto,
                size: 220.0,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scan directly from another phone with Prism Music or camera to import without any server accounts.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: link));
                      if (context.mounted) {
                        showPrismToast(context, 'Playlist share link copied to clipboard');
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy Link'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Share.share(
                        '🎶 Check out my playlist "${playlist.name}" on Prism Music!\n\nApp Link: $link\nWeb Link: $webLink',
                        subject: playlist.name,
                      );
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share Link'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
