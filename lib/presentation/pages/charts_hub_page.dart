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
      ChartSource.appleMusic => const Color(0xFFFA2D48), // Apple Music pink-red
      ChartSource.spotify => const Color(0xFF1DB954), // Spotify Green
      ChartSource.youtube => const Color(0xFFFF0033), // YouTube Red
      ChartSource.billboard => const Color(0xFFD4AF37), // Billboard Gold
      ChartSource.kworb => const Color(0xFF00ADB5), // Kworb Cyan
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Streaming Charts',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.9,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'What the world is playing across Apple Music, Spotify, YouTube & Billboard.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      InkWell(
                        onTap: () => _showCountryPicker(context),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: spec.accentSoft,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: spec.hairline),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _settings.selectedCountry.flag,
                                style: theme.textTheme.labelLarge,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _settings.selectedCountry.name,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
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
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          theme: theme,
                          label: 'Apple Music',
                          accentColor: const Color(0xFFFA2D48),
                          isSelected: _selectedPlatform == ChartSource.appleMusic,
                          onTap: () => setState(() =>
                              _selectedPlatform = ChartSource.appleMusic),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          theme: theme,
                          label: 'Spotify',
                          accentColor: const Color(0xFF1DB954),
                          isSelected: _selectedPlatform == ChartSource.spotify,
                          onTap: () => setState(
                              () => _selectedPlatform = ChartSource.spotify),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          theme: theme,
                          label: 'YouTube Music',
                          accentColor: const Color(0xFFFF0033),
                          isSelected: _selectedPlatform == ChartSource.youtube,
                          onTap: () => setState(
                              () => _selectedPlatform = ChartSource.youtube),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          theme: theme,
                          label: 'Billboard',
                          accentColor: const Color(0xFFD4AF37),
                          isSelected: _selectedPlatform == ChartSource.billboard,
                          onTap: () => setState(() =>
                              _selectedPlatform = ChartSource.billboard),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          theme: theme,
                          label: 'Kworb WW',
                          accentColor: const Color(0xFF00ADB5),
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
                          side: BorderSide(
                            color: platformAccent.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  PrismChartChip(type: chart.iconType, size: 38),
                                  const Spacer(),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: platformAccent.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(
                                            PrismRadius.pill),
                                      ),
                                      child: Text(
                                        chartSourceLabel(chart.source),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: platformAccent,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    chart.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    chart.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.verified_rounded,
                                        size: 11,
                                        color: platformAccent,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          chart.provenance ?? 'Curated chart',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            fontSize: 10,
                                            color: theme.colorScheme
                                                .onSurfaceVariant,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                          const SizedBox(height: 12),
                          Text(
                            'Select Music Region',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Search countries...',
                              prefixIcon: const Icon(Icons.search_rounded, size: 20),
                              isDense: true,
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerHigh,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
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
                            leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                            title: Text(
                              c.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? theme.colorScheme.primary : null,
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.18)
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(PrismRadius.pill),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? activeColor
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
