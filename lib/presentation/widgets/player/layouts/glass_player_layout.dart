import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../domain/entities/song.dart';
import '../../../blocs/player/player_state.dart';
import '../player_action_bar.dart';
import '../player_controls_section.dart';
import '../player_metadata_row.dart';
import '../waveform_scrubber.dart';
import '../../../theme/prism_theme.dart';

/// Frosted glass player layout with deep Gaussian blur and glowing control deck.
class GlassPlayerLayout extends StatelessWidget {
  final Song song;
  final PlayerState state;
  final Color? dominantColor;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;
  final ValueChanged<String> onArtistTap;
  final VoidCallback onProvenanceTap;

  const GlassPlayerLayout({
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

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          children: [
            // Glassmorphic Artwork Card
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PrismColors.onScrim.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: PrismColors.onScrim.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (song.thumbnails.best != null)
                            CachedNetworkImage(
                              imageUrl: song.thumbnails.best!,
                              fit: BoxFit.cover,
                            )
                          else
                            Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.music_note_rounded, size: 80),
                            ),
                          // Subtle inner vignette
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  PrismColors.scrim.withValues(alpha: 0.4),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Metadata Card
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: PrismColors.onScrim.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: PrismColors.onScrim.withValues(alpha: 0.12),
                      width: 1.0,
                    ),
                  ),
                  child: PlayerMetadataRow(
                    song: song,
                    streamInfo: state.currentStreamInfo,
                    onArtistTap: onArtistTap,
                    onProvenanceTap: onProvenanceTap,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 48-Bar Waveform Scrubber
            WaveformScrubber(
              dominantColor: accent,
            ),
            const SizedBox(height: 16),

            // Translucent Control Deck
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: PrismColors.onScrim.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: PrismColors.onScrim.withValues(alpha: 0.15),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    children: [
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
        ),
      ),
    );
  }
}
