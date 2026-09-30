import 'package:flutter/material.dart';

import '../../../core/services/chart_service.dart';

/// Accent hue for a chart category, tuned to read on both the ink (dark)
/// and paper (light) themes.
Color chartAccent(ChartIconType type) => switch (type) {
  ChartIconType.global => const Color(0xFF5B9CF6), // blue
  ChartIconType.viral => const Color(0xFFFF6B5E), // coral
  ChartIconType.trending => const Color(0xFF2FBF9B), // teal
  ChartIconType.top => const Color(0xFFF2B33D), // amber
  ChartIconType.chart => const Color(0xFF8B7BFF), // violet
  ChartIconType.newRelease => const Color(0xFFF07EB0), // pink
};

IconData chartIcon(ChartIconType type) => switch (type) {
  ChartIconType.global => Icons.public_rounded,
  ChartIconType.viral => Icons.local_fire_department_rounded,
  ChartIconType.trending => Icons.trending_up_rounded,
  ChartIconType.top => Icons.emoji_events_outlined,
  ChartIconType.chart => Icons.bar_chart_rounded,
  ChartIconType.newRelease => Icons.auto_awesome_outlined,
};

String chartSourceLabel(ChartSource source) => switch (source) {
  ChartSource.billboard => 'Billboard',
  ChartSource.youtube => 'YouTube',
  ChartSource.spotify => 'Spotify',
};

/// Rounded accent chip carrying a chart's icon, shared by the charts hub
/// and chart pages.
class PrismChartChip extends StatelessWidget {
  const PrismChartChip({super.key, required this.type, this.size = 40});

  final ChartIconType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = chartAccent(type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        chartIcon(type),
        size: size * 0.5,
        color: accent,
      ),
    );
  }
}
