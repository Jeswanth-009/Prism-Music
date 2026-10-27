import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../domain/entities/song.dart';
import '../../theme/prism_theme.dart';

/// Full-screen player album artwork with ambient drop shadow.
class PlayerArtworkSection extends StatelessWidget {
  const PlayerArtworkSection({
    super.key,
    required this.song,
    required this.dominantColor,
  });

  final Song song;
  final Color? dominantColor;

  @override
  Widget build(BuildContext context) {
    final size = (MediaQuery.sizeOf(context).width * 0.74)
        .clamp(220.0, 320.0)
        .toDouble();
    final maxArtHeight = MediaQuery.sizeOf(context).height * 0.40;
    final artSize = size > maxArtHeight ? maxArtHeight : size;
    final accent = dominantColor ?? Theme.of(context).colorScheme.primary;

    return Hero(
      tag: 'album_art_${song.youtubeId ?? song.id}',
      child: Container(
        width: artSize,
        height: artSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PrismRadius.xl),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.35),
              blurRadius: 44,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(PrismRadius.xl),
          child: song.thumbnailUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: song.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _fallback(context),
                  errorWidget: (_, __, ___) => _fallback(context),
                )
              : _fallback(context),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Icon(
        Icons.music_note_rounded,
        size: 48,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: .4),
      ),
    );
  }
}
