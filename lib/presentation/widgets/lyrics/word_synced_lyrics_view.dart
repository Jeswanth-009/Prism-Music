import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/lyrics/word_synced_lyric.dart';
import '../../blocs/player/player_bloc.dart';
import '../../blocs/player/player_event.dart';
import '../../blocs/player/player_state.dart';

/// Interactive word-synced lyrics view with real-time syllable sweep highlights.
class WordSyncedLyricsView extends StatefulWidget {
  final String rawLyrics;
  final Color? dominantColor;
  final bool isKaraokeMode;
  final double fontSize;

  const WordSyncedLyricsView({
    super.key,
    required this.rawLyrics,
    this.dominantColor,
    this.isKaraokeMode = false,
    this.fontSize = 22.0,
  });

  @override
  State<WordSyncedLyricsView> createState() => _WordSyncedLyricsViewState();
}

class _WordSyncedLyricsViewState extends State<WordSyncedLyricsView> {
  late final ParsedLyrics _parsed;
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;

  @override
  void initState() {
    super.initState();
    _parsed = WordSyncedLyricParser.parse(widget.rawLyrics);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients || index < 0 || index >= _parsed.lines.length) return;
    // Estimate line height for centering
    const estimatedLineHeight = 70.0;
    final targetOffset = (index * estimatedLineHeight) - 150.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.dominantColor ?? theme.colorScheme.primary;

    if (_parsed.isEmpty) {
      return Center(
        child: Text(
          'No lyrics available',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return BlocBuilder<PlayerBloc, PlayerState>(
      buildWhen: (prev, curr) =>
          prev.position != curr.position ||
          prev.currentSong?.id != curr.currentSong?.id,
      builder: (context, state) {
        final position = state.position;
        final activeIndex = _parsed.getActiveLineIndex(position);

        if (activeIndex != _lastActiveIndex && activeIndex >= 0) {
          _lastActiveIndex = activeIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToIndex(activeIndex);
          });
        }

        return ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: widget.isKaraokeMode ? 40 : 80,
          ),
          itemCount: _parsed.lines.length,
          itemBuilder: (context, index) {
            final line = _parsed.lines[index];
            final isActive = index == activeIndex;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                context.read<PlayerBloc>().add(SeekEvent(line.startTime));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  style: theme.textTheme.headlineSmall!.copyWith(
                    fontSize: isActive ? widget.fontSize * 1.15 : widget.fontSize,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                    color: isActive
                        ? Colors.white
                        : Colors.white.withOpacity(0.35),
                  ),
                  child: line.hasWordTiming && isActive
                      ? _buildWordHighlightedLine(line, position, accent)
                      : Text(line.text),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWordHighlightedLine(LineLyric line, Duration position, Color accent) {
    return Wrap(
      spacing: 4.0,
      runSpacing: 4.0,
      children: line.words.map((w) {
        final progress = w.getProgress(position);
        final isCompleted = progress >= 1.0;
        final isSinging = progress > 0.0 && progress < 1.0;

        return isSinging
            ? ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: [accent, Colors.white.withOpacity(0.4)],
                    stops: [progress, progress + 0.05],
                  ).createShader(bounds);
                },
                child: Text(
                  w.word,
                  style: const TextStyle(color: Colors.white),
                ),
              )
            : Text(
                w.word,
                style: TextStyle(
                  color: isCompleted ? accent : Colors.white.withOpacity(0.35),
                ),
              );
      }).toList(),
    );
  }
}
