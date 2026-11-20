import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../domain/entities/song.dart';
import '../../blocs/player/player_state.dart';
import '../../theme/prism_theme.dart';

/// Full-screen player album artwork with ambient drop shadow.
class PlayerArtworkSection extends StatelessWidget {
  const PlayerArtworkSection({
    super.key,
    required this.song,
    required this.dominantColor,
    this.loadingStage = PlayerLoadingStage.none,
  });

  final Song song;
  final Color? dominantColor;
  final PlayerLoadingStage loadingStage;

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
          child: Stack(
            fit: StackFit.expand,
            children: [
              song.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: song.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _fallback(context),
                      errorWidget: (_, __, ___) => _fallback(context),
                    )
                  : _fallback(context),
              if (loadingStage != PlayerLoadingStage.none)
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(PrismRadius.pill),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            dimension: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            loadingStage.displayLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
