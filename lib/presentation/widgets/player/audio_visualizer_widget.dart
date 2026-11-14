import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/visualizer_service.dart';

/// Real-time interactive audio visualizer widget for PlayerPage.
/// Renders spectrum bars, smooth waveforms, or radial pulses.
class AudioVisualizerWidget extends StatefulWidget {
  final bool isPlaying;
  final double volume;
  final Color? dominantColor;
  final double height;
  final VoidCallback? onStyleChanged;

  const AudioVisualizerWidget({
    super.key,
    required this.isPlaying,
    this.volume = 1.0,
    this.dominantColor,
    this.height = 48.0,
    this.onStyleChanged,
  });

  @override
  State<AudioVisualizerWidget> createState() => _AudioVisualizerWidgetState();
}

class _AudioVisualizerWidgetState extends State<AudioVisualizerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  double _elapsed = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(_onTick);

    if (widget.isPlaying) {
      _ticker.repeat();
    }
  }

  void _onTick() {
    setState(() {
      _elapsed += 0.025;
    });
  }

  @override
  void didUpdateWidget(covariant AudioVisualizerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _ticker.repeat();
      } else {
        _ticker.stop();
      }
    }
  }

  @override
  void dispose() {
    _ticker.removeListener(_onTick);
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await VisualizerService.instance.cycleStyle();
    widget.onStyleChanged?.call();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final style = VisualizerService.instance.style;
    if (style == VisualizerStyle.off) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final accent = widget.dominantColor ?? theme.colorScheme.primary;

    final amplitudes = VisualizerService.instance.computeAmplitudes(
      timeSeconds: _elapsed,
      isPlaying: widget.isPlaying,
      volume: widget.volume,
      count: style == VisualizerStyle.bars ? 24 : 32,
    );

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: CustomPaint(
          painter: _VisualizerPainter(
            style: style,
            amplitudes: amplitudes,
            color: accent,
            time: _elapsed,
          ),
        ),
      ),
    );
  }
}

class _VisualizerPainter extends CustomPainter {
  final VisualizerStyle style;
  final List<double> amplitudes;
  final Color color;
  final double time;

  _VisualizerPainter({
    required this.style,
    required this.amplitudes,
    required this.color,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case VisualizerStyle.bars:
        _paintBars(canvas, size);
        break;
      case VisualizerStyle.wave:
        _paintWave(canvas, size);
        break;
      case VisualizerStyle.pulse:
        _paintPulse(canvas, size);
        break;
      case VisualizerStyle.off:
        break;
    }
  }

  void _paintBars(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final count = amplitudes.length;
    const spacing = 3.0;
    final totalSpacing = spacing * (count - 1);
    final barWidth = (size.width - totalSpacing) / count;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          color.withValues(alpha: 0.85),
          color.withValues(alpha: 0.35),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    for (int i = 0; i < count; i++) {
      final amp = amplitudes[i];
      final barHeight = (amp * size.height).clamp(4.0, size.height);
      final left = i * (barWidth + spacing);
      final top = size.height - barHeight;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        const Radius.circular(2.5),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  void _paintWave(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final path = Path();
    final midY = size.height / 2;
    path.moveTo(0, midY);

    final step = size.width / (amplitudes.length - 1);
    for (int i = 0; i < amplitudes.length; i++) {
      final x = i * step;
      final amp = amplitudes[i];
      final offset = (amp - 0.5) * (size.height * 0.8);
      final y = midY + offset * math.sin((time * 3) + (i * 0.4));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = (i - 1) * step;
        final cx = (prevX + x) / 2;
        path.quadraticBezierTo(cx, y, x, y);
      }
    }

    final strokePaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);
  }

  void _paintPulse(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final avgAmp = amplitudes.isEmpty
        ? 0.0
        : amplitudes.reduce((a, b) => a + b) / amplitudes.length;

    final maxRadius = math.min(size.width / 2, size.height / 2);
    for (int r = 1; r <= 3; r++) {
      final progress = ((time * 0.8) + (r * 0.33)) % 1.0;
      final radius = (progress * maxRadius * (0.6 + avgAmp * 0.4));
      final alpha = (1.0 - progress) * (0.6 * avgAmp);

      final pulsePaint = Paint()
        ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, pulsePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VisualizerPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.style != style ||
        oldDelegate.color != color;
  }
}
