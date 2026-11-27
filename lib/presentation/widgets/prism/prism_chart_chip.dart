import 'package:flutter/material.dart';

import '../../../core/services/chart_service.dart';
import '../../theme/prism_theme.dart';

/// Accent hue for a chart category. Data colours — they identify the
/// category's feed, they are not chrome — so they live in [PrismColors].
Color chartAccent(ChartIconType type) => switch (type) {
  ChartIconType.global => PrismColors.dataBlue,
  ChartIconType.viral => PrismColors.dataCoral,
  ChartIconType.trending => PrismColors.dataTeal,
  ChartIconType.top => PrismColors.dataAmber,
  ChartIconType.chart => PrismColors.dataViolet,
  ChartIconType.newRelease => PrismColors.dataPink,
};

IconData chartIcon(ChartIconType type) => switch (type) {
  ChartIconType.global => Icons.public_rounded,
  ChartIconType.viral => Icons.local_fire_department_rounded,
  ChartIconType.trending => Icons.trending_up_rounded,
  ChartIconType.top => Icons.emoji_events_rounded,
  ChartIconType.chart => Icons.bar_chart_rounded,
  ChartIconType.newRelease => Icons.auto_awesome_rounded,
};

String chartSourceLabel(ChartSource source) => switch (source) {
  ChartSource.billboard => 'Billboard',
  ChartSource.youtube => 'YouTube Music',
  ChartSource.spotify => 'Spotify',
  ChartSource.appleMusic => 'Apple Music',
  ChartSource.kworb => 'Kworb WW',
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
