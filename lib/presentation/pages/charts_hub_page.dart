import 'package:flutter/material.dart';

import '../../core/services/chart_service.dart';
import '../../core/services/settings_service.dart';
import '../theme/prism_theme.dart';
import 'chart_page.dart';

/// Charts hub: a calm grid of available charts per region.
class ChartsHubPage extends StatefulWidget {
  const ChartsHubPage({super.key});

  @override
  State<ChartsHubPage> createState() => _ChartsHubPageState();
}

class _ChartsHubPageState extends State<ChartsHubPage> {
  final _settings = SettingsService.instance;

  IconData _icon(ChartIconType type) => switch (type) {
    ChartIconType.global => Icons.public_rounded,
    ChartIconType.viral => Icons.local_fire_department_rounded,
    ChartIconType.trending => Icons.trending_up_rounded,
    ChartIconType.top => Icons.emoji_events_outlined,
    ChartIconType.chart => Icons.bar_chart_rounded,
    ChartIconType.newRelease => Icons.auto_awesome_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final charts = ChartService.getAvailableCharts(
      _settings.countryCode,
      _settings.selectedCountry.name,
    );
    final theme = Theme.of(context);
    final spec = context.prismSpec;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        key: const PageStorageKey('charts_hub'),
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Charts',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.9,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_settings.selectedCountry.flag} ${_settings.selectedCountry.name} · updated throughout the day',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
            sliver: SliverGrid.builder(
              itemCount: charts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.15,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final chart = charts[index];
                return Material(
                  color: theme.colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PrismRadius.lg),
                    side: BorderSide(color: spec.hairline),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(PrismRadius.lg),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChartPage(chart: chart),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: spec.accentSoft,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              _icon(chart.iconType),
                              size: 19,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            chart.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            chart.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
