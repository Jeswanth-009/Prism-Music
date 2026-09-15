import 'package:flutter/material.dart';

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
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete download?'),
          content: Text(
              'Remove "${widget.song.title}" from offline storage?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Colors.white,
              ),
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Download deleted')),
            );
          }
        }
      }
    } else if (_status == DownloadStatus.notDownloaded) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloading "${widget.song.title}"…')),
        );
      }

      final success =
          await widget.downloadService.downloadSong(widget.song);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download completed')),
        );
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Download',
      onPressed:
          _status == DownloadStatus.downloading ? null : _handleDownload,
      icon: _buildIcon(),
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
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 2,
                color: color,
              ),
            ),
            Icon(Icons.download_rounded, size: size * 0.55, color: color),
          ],
        );
      case DownloadStatus.completed:
        return Icon(Icons.check_circle_rounded,
            size: size, color: Colors.green);
      case DownloadStatus.failed:
        return Icon(Icons.error_outline_rounded,
            size: size, color: Colors.red);
      case DownloadStatus.notDownloaded:
        return Icon(Icons.download_rounded,
            size: size, color: widget.iconColor);
    }
  }
}
