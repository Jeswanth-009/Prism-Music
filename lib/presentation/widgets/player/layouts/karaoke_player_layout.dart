import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../domain/entities/song.dart';
import '../../../blocs/player/player_state.dart';
import '../../lyrics/word_synced_lyrics_view.dart';
import '../player_controls_section.dart';
import '../../../theme/prism_theme.dart';

/// Dedicated Karaoke "Sing" layout with 85% vertical lyric viewport and real-time syllable sweep.
class KaraokePlayerLayout extends StatelessWidget {
  final Song song;
  final PlayerState state;
  final Color? dominantColor;
  final String? lyricsText;
  final VoidCallback onExitKaraoke;

  const KaraokePlayerLayout({
    super.key,
    required this.song,
    required this.state,
    this.dominantColor,
    this.lyricsText,
    required this.onExitKaraoke,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = dominantColor ?? theme.colorScheme.primary;

    return Column(
      children: [
        // Top Karaoke Header Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, Colors.pinkAccent],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mic, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'SING KARAOKE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_fullscreen_rounded, color: Colors.white70),
                tooltip: 'Exit Karaoke View',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onExitKaraoke();
                },
              ),
            ],
          ),
        ),

        // 80-85% Screen Space Word-Synced Lyrics
        Expanded(
          child: WordSyncedLyricsView(
            rawLyrics: lyricsText ?? '',
            dominantColor: accent,
            isKaraokeMode: true,
            fontSize: 26.0,
          ),
        ),

        // Bottom Compact Transport Strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: PrismColors.scrim.withValues(alpha: 0.5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: PrismColors.onScrim.withValues(alpha: 0.1),
                width: 1.0,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                PlayerControlsSection(state: state),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
