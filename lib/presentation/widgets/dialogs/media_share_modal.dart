import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/media_share_helper.dart';
import '../../../domain/entities/song.dart';
import '../prism/prism_sheet.dart';

/// Show the modern branded share sheet for a song or single
Future<void> showMediaShareModal(BuildContext context, Song song) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MediaShareModal(song: song),
  );
}

class MediaShareModal extends StatefulWidget {
  final Song song;

  const MediaShareModal({super.key, required this.song});

  @override
  State<MediaShareModal> createState() => _MediaShareModalState();
}

class _MediaShareModalState extends State<MediaShareModal> {
  final GlobalKey _cardKey = GlobalKey();
  bool _isExporting = false;

  Future<void> _shareImage() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final xFile = XFile.fromData(
        bytes,
        mimeType: 'image/png',
        name: 'prism_${widget.song.id}.png',
      );

      if (mounted) Navigator.of(context).pop();
      await Share.shareXFiles([xFile], text: 'Listening to "${widget.song.title}" on Prism Music');
    } catch (e) {
      if (mounted) {
        showPrismToast(context, 'Could not export image: $e');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _copyLink() {
    final shareUrl = widget.song.youtubeId != null
        ? 'https://music.youtube.com/watch?v=${widget.song.youtubeId}'
        : 'https://prism.music/track/${widget.song.id}';
    Clipboard.setData(ClipboardData(text: shareUrl));
    if (mounted) {
      Navigator.of(context).pop();
      showPrismToast(context, 'Link copied to clipboard');
    }
  }

  void _shareLink() {
    Navigator.of(context).pop();
    final shareUrl = MediaShareHelper.buildReliableSongUrl(widget.song) ??
        'https://music.youtube.com/search?q=${Uri.encodeComponent('${widget.song.title} ${widget.song.artist}')}';
    Share.share('Listening to "${widget.song.title}" by ${widget.song.artist}\n$shareUrl');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final song = widget.song;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Share Preview Card (Captured for image sharing)
            RepaintBoundary(
              key: _cardKey,
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1E1E28),
                      Color(0xFF121218),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Single / Track capsule badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        song.album?.isNotEmpty == true ? 'TRACK' : 'SINGLE',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Artwork
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: song.thumbnailUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: song.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  color: Colors.white10,
                                  child: const Icon(Icons.music_note_rounded, size: 50, color: Colors.white54),
                                ),
                              )
                            : Container(
                                color: Colors.white10,
                                child: const Icon(Icons.music_note_rounded, size: 50, color: Colors.white54),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Song Title & Artist
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Footer attribution
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF8A2BE2), Color(0xFF00ADB5)],
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Listen on Prism Music',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons Row (Copy Link, Share Link, Share Story/Image)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.link_rounded,
                  label: 'Copy link',
                  onTap: _copyLink,
                  theme: theme,
                ),
                _buildActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share link',
                  onTap: _shareLink,
                  theme: theme,
                ),
                _buildActionButton(
                  icon: Icons.photo_library_rounded,
                  label: _isExporting ? 'Exporting...' : 'Share card',
                  onTap: _isExporting ? () {} : _shareImage,
                  theme: theme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
