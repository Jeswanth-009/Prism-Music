import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/services/chart_service.dart';
import '../../core/services/settings_service.dart';
import '../theme/prism_theme.dart';
import 'chart_page.dart';

class ChartsHubPage extends StatefulWidget {
  const ChartsHubPage({super.key});

  @override
  State<ChartsHubPage> createState() => _ChartsHubPageState();
}

class _ChartsHubPageState extends State<ChartsHubPage> {
  final _settings = SettingsService.instance;

  IconData _icon(ChartIconType type) => switch (type) {
    ChartIconType.global => LucideIcons.globe2,
    ChartIconType.viral => LucideIcons.flame,
    ChartIconType.trending => LucideIcons.trendingUp,
    ChartIconType.top => LucideIcons.trophy,
    ChartIconType.chart => LucideIcons.chartNoAxesColumnIncreasing,
    ChartIconType.newRelease => LucideIcons.sparkles,
  };

  @override
  Widget build(BuildContext context) {
    final charts = ChartService.getAvailableCharts(
      _settings.countryCode,
      _settings.selectedCountry.name,
    );
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: AuroraBackdrop(
        child: CustomScrollView(
          key: const PageStorageKey('charts_hub'),
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CHARTS', style: theme.textTheme.labelMedium?.copyWith(color: PrismColors.cyan, fontWeight: FontWeight.w800, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Text('What the world is\nplaying now', style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.4, height: 1.02)),
                    const SizedBox(height: 10),
                    Text('${_settings.selectedCountry.flag} ${_settings.selectedCountry.name} · updated throughout the day', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
              sliver: SliverGrid.builder(
                itemCount: charts.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: .88, crossAxisSpacing: 14, mainAxisSpacing: 14),
                itemBuilder: (context, index) {
                  final chart = charts[index];
                  final colors = [
                    const [Color(0xFF3755D8), Color(0xFF843DCE)],
                    const [Color(0xFF087F9E), Color(0xFF2D50B4)],
                    const [Color(0xFFBE376F), Color(0xFFFF765E)],
                  ][index % 3];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChartPage(chart: chart))),
                      child: Ink(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors), borderRadius: BorderRadius.circular(24)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(_icon(chart.iconType), color: Colors.white, size: 28),
                          const Spacer(),
                          Text(chart.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.05)),
                          const SizedBox(height: 7),
                          Text(chart.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: .78))),
                          const SizedBox(height: 14),
                          const Row(children: [Text('OPEN CHART', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)), Spacer(), Icon(LucideIcons.arrowUpRight, color: Colors.white, size: 18)]),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
