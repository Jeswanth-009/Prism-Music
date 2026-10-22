import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/prism_theme.dart';

/// Media type used to determine the semantic fallback icon and styling.
enum ArtworkType {
  song,
  album,
  artist,
  playlist,
}

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
    this.type = ArtworkType.song,
    this.isCircular = false,
  });

  final String url;
  final double? width;
  final double? height;
  final double? borderRadius;
  final BoxFit fit;
  final ArtworkType type;
  final bool isCircular;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? (isCircular ? 999.0 : PrismRadius.sm);
    final fallback = _ArtworkFallback(
      type: type,
      borderRadius: radius,
      isCircular: isCircular,
    );

    final Widget fallbackWidget = SizedBox(
      width: width,
      height: height,
      child: fallback,
    );

    final Widget image = url.isEmpty
        ? fallbackWidget
        : CachedNetworkImage(
            imageUrl: url,
            fit: fit,
            width: width,
            height: height,
            placeholder: (_, __) => fallbackWidget,
            errorWidget: (_, __, ___) => fallbackWidget,
          );

    if (isCircular) {
      return ClipOval(child: image);
    }
    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({
    required this.type,
    required this.borderRadius,
    this.isCircular = false,
  });

  final ArtworkType type;
  final double borderRadius;
  final bool isCircular;

  IconData get _icon {
    switch (type) {
      case ArtworkType.artist:
        return Icons.person_rounded;
      case ArtworkType.album:
        return Icons.album_rounded;
      case ArtworkType.playlist:
        return Icons.queue_music_rounded;
      case ArtworkType.song:
        return Icons.music_note_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircular ? null : BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Icon(
        _icon,
        color: scheme.onSurfaceVariant.withValues(alpha: .5),
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
