import 'package:flutter/material.dart';

import '../../theme/prism_theme.dart';
import '../prism/prism_artwork.dart';

/// Dynamic 2x2 collage artwork for playlists with 4 or more tracks.
class PlaylistCollageArtwork extends StatelessWidget {
  const PlaylistCollageArtwork({
    super.key,
    required this.thumbnailUrls,
    this.size = 80,
    this.borderRadius = PrismRadius.md,
  });

  final List<String> thumbnailUrls;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final spec = context.prismSpec;
    final half = size / 2;

    if (thumbnailUrls.length < 4) {
      final fallbackUrl = thumbnailUrls.isNotEmpty ? thumbnailUrls.first : '';
      return Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: spec.hairline),
        ),
        child: PrismArtwork(
          url: fallbackUrl,
          borderRadius: borderRadius,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: spec.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: half,
                height: half,
                child: PrismArtwork(
                  url: thumbnailUrls[0],
                  borderRadius: 0,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(
                width: half,
                height: half,
                child: PrismArtwork(
                  url: thumbnailUrls[1],
                  borderRadius: 0,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(
                width: half,
                height: half,
                child: PrismArtwork(
                  url: thumbnailUrls[2],
                  borderRadius: 0,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(
                width: half,
                height: half,
                child: PrismArtwork(
                  url: thumbnailUrls[3],
                  borderRadius: 0,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
