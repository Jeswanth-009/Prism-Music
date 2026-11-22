import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../domain/entities/song.dart';
import '../../../blocs/player/player_state.dart';
import '../player_action_bar.dart';
import '../player_controls_section.dart';
import '../player_metadata_row.dart';
import '../waveform_scrubber.dart';

/// Full-bleed player layout displaying edge-to-edge album artwork with gradient scrim.
class FullBleedPlayerLayout extends StatelessWidget {
  final Song song;
  final PlayerState state;
  final Color? dominantColor;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;
  final ValueChanged<String> onArtistTap;
  final VoidCallback onProvenanceTap;

  const FullBleedPlayerLayout({
    super.key,
    required this.song,
    required this.state,
    this.dominantColor,
    required this.showLyrics,
    required this.onToggleLyrics,
    required this.onArtistTap,
    required this.onProvenanceTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = dominantColor ?? theme.colorScheme.primary;

    return Stack(
      children: [
        // Background Artwork
        Positioned.fill(
          child: song.thumbnails.best != null
              ? CachedNetworkImage(
                  imageUrl: song.thumbnails.best!,
                  fit: BoxFit.cover,
                )
              : Container(color: Colors.black87),
        ),

        // Gradient Scrim
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.95),
                ],
                stops: const [0.0, 0.35, 0.7, 1.0],
              ),
            ),
          ),
        ),

        // Content
        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Spacer(),
                  PlayerMetadataRow(
                    song: song,
                    streamInfo: state.currentStreamInfo,
                    onArtistTap: onArtistTap,
                    onProvenanceTap: onProvenanceTap,
                  ),
                  const SizedBox(height: 16),
                  WaveformScrubber(
                    dominantColor: accent,
                  ),
                  const SizedBox(height: 12),
                  PlayerControlsSection(state: state),
                  const SizedBox(height: 8),
                  PlayerActionBar(
                    song: song,
                    state: state,
                    showLyrics: showLyrics,
                    onToggleLyrics: onToggleLyrics,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
