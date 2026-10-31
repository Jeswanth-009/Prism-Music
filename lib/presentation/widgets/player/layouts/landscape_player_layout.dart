import 'package:flutter/material.dart';

import '../../../../domain/entities/song.dart';
import '../../../blocs/player/player_state.dart';
import '../../common/adaptive_layout.dart';
import '../player_action_bar.dart';
import '../player_artwork_section.dart';
import '../player_controls_section.dart';
import '../player_lyrics_sheet.dart';
import '../player_metadata_row.dart';
import '../player_slider_widget.dart';

/// Landscape and tablet split-pane player layout:
/// Artwork / lyrics on the left, metadata and transport controls on the right.
class LandscapePlayerLayout extends StatelessWidget {
  final Song song;
  final PlayerState state;
  final Color? dominantColor;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;
  final void Function(String artistName) onArtistTap;
  final VoidCallback onProvenanceTap;

  const LandscapePlayerLayout({
    super.key,
    required this.song,
    required this.state,
    required this.dominantColor,
    required this.showLyrics,
    required this.onToggleLyrics,
    required this.onArtistTap,
    required this.onProvenanceTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = AdaptiveBreakpoints.isTablet(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive artwork bounds based on available height
        final double maxArtworkSize = isTablet
            ? (constraints.maxHeight * 0.75).clamp(280.0, 480.0)
            : (constraints.maxHeight * 0.85).clamp(200.0, 340.0);

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 36.0 : 24.0,
            vertical: isTablet ? 16.0 : 8.0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Pane: Artwork or Lyrics
              Expanded(
                flex: isTablet ? 5 : 5,
                child: Center(
                  child: showLyrics
                      ? ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight > 0
                                ? constraints.maxHeight
                                : 600,
                            maxWidth: isTablet ? 560 : 380,
                          ),
                          child: PlayerLyricsView(
                            key: ValueKey('lyrics_${song.id}'),
                            song: song,
                          ),
                        )
                      : ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: maxArtworkSize,
                            maxWidth: maxArtworkSize,
                          ),
                          child: PlayerArtworkSection(
                            song: song,
                            dominantColor: dominantColor,
                          ),
                        ),
                ),
              ),
              SizedBox(width: isTablet ? 32 : 24),
              // Right Pane: Song Info + Scrubber + Controls
              Expanded(
                flex: isTablet ? 6 : 6,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? 540 : 420,
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PlayerMetadataRow(
                            song: song,
                            streamInfo: state.currentStreamInfo,
                            onArtistTap: onArtistTap,
                            onProvenanceTap: onProvenanceTap,
                          ),
                          const SizedBox(height: 12),
                          PlayerSliderWidget(state: state),
                          const SizedBox(height: 8),
                          PlayerControlsSection(state: state),
                          const SizedBox(height: 4),
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
              ),
            ],
          ),
        );
      },
    );
  }
}
