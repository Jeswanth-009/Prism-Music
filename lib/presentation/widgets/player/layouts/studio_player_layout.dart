import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../domain/entities/song.dart';
import '../../../blocs/player/player_state.dart';
import '../audio_visualizer_widget.dart';
import '../player_action_bar.dart';
import '../player_controls_section.dart';
import '../waveform_scrubber.dart';

/// Studio Reference layout with audio visualizer, acoustic diagnostics, and precision controls.
class StudioPlayerLayout extends StatelessWidget {
  final Song song;
  final PlayerState state;
  final Color? dominantColor;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;
  final ValueChanged<String> onArtistTap;
  final VoidCallback onProvenanceTap;

  const StudioPlayerLayout({
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
    final streamInfo = state.currentStreamInfo;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Column(
          children: [
            // Studio Header Diagnostic Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'STUDIO MASTER  •  ${streamInfo?.codec.toUpperCase() ?? "AAC"}  •  ${streamInfo?.bitrate ?? 320} KBPS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Artwork & Spectrum Display
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: song.thumbnails.best != null
                          ? CachedNetworkImage(
                              imageUrl: song.thumbnails.best!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.album_rounded, size: 64),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AudioVisualizerWidget(
                        isPlaying: state.status == PlayerStatus.playing,
                        dominantColor: accent,
                        height: 48,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Precision 48-bar Waveform Scrubber
            WaveformScrubber(
              dominantColor: accent,
            ),
            const SizedBox(height: 16),

            // Transport Deck
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
    );
  }
}
