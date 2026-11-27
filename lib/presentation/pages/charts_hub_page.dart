import 'package:flutter/material.dart';

import '../../core/services/chart_service.dart';
import '../../core/services/settings_service.dart';
import '../theme/prism_theme.dart';
import '../widgets/common/bouncing_tap_widget.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/prism/prism_chart_chip.dart';
import '../widgets/prism/prism_states.dart';
import 'chart_page.dart';

/// Charts Hub — reads like a leaderboard, not a settings grid.
///
/// A featured strip flags each provider's flagship countdown, then every
/// chart is listed under its provider as a scannable row. The provider
/// hue appears only where it identifies data (dots, overlines, watermarks);
/// the chrome stays on the neutral surface ladder.
class ChartsHubPage extends StatefulWidget {
  final bool embedded;

  const ChartsHubPage({super.key, this.embedded = false});

  @override
  State<ChartsHubPage> createState() => _ChartsHubPageState();
}

class _ChartsHubPageState extends State<ChartsHubPage> {
  final _settings = SettingsService.instance;
  ChartSource? _selectedPlatform; // null = All

  static const _featuredOrder = [
    ChartSource.appleMusic,
    ChartSource.billboard,
    ChartSource.spotify,
    ChartSource.youtube,
  ];

  Color _getPlatformAccent(ChartSource source, ColorScheme scheme) {
    return switch (source) {
      ChartSource.appleMusic => PrismColors.brandApple,
      ChartSource.spotify => PrismColors.brandSpotify,
      ChartSource.youtube => PrismColors.brandYouTube,
      ChartSource.billboard => PrismColors.brandBillboard,
      ChartSource.kworb => PrismColors.dataTeal,
    };
  }

