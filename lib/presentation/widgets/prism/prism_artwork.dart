import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/prism_theme.dart';

/// Artwork thumbnail with a quiet fallback. The only image widget pages
/// should use directly.
class PrismArtwork extends StatelessWidget {
  const PrismArtwork({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  final String url;
  final double? width;
  final double? height;
  final double? borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? PrismRadius.sm;
    final fallback = _ArtworkFallback(borderRadius: radius);

    final Widget image = url.isEmpty
        ? fallback
        : CachedNetworkImage(
            imageUrl: url,
            fit: fit,
            width: width,
            height: height,
            placeholder: (_, __) => fallback,
            errorWidget: (_, __, ___) => fallback,
          );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({required this.borderRadius});
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: scheme.surfaceContainerHigh,
      child: Icon(
        Icons.music_note_outlined,
        color: scheme.onSurfaceVariant.withValues(alpha: .6),
      ),
    );
  }
}

/// The spectrum logo mark — the one place gradients are allowed.
class PrismLogoMark extends StatelessWidget {
  const PrismLogoMark({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: PrismColors.spectrum,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: Theme.of(context).colorScheme.surface,
        size: size * 0.55,
      ),
    );
  }
}
