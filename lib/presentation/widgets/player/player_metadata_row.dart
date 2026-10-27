import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../domain/entities/song.dart';
import '../../../domain/entities/stream_info.dart';
import '../../theme/prism_theme.dart';

/// Song title, clickable artist text, and truthful audio provenance badge.
class PlayerMetadataRow extends StatelessWidget {
  const PlayerMetadataRow({
    super.key,
    required this.song,
    this.streamInfo,
    required this.onArtistTap,
    this.onProvenanceTap,
  });

  final Song song;
  final StreamInfo? streamInfo;
  final void Function(String) onArtistTap;
  final VoidCallback? onProvenanceTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Text(
            song.title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          PlayerClickableArtistText(
            artistString: song.artist,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: .75),
              fontWeight: FontWeight.w500,
            ),
            onArtistTap: onArtistTap,
          ),
          if (streamInfo != null || song.source == MusicSource.local) ...[
            const SizedBox(height: 8),
            PlayerAudioProvenanceBadge(
              song: song,
              streamInfo: streamInfo,
              onTap: onProvenanceTap ?? () {},
            ),
          ],
        ],
      ),
    );
  }
}

/// Truthful audio source and bitrate badge pill with info diagnostics trigger.
class PlayerAudioProvenanceBadge extends StatelessWidget {
  const PlayerAudioProvenanceBadge({
    super.key,
    required this.song,
    required this.streamInfo,
    required this.onTap,
  });

  final Song song;
  final StreamInfo? streamInfo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOffline = song.source == MusicSource.local;
    final provenance = streamInfo?.streamProvenance;

    IconData sourceIcon;
    String sourceName;
    if (isOffline) {
      sourceIcon = Icons.offline_pin_rounded;
      sourceName = 'Offline';
    } else {
      switch (provenance) {
        case 'jiosaavn_matched':
          sourceIcon = Icons.graphic_eq_rounded;
          sourceName = 'JioSaavn';
          break;
        case 'youtube_explode':
          sourceIcon = Icons.play_circle_fill_rounded;
          sourceName = 'YouTube';
          break;
        case 'piped_proxy':
          sourceIcon = Icons.shield_outlined;
          sourceName = 'Piped';
          break;
        case 'invidious_instance':
          sourceIcon = Icons.dns_rounded;
          sourceName = 'Invidious';
          break;
        default:
          sourceIcon = Icons.music_note_rounded;
          sourceName = song.source == MusicSource.spotify ? 'Spotify' : 'Direct';
          break;
      }
    }

    final bitrate = streamInfo?.bitrate ?? 0;
    final codec = (streamInfo?.codec ?? '').toUpperCase();
    final formatText = bitrate > 0
        ? '$bitrate kbps · $codec'
        : (codec.isNotEmpty ? codec : '');
    final matchConfidence = streamInfo?.matchConfidence;
    final hasMatchConfidence =
        matchConfidence != null && provenance == 'jiosaavn_matched';
    final matchPercent =
        matchConfidence != null ? (matchConfidence * 100).round() : null;

    return Semantics(
      button: true,
      label: 'Audio stream details: $sourceName $formatText',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PrismRadius.pill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(PrismRadius.pill),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                width: 0.5,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    sourceIcon,
                    size: 13,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    sourceName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (formatText.isNotEmpty) ...[
                    Text(
                      ' · ',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      formatText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (hasMatchConfidence) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: (matchPercent != null && matchPercent >= 85)
                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                            : Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(PrismRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 9,
                            color: (matchPercent != null && matchPercent >= 85)
                                ? theme.colorScheme.primary
                                : Colors.amber,
                          ),
                          const SizedBox(width: 2.5),
                          Text(
                            '$matchPercent%',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color:
                                  (matchPercent != null && matchPercent >= 85)
                                      ? theme.colorScheme.primary
                                      : Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(
                    Icons.info_outline_rounded,
                    size: 11,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tappable multi-artist line ("A, B, C" → each name links to ArtistPage).
class PlayerClickableArtistText extends StatefulWidget {
  const PlayerClickableArtistText({
    super.key,
    required this.artistString,
    required this.style,
    required this.onArtistTap,
  });

  final String artistString;
  final TextStyle? style;
  final void Function(String) onArtistTap;

  @override
  State<PlayerClickableArtistText> createState() =>
      _PlayerClickableArtistTextState();
}

class _PlayerClickableArtistTextState extends State<PlayerClickableArtistText> {
  late List<TapGestureRecognizer> _recognizers;

  @override
  void initState() {
    super.initState();
    _buildRecognizers();
  }

  @override
  void didUpdateWidget(covariant PlayerClickableArtistText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artistString != widget.artistString) {
      _disposeRecognizers();
      _buildRecognizers();
    }
  }

  void _buildRecognizers() {
    final artistCount = widget.artistString.split(RegExp(r',\s*')).length;
    _recognizers = List.generate(
      artistCount,
      (_) => TapGestureRecognizer()..onTap = () {},
    );
    final names = widget.artistString.split(RegExp(r',\s*'));
    for (var i = 0; i < names.length && i < _recognizers.length; i++) {
      final name = names[i].trim();
      _recognizers[i].onTap = () => widget.onArtistTap(name);
    }
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = widget.artistString.split(RegExp(r',\s*'));
    final spans = <InlineSpan>[];
    for (var i = 0; i < names.length; i++) {
      if (i > 0) {
        spans.add(TextSpan(text: ', ', style: widget.style));
      }
      if (i < _recognizers.length) {
        spans.add(
          TextSpan(
            text: names[i].trim(),
            style: widget.style?.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: widget.style?.color?.withValues(alpha: .4),
            ),
            recognizer: _recognizers[i],
          ),
        );
      } else {
        spans.add(TextSpan(text: names[i].trim(), style: widget.style));
      }
    }
    return RichText(
      text: TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }
}
