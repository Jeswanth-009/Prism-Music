import 'package:flutter/material.dart';

import '../../core/services/chart_service.dart';
import '../../core/services/settings_service.dart';
import '../theme/prism_theme.dart';
import '../widgets/common/bouncing_tap_widget.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/prism/prism_chart_chip.dart';
import '../widgets/prism/prism_states.dart';
import 'chart_page.dart';

/// Modern Charts Hub: browse live charts aggregated from Apple Music,
/// Spotify, YouTube Music, and Billboard with platform filtering.
class ChartsHubPage extends StatefulWidget {
  final bool embedded;

  const ChartsHubPage({super.key, this.embedded = false});

  @override
  State<ChartsHubPage> createState() => _ChartsHubPageState();
}

class _ChartsHubPageState extends State<ChartsHubPage> {
  final _settings = SettingsService.instance;
  ChartSource? _selectedPlatform; // null = All

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

    final body = SafeArea(
      bottom: false,
      child: CustomScrollView(
        key: const PageStorageKey('charts_hub'),
        physics: const BouncingScrollPhysics(),
        slivers: [
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
                            borderRadius: BorderRadius.circular(PrismRadius.pill),
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
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.sync_rounded,
                              size: 13,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Live Multi-Feed',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Platform Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterPill(
                          theme: theme,
                          label: 'All Charts',
                          isSelected: _selectedPlatform == null,
                          onTap: () => setState(() => _selectedPlatform = null),
                        ),
                        const SizedBox(width: PrismSpacing.sm),
                        _buildFilterPill(
                          theme: theme,
                          label: 'Apple Music',
                          accentColor: PrismColors.brandApple,
                          isSelected: _selectedPlatform == ChartSource.appleMusic,
                          onTap: () => setState(() =>
                              _selectedPlatform = ChartSource.appleMusic),
                        ),
                        const SizedBox(width: PrismSpacing.sm),
                        _buildFilterPill(
                          theme: theme,
                          label: 'Spotify',
                          accentColor: PrismColors.brandSpotify,
                          isSelected: _selectedPlatform == ChartSource.spotify,
                          onTap: () => setState(
                              () => _selectedPlatform = ChartSource.spotify),
                        ),
                        const SizedBox(width: PrismSpacing.sm),
                        _buildFilterPill(
                          theme: theme,
                          label: 'YouTube Music',
                          accentColor: PrismColors.brandYouTube,
                          isSelected: _selectedPlatform == ChartSource.youtube,
                          onTap: () => setState(
                              () => _selectedPlatform = ChartSource.youtube),
                        ),
                        const SizedBox(width: PrismSpacing.sm),
                        _buildFilterPill(
                          theme: theme,
                          label: 'Billboard',
                          accentColor: PrismColors.brandBillboard,
                          isSelected: _selectedPlatform == ChartSource.billboard,
                          onTap: () => setState(() =>
                              _selectedPlatform = ChartSource.billboard),
                        ),
                        const SizedBox(width: PrismSpacing.sm),
                        _buildFilterPill(
                          theme: theme,
                          label: 'Kworb WW',
                          accentColor: PrismColors.dataTeal,
                          isSelected: _selectedPlatform == ChartSource.kworb,
                          onTap: () => setState(() =>
                              _selectedPlatform = ChartSource.kworb),
                        ),
                      ],
                    ),
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
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              sliver: SliverGrid.builder(
                itemCount: filteredCharts.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  childAspectRatio: 0.82,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final chart = filteredCharts[index];
                  final platformAccent =
                      _getPlatformAccent(chart.source, theme.colorScheme);

                  return Semantics(
                    button: true,
                    label:
                        '${chart.name}, ${chartSourceLabel(chart.source)}, ${chart.description}',
                    child: BouncingTapWidget(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChartPage(chart: chart),
                        ),
                      ),
                      child: Material(
                        color: theme.colorScheme.surfaceContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(PrismRadius.lg),
                          side: BorderSide(color: spec.hairline),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(PrismSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PrismChartChip(type: chart.iconType, size: 38),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    chart.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: PrismSpacing.xs),
                                  Text(
                                    chart.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: PrismSpacing.sm),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.verified_rounded,
                                        size: PrismIconSize.xs - 3,
                                        color: platformAccent,
                                      ),
                                      const SizedBox(width: PrismSpacing.xs),
                                      Expanded(
                                        child: Text(
                                          chart.provenance ?? 'Curated chart',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: PrismText.tabular(
                                            theme.textTheme.labelSmall
                                                ?.copyWith(
                                              color: theme
                                                  .colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
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
