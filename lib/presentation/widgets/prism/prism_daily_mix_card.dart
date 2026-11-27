import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/services/daily_mix_service.dart';
import '../../theme/prism_theme.dart';
import '../common/bouncing_tap_widget.dart';

/// Card rendering an on-device Daily Mix with 2x2 artwork quad collage,
/// dynamic vibrant bottom glow, and artist subtitles matching official streaming apps.
class PrismDailyMixCard extends StatelessWidget {
  final DailyMix mix;
  final VoidCallback onTap;

  /// Fixed width for rails; null fills the parent (grids).
  final double? width;

  const PrismDailyMixCard({
    super.key,
    required this.mix,
    required this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BouncingTapWidget(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 2x2 Artwork Collage with gradient overlay
            ClipRRect(
              borderRadius: BorderRadius.circular(PrismRadius.md),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 2x2 Grid of images
                    _buildQuadCollage(context),

                    // Dark gradient scrim from mid to bottom
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.15),
                              Colors.black.withValues(alpha: 0.85),
                            ],
                            stops: const [0.4, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Title & Accent glow inside bottom of image
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mix.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: PrismColors.onScrim,
                              fontWeight: FontWeight.w700,
                              shadows: const [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Vibrant bottom color indicator bar
                          Container(
                            height: 3,
                            width: 32,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [mix.primaryAccent, mix.secondaryAccent],
                              ),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: mix.primaryAccent.withValues(alpha: 0.6),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Artist subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                mix.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11.5,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuadCollage(BuildContext context) {
    final urls = mix.artworkUrls;
    if (urls.isEmpty) {
      return Container(
        color: mix.primaryAccent.withValues(alpha: 0.2),
        child: Icon(Icons.music_note_rounded, size: 40, color: mix.primaryAccent),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildQuadItem(urls[0])),
              Expanded(child: _buildQuadItem(urls.length > 1 ? urls[1] : urls[0])),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildQuadItem(urls.length > 2 ? urls[2] : urls[0]),
              ),
              Expanded(
                child: _buildQuadItem(
                  urls.length > 3 ? urls[3] : (urls.length > 1 ? urls[1] : urls[0]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuadItem(String url) {
    if (url.isEmpty) {
      return Container(color: PrismColors.inkHigh);
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 150),
      errorWidget: (_, __, ___) => Container(color: PrismColors.inkHigh),
    );
  }
}
