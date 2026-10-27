import 'package:flutter/material.dart';

import '../../../../domain/entities/song.dart';
import '../../../blocs/player/player_state.dart';
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Pane: Artwork or Lyrics
          Expanded(
            flex: 5,
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxHeight: 340, maxWidth: 340),
                child: showLyrics
                    ? PlayerLyricsView(
                        key: ValueKey('lyrics_${song.id}'),
                        song: song,
                      )
                    : PlayerArtworkSection(
                        song: song,
                        dominantColor: dominantColor,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Right Pane: Song Info + Scrubber + Controls
          Expanded(
            flex: 6,
            child: Center(
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
        ],
      ),
    );
  }
}
