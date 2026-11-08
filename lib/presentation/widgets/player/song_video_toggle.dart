import 'package:flutter/material.dart';

/// Segmented pill switch for switching between Audio (Song) and Video mode.
class SongVideoToggle extends StatelessWidget {
  final bool isVideoMode;
  final bool isVideoAvailable;
  final ValueChanged<bool> onToggle;

  const SongVideoToggle({
    super.key,
    required this.isVideoMode,
    required this.isVideoAvailable,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVideoAvailable && !isVideoMode) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Song (Audio) Tab
          GestureDetector(
            onTap: isVideoMode ? () => onToggle(false) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: !isVideoMode
                    ? (isDark
                        ? Colors.white.withOpacity(0.2)
                        : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.music_note_rounded,
                    size: 14,
                    color: !isVideoMode ? Colors.white : Colors.white60,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Song',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: !isVideoMode ? FontWeight.w600 : FontWeight.normal,
                      color: !isVideoMode ? Colors.white : Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Video Tab
          GestureDetector(
            onTap: isVideoAvailable && !isVideoMode ? () => onToggle(true) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isVideoMode
                    ? (isDark
                        ? Colors.white.withOpacity(0.2)
                        : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.smart_display_rounded,
                    size: 14,
                    color: isVideoMode
                        ? Colors.white
                        : (isVideoAvailable ? Colors.white60 : Colors.white24),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Video',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isVideoMode ? FontWeight.w600 : FontWeight.normal,
                      color: isVideoMode
                          ? Colors.white
                          : (isVideoAvailable ? Colors.white60 : Colors.white24),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