  @override
  Widget build(BuildContext context) {
    List<ChartDefinition> charts;
    String? error;
    try {
      charts = ChartService.getAvailableCharts(
        _settings.countryCode,
        _settings.selectedCountry.name,
      );
    } catch (e) {
      charts = const [];
      error = e.toString();
    }

    final filteredCharts = _selectedPlatform == null
        ? charts
        : charts.where((c) => c.source == _selectedPlatform).toList();

    final theme = Theme.of(context);
    final spec = context.prismSpec;

    // Featured strip: the flagship countdown of each provider.
    final featured = <ChartDefinition>[];
    if (_selectedPlatform == null) {
      for (final source in _featuredOrder) {
        final match = charts.where((c) => c.source == source).firstOrNull;
        if (match != null) featured.add(match);
      }
    }

    // Leaderboard rows grouped under their provider.
    final groups = <ChartSource, List<ChartDefinition>>{};
    for (final chart in filteredCharts) {
      groups.putIfAbsent(chart.source, () => []).add(chart);
    }

    final body = SafeArea(
      bottom: false,
      child: CustomScrollView(
        key: const PageStorageKey('charts_hub'),
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              PrismSpacing.gutter,
              PrismSpacing.xl,
              PrismSpacing.gutter,
              PrismSpacing.md,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OFFICIAL COUNTDOWNS',
                    style: PrismText.overline(context)?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: PrismSpacing.xs),
                  Text(
                    'Streaming Charts',
                    style: theme.textTheme.headlineLarge,
                  ),
                  const SizedBox(height: PrismSpacing.xs + 2),
                  Text(
                    'What the world is playing across Apple Music, Spotify, YouTube & Billboard.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: PrismSpacing.md + 2),
                  Wrap(
                    spacing: PrismSpacing.sm,
                    runSpacing: PrismSpacing.xs + 2,
                    children: [
                      InkWell(
                        onTap: () => _showCountryPicker(context),
                        borderRadius: BorderRadius.circular(PrismRadius.pill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: PrismSpacing.sm + 2,
                            vertical: PrismSpacing.xs + 2,
                          ),
                          decoration: BoxDecoration(
                            color: spec.accentSoft,
                            borderRadius:
                                BorderRadius.circular(PrismRadius.pill),
                            border: Border.all(color: spec.hairline),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _RegionBadge(
                                code: _settings.selectedCountry.code,
                                hue: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: PrismSpacing.xs + 2),
                              Text(
                                _settings.selectedCountry.name,
                                style: theme.textTheme.labelLarge,
                              ),
                              const SizedBox(width: PrismSpacing.xs),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: PrismIconSize.sm,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: PrismSpacing.sm + 2,
                          vertical: PrismSpacing.xs + 3,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius:
                              BorderRadius.circular(PrismRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.sync_rounded,
                              size: PrismIconSize.sm,
                              color: spec.success,
                            ),
                            const SizedBox(width: PrismSpacing.xs + 2),
                            Text(
                              'Live Multi-Feed',
                              style: PrismText.overline(context)?.copyWith(
                                color: spec.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Provider filters ─────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: PrismSpacing.gutter,
                ),
                children: [
                  _buildFilterPill(
                    theme: theme,
                    label: 'All Charts',
                    isSelected: _selectedPlatform == null,
                    onTap: () => setState(() => _selectedPlatform = null),
                  ),
                  _buildFilterPill(
                    theme: theme,
                    label: 'Apple Music',
                    accentColor: PrismColors.brandApple,
                    isSelected: _selectedPlatform == ChartSource.appleMusic,
                    onTap: () => setState(
                        () => _selectedPlatform = ChartSource.appleMusic),
                  ),
                  _buildFilterPill(
                    theme: theme,
                    label: 'Spotify',
                    accentColor: PrismColors.brandSpotify,
                    isSelected: _selectedPlatform == ChartSource.spotify,
                    onTap: () =>
                        setState(() => _selectedPlatform = ChartSource.spotify),
                  ),
                  _buildFilterPill(
                    theme: theme,
                    label: 'YouTube Music',
                    accentColor: PrismColors.brandYouTube,
                    isSelected: _selectedPlatform == ChartSource.youtube,
                    onTap: () => setState(
                        () => _selectedPlatform = ChartSource.youtube),
                  ),
                  _buildFilterPill(
                    theme: theme,
                    label: 'Billboard',
                    accentColor: PrismColors.brandBillboard,
                    isSelected: _selectedPlatform == ChartSource.billboard,
                    onTap: () => setState(
                        () => _selectedPlatform = ChartSource.billboard),
                  ),
                  _buildFilterPill(
                    theme: theme,
                    label: 'Kworb WW',
                    accentColor: PrismColors.dataTeal,
                    isSelected: _selectedPlatform == ChartSource.kworb,
                    onTap: () =>
                        setState(() => _selectedPlatform = ChartSource.kworb),
                  ),
                ],
              ),
            ),
          ),

          if (error != null || filteredCharts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: PrismErrorState(
                title: 'Could not load charts',
                message: error ??
                    'No charts found for this platform in ${_settings.selectedCountry.name}. Tap to reload.',
                onRetry: () => setState(() {}),
              ),
            )
          else ...[
            // ── Featured countdowns ────────────────────────────────
            if (featured.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 172,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      PrismSpacing.gutter,
                      PrismSpacing.lg,
                      PrismSpacing.gutter,
                      0,
                    ),
                    itemCount: featured.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: PrismSpacing.railGap),
                    itemBuilder: (context, index) {
                      return _FeaturedChartCard(
                        chart: featured[index],
                        accent:
                            _getPlatformAccent(featured[index].source, theme.colorScheme),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChartPage(chart: featured[index]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // ── Leaderboard, grouped by provider ───────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                PrismSpacing.gutter,
                PrismSpacing.xl,
                PrismSpacing.gutter,
                PrismSpacing.xxxl,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                          top: PrismSpacing.lg,
                          bottom: PrismSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getPlatformAccent(
                                    entry.key, theme.colorScheme),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: PrismSpacing.xs + 2),
                            Text(
                              chartSourceLabel(entry.key).toUpperCase(),
                              style: PrismText.overline(context)?.copyWith(
                                color: _getPlatformAccent(
                                    entry.key, theme.colorScheme),
                              ),
                            ),
                            const SizedBox(width: PrismSpacing.sm),
                            Expanded(
                              child: Text(
                                '${entry.value.length} charts',
                                style: PrismText.tabular(
                                  theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final chart in entry.value)
                        _ChartRow(
                          chart: chart,
                          accent:
                              _getPlatformAccent(chart.source, theme.colorScheme),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChartPage(chart: chart),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Charts'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      bottomNavigationBar: const PrismPersistentMiniPlayer(),
      body: body,
    );
  }

  void _showCountryPicker(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(PrismRadius.xl)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = supportedCountries
                .where((c) =>
                    c.name.toLowerCase().contains(query.toLowerCase()) ||
                    c.code.toLowerCase().contains(query.toLowerCase()))
                .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.outlineVariant,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: PrismSpacing.md),
                          Text(
                            'Select Music Region',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: PrismSpacing.sm),
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Search countries...',
                              prefixIcon: const Icon(Icons.search_rounded, size: 20),
                              isDense: true,
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerHigh,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(PrismRadius.md),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (val) {
                              setModalState(() {
                                query = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final c = filtered[idx];
                          final isSelected = c.code == _settings.countryCode;
                          return ListTile(
                            leading: _RegionBadge(
                              code: c.code,
                              hue: theme.colorScheme.primary,
                            ),
                            title: Text(
                              c.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                                : null,
                            onTap: () async {
                              await _settings.setCountryCode(c.code);
                              if (context.mounted) Navigator.of(context).pop();
                              if (mounted) setState(() {});
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFilterPill({
    required ThemeData theme,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? accentColor,
  }) {
    final activeColor = accentColor ?? theme.colorScheme.primary;
    final spec = context.prismSpec;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: PrismMotion.fastOf(context),
        curve: PrismMotion.curve,
        margin: const EdgeInsets.only(right: PrismSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: PrismSpacing.md + 2,
          vertical: PrismSpacing.xs + 3,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? spec.accentSoft
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(PrismRadius.pill),
          border: Border.all(
            color: isSelected
                ? activeColor.withValues(alpha: 0.6)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (accentColor != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: PrismSpacing.xs + 2),
            ],
            Text(
              label,
              style: PrismText.overline(context)?.copyWith(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flagship countdown card: provider hue as a wash, glyph watermark,
/// overline provider identity, and a clear affordance to open.
class _FeaturedChartCard extends StatelessWidget {
  const _FeaturedChartCard({
    required this.chart,
    required this.accent,
    required this.onTap,
  });

  final ChartDefinition chart;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = context.prismSpec;
    return Semantics(
      button: true,
      label: '${chart.name}, ${chartSourceLabel(chart.source)}, ${chart.description}',
      child: BouncingTapWidget(
        onTap: onTap,
        child: Container(
          width: 300,
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              accent.withValues(alpha: 0.16),
              theme.colorScheme.surfaceContainer,
            ),
            borderRadius: BorderRadius.circular(PrismRadius.xl),
            border: Border.all(color: spec.hairline),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(PrismRadius.xl),
            child: Stack(
              children: [
                Positioned(
                  right: -18,
                  top: -18,
                  child: Icon(
                    Icons.leaderboard_rounded,
                    size: 120,
                    color: accent.withValues(alpha: 0.12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(PrismSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          PrismChartChip(type: chart.iconType, size: 34),
                          const Spacer(),
                          Icon(
                            Icons.verified_rounded,
                            size: PrismIconSize.sm,
                            color: accent,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        chartSourceLabel(chart.source).toUpperCase(),
                        style: PrismText.overline(context)
                            ?.copyWith(color: accent),
                      ),
                      const SizedBox(height: PrismSpacing.xs + 2),
                      Text(
                        chart.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: PrismSpacing.xs),
                      Row(
                        children: [
                          Text(
                            'View countdown',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: accent,
                            ),
                          ),
                          const SizedBox(width: PrismSpacing.xs),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: PrismIconSize.sm,
                            color: accent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One chart in the leaderboard: chip, name, one-line description.
class _ChartRow extends StatelessWidget {
  const _ChartRow({
    required this.chart,
    required this.accent,
    required this.onTap,
  });

  final ChartDefinition chart;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = context.prismSpec;
    return Semantics(
      button: true,
      label:
          '${chart.name}, ${chartSourceLabel(chart.source)}, ${chart.description}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: PrismSpacing.sm),
        child: Material(
          color: theme.colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PrismRadius.md),
            side: BorderSide(color: spec.hairline),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(PrismRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PrismSpacing.md,
                vertical: PrismSpacing.md,
              ),
              child: Row(
                children: [
                  PrismChartChip(type: chart.iconType, size: 44),
                  const SizedBox(width: PrismSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chart.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: PrismSpacing.xxs + 1),
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
                  const SizedBox(width: PrismSpacing.sm),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: PrismIconSize.lg,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Region identity as a two-letter code badge — flags stay out of the UI.
class _RegionBadge extends StatelessWidget {
  const _RegionBadge({required this.code, required this.hue});

  final String code;
  final Color hue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(PrismRadius.xs),
        border: Border.all(color: hue.withValues(alpha: 0.35)),
      ),
      child: Text(
        code.toUpperCase(),
        style: PrismText.overline(context)?.copyWith(
          color: hue,
          fontSize: 9,
          height: 1,
        ),
      ),
    );
  }
}
