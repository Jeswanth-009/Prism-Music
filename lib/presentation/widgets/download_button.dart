import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/services/download_service.dart';
import '../../domain/entities/song.dart';

class DownloadButton extends StatefulWidget {
  final Song song;
  final DownloadService downloadService;
  final double iconSize;
  final Color? iconColor;

  const DownloadButton({
    super.key,
    required this.song,
    required this.downloadService,
    this.iconSize = 24.0,
    this.iconColor,
  });

  @override
  State<DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<DownloadButton> {
  DownloadStatus _status = DownloadStatus.notDownloaded;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _updateStatus();
    widget.downloadService.addListener(_onDownloadProgress);
  }

  @override
  void dispose() {
    widget.downloadService.removeListener(_onDownloadProgress);
    super.dispose();
  }

  void _updateStatus() {
    setState(() {
      _status =
          widget.downloadService.getDownloadStatus(widget.song.playableId);
      _progress =
          widget.downloadService.getDownloadProgress(widget.song.playableId);
    });
  }

  void _onDownloadProgress(DownloadInfo info) {
    if (info.songId == widget.song.playableId) {
      setState(() {
        _status = info.status;
        _progress = info.progress;
      });
    }
  }

  Future<void> _handleDownload() async {
    if (_status == DownloadStatus.completed) {
      final shouldDelete = await showShadDialog<bool>(
        context: context,
        builder: (context) => ShadDialog(
          title: const Text('Delete Download'),
          description: Text(
              'Remove "${widget.song.title}" from offline storage?'),
          actions: [
            ShadButton.ghost(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ShadButton.destructive(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (shouldDelete == true && mounted) {
        final success =
            await widget.downloadService.deleteSong(widget.song.playableId);
        if (success) {
          _updateStatus();
          if (mounted) {
            ShadToaster.of(context).show(
              const ShadToast(title: Text('Download deleted')),
            );
          }
        }
      }
    } else if (_status == DownloadStatus.notDownloaded) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            title: Text('Downloading "${widget.song.title}"...'),
          ),
        );
      }

      final success =
          await widget.downloadService.downloadSong(widget.song);

      if (success && mounted) {
        ShadToaster.of(context).show(
          const ShadToast(title: Text('Download completed')),
        );
      } else if (!success && mounted) {
        ShadToaster.of(context).show(
          const ShadToast.destructive(
              title: Text('Download failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShadIconButton.ghost(
      icon: _buildIcon(),
      onPressed:
          _status == DownloadStatus.downloading ? null : _handleDownload,
    );
  }

  Widget _buildIcon() {
    final color =
        widget.iconColor ?? Theme.of(context).colorScheme.primary;
    final size = widget.iconSize;

    switch (_status) {
      case DownloadStatus.downloading:
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: ShadProgress(
                value: _progress,
                minHeight: 2,
                color: color,
              ),
            ),
            Icon(LucideIcons.download, size: size * 0.6, color: color),
          ],
        );
      case DownloadStatus.completed:
        return Icon(LucideIcons.circleCheck,
            size: size, color: Colors.green);
      case DownloadStatus.failed:
        return Icon(LucideIcons.circleAlert,
            size: size, color: Colors.red);
      case DownloadStatus.notDownloaded:
        return Icon(LucideIcons.download,
            size: size, color: widget.iconColor);
    }
  }
}
