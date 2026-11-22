import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/song_scan_data.dart';
import '../../blocs/player/player_bloc.dart';
import '../../blocs/player/player_event.dart';
import '../../blocs/player/player_state.dart';

/// 48-bar interactive waveform scrubber with Best-Part climax drop chip.
class WaveformScrubber extends StatefulWidget {
  final Color? dominantColor;
  final SongScanData? scanData;
  final double height;

  const WaveformScrubber({
    super.key,
    this.dominantColor,
    this.scanData,
    this.height = 42.0,
  });

  @override
  State<WaveformScrubber> createState() => _WaveformScrubberState();
}

class _WaveformScrubberState extends State<WaveformScrubber> {
  static const int _barCount = 48;
  double? _dragProgress;

  // Stable pseudo-random amplitudes generated from song ID/scan data
  late final List<double> _barHeights;

  @override
  void initState() {
    super.initState();
    _initBars();
  }

  void _initBars() {
    final rand = math.Random(widget.scanData?.songId.hashCode ?? 42);
    _barHeights = List.generate(_barCount, (i) {
      // Create musical energy curve (lower at edges, energetic in middle climax)
      final centerNorm = 1.0 - ((i - _barCount / 2).abs() / (_barCount / 2));
      final base = 0.25 + 0.45 * centerNorm;
      final jitter = (rand.nextDouble() - 0.5) * 0.3;
      return (base + jitter).clamp(0.15, 1.0);
    });
  }

  String _formatDuration(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  void _onSeek(double progress, Duration totalDuration) {
    HapticFeedback.selectionClick();
    final targetMs = (progress * totalDuration.inMilliseconds).round();
    context.read<PlayerBloc>().add(SeekEvent(Duration(milliseconds: targetMs)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.dominantColor ?? theme.colorScheme.primary;

    return BlocBuilder<PlayerBloc, PlayerState>(
      buildWhen: (prev, curr) =>
          prev.position != curr.position ||
          prev.duration != curr.duration ||
          prev.currentSong?.id != curr.currentSong?.id,
      builder: (context, state) {
        final totalDuration = state.duration;
        final currentPosition = state.position;
        final totalMs = totalDuration.inMilliseconds > 0
            ? totalDuration.inMilliseconds
            : 1;

        final currentProgress = (currentPosition.inMilliseconds / totalMs).clamp(0.0, 1.0);
        final effectiveProgress = _dragProgress ?? currentProgress;

        final bestPartStart = widget.scanData?.bestPartStartSeconds ?? 0.0;
        final hasBestPart = bestPartStart > 0.0 &&
            bestPartStart < totalDuration.inSeconds;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasBestPart) ...[
              Align(
                alignment: Alignment(
                  (bestPartStart / (totalDuration.inSeconds > 0 ? totalDuration.inSeconds : 1)) * 2.0 - 1.0,
                  0,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      context.read<PlayerBloc>().add(
                            SeekEvent(Duration(seconds: bestPartStart.round())),
                          );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade600,
                            Colors.orange.shade500,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 11,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Best Part ${_formatDuration(Duration(seconds: bestPartStart.round()))}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box != null) {
                  final localX = box.globalToLocal(details.globalPosition).dx;
                  final p = (localX / box.size.width).clamp(0.0, 1.0);
                  setState(() => _dragProgress = p);
                }
              },
              onHorizontalDragUpdate: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box != null) {
                  final localX = box.globalToLocal(details.globalPosition).dx;
                  final p = (localX / box.size.width).clamp(0.0, 1.0);
                  setState(() => _dragProgress = p);
                }
              },
              onHorizontalDragEnd: (details) {
                if (_dragProgress != null) {
                  _onSeek(_dragProgress!, totalDuration);
                  setState(() => _dragProgress = null);
                }
              },
              onTapDown: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box != null) {
                  final localX = box.globalToLocal(details.globalPosition).dx;
                  final p = (localX / box.size.width).clamp(0.0, 1.0);
                  _onSeek(p, totalDuration);
                }
              },
              child: SizedBox(
                height: widget.height,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _WaveformPainter(
                    barHeights: _barHeights,
                    progress: effectiveProgress,
                    activeColor: accent,
                    inactiveColor: theme.colorScheme.onSurface.withOpacity(0.2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(
                      _dragProgress != null
                          ? Duration(
                              milliseconds: (_dragProgress! * totalMs).round(),
                            )
                          : currentPosition,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    _formatDuration(totalDuration),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> barHeights;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  _WaveformPainter({
    required this.barHeights,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final count = barHeights.length;
    if (count == 0) return;

    final totalWidth = size.width;
    final barWidth = (totalWidth / count) * 0.65;
    final gap = (totalWidth - (barWidth * count)) / (count - 1);
    final centerY = size.height / 2.0;

    final activePaint = Paint()
      ..color = activeColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    for (int i = 0; i < count; i++) {
      final x = i * (barWidth + gap) + barWidth / 2.0;
      final barNorm = barHeights[i];
      final halfHeight = (barNorm * size.height * 0.45).clamp(2.0, size.height * 0.48);

      final isPast = (x / totalWidth) <= progress;
      final paint = isPast ? activePaint : inactivePaint;

      canvas.drawLine(
        Offset(x, centerY - halfHeight),
        Offset(x, centerY + halfHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
