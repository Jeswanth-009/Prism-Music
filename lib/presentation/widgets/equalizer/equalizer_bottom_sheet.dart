import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/services/equalizer_service.dart';
import '../../../core/models/reverb_preset.dart';

/// Modern equalizer bottom sheet with presets and manual controls
class EqualizerBottomSheet extends StatefulWidget {
  final EqualizerService equalizerService;

  const EqualizerBottomSheet({
    super.key,
    required this.equalizerService,
  });

  @override
  State<EqualizerBottomSheet> createState() =>
      _EqualizerBottomSheetState();
}

class _EqualizerBottomSheetState extends State<EqualizerBottomSheet>
    with TickerProviderStateMixin {
  late String _selectedPreset;
  late TabController _tabController;
  late AnimationController _animController;

  // Manual control values
  late double _bassBoostLevel;
  late bool _bassBoostEnabled;
  late double _trebleLevel;
  late ReverbPreset _selectedReverb;

  @override
  void initState() {
    super.initState();
    _selectedPreset = widget.equalizerService.currentPreset;
    _tabController = TabController(length: 2, vsync: this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();

    _bassBoostLevel = widget.equalizerService.bassBoostLevel;
    _bassBoostEnabled = widget.equalizerService.isBassBoostEnabled;
    _trebleLevel = widget.equalizerService.trebleLevel;
    _selectedReverb = widget.equalizerService.reverbPreset;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _animController,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _animController,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant
                    .withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Icon(LucideIcons.audioLines,
                      color: theme.colorScheme.primary, size: 26),
                  const SizedBox(width: 12),
                  Text('Equalizer',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  ShadIconButton.ghost(
                    icon: Icon(LucideIcons.rotateCcw,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant),
                    onPressed: () async {
                      await widget.equalizerService.reset();
                      setState(() {
                        _selectedPreset = 'Normal';
                        _bassBoostLevel = 0.0;
                        _bassBoostEnabled = false;
                        _trebleLevel = 0.5;
                        _selectedReverb = ReverbPreset.none;
                      });
                    },
                  ),
                ],
              ),
            ),

            // Tabs header
            TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor:
                  theme.colorScheme.onSurfaceVariant,
              indicatorColor: theme.colorScheme.primary,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'PRESETS'),
                Tab(text: 'MANUAL'),
              ],
            ),

            // Tab views
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPresetsTab(theme),
                  _buildManualTab(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Presets Tab ──────────────────────────────────────────────────────

  Widget _buildPresetsTab(ThemeData theme) {
    final presets = EqualizerService.presets.keys.toList();

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: presets.length,
          itemBuilder: (context, index) {
            final presetName = presets[index];
            final isSelected = _selectedPreset == presetName;
            final preset = EqualizerService.presets[presetName]!;

            return GestureDetector(
              onTap: () async {
                setState(() {
                  _selectedPreset = presetName;
                  _bassBoostLevel = preset.bassBoost;
                  _bassBoostEnabled = preset.bassBoost > 0.0;
                  _trebleLevel = preset.treble;
                  _selectedReverb = preset.reverb;
                });
                await widget.equalizerService
                    .applyPreset(presetName);
              },
              child: ShadCard(
              padding: const EdgeInsets.all(14),
              child: Container(
                decoration: isSelected
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: theme.colorScheme.primaryContainer
                            .withOpacity(0.3),
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getPresetIcon(presetName),
                          size: 20,
                          color: isSelected
                              ? theme
                                  .colorScheme.onPrimaryContainer
                              : theme
                                  .colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            presetName,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isSelected
                                  ? theme.colorScheme
                                      .onPrimaryContainer
                                  : theme
                                      .colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        _buildFrequencyBar(
                            context, preset.bassBoost, isSelected),
                        const SizedBox(width: 3),
                        _buildFrequencyBar(
                            context,
                            (preset.bassBoost + preset.treble) / 2,
                            isSelected),
                        const SizedBox(width: 3),
                        _buildFrequencyBar(
                            context, preset.treble, isSelected),
                        const SizedBox(width: 3),
                        _buildFrequencyBar(context,
                            preset.treble * 0.9, isSelected),
                        const SizedBox(width: 3),
                        _buildFrequencyBar(context,
                            preset.bassBoost * 0.7, isSelected),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            );
          },
        ),
      ],
    );
  }

  // ── Manual Tab ──────────────────────────────────────────────────────

  Widget _buildManualTab(ThemeData theme) {
    return ListView(
      shrinkWrap: true,
      padding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        // Bass Boost
        ShadCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.speaker,
                      color: theme.colorScheme.primary, size: 22),
                  const SizedBox(width: 12),
                  Text('Bass Boost',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  ShadSwitch(
                    value: _bassBoostEnabled,
                    onChanged: (value) async {
                      setState(() => _bassBoostEnabled = value);
                      await widget.equalizerService
                          .setBassBoost(_bassBoostLevel, value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ShadSlider(
                      initialValue: _bassBoostLevel,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      onChanged: _bassBoostEnabled
                          ? (value) {
                              setState(
                                  () => _bassBoostLevel = value);
                            }
                          : null,
                      onChangeEnd: _bassBoostEnabled
                          ? (value) async {
                              await widget.equalizerService
                                  .setBassBoost(value, true);
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 40,
                    child: Text(
                      _bassBoostLevel.toStringAsFixed(1),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: [
                          const FontFeature.tabularFigures()
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Enhance low-frequency audio (0.0 - 1.0)',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Treble
        ShadCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.ear,
                      color: theme.colorScheme.primary, size: 22),
                  const SizedBox(width: 12),
                  Text('Treble',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ShadSlider(
                      initialValue: _trebleLevel,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      onChanged: (value) {
                        setState(() => _trebleLevel = value);
                      },
                      onChangeEnd: (value) async {
                        await widget.equalizerService
                            .setTreble(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 40,
                    child: Text(
                      _trebleLevel.toStringAsFixed(1),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: [
                          const FontFeature.tabularFigures()
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('High-frequency adjustment (not yet implemented)',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Reverb
        ShadCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.waves,
                      color: theme.colorScheme.primary, size: 22),
                  const SizedBox(width: 12),
                  Text('Reverb',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ReverbPreset.values.map((preset) {
                  final isSelected = _selectedReverb == preset;
                  return ShadButton.outline(
                    onPressed: () async {
                      setState(() => _selectedReverb = preset);
                      await widget.equalizerService
                          .setReverb(preset);
                    },
                    size: ShadButtonSize.sm,
                    backgroundColor: isSelected
                        ? theme.colorScheme.primaryContainer
                        : null,
                    foregroundColor: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : null,
                    child: Text(preset.displayName),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text('Apply depth effect to audio',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  IconData _getPresetIcon(String preset) {
    switch (preset) {
      case 'Bass Boost':
        return LucideIcons.speaker;
      case 'Treble Boost':
        return LucideIcons.ear;
      case 'Rock':
        return LucideIcons.guitar;
      case 'Pop':
        return LucideIcons.radio;
      case 'Classical':
        return LucideIcons.music;
      case 'Jazz':
        return LucideIcons.disc;
      case 'Electronic':
        return LucideIcons.zap;
      default:
        return LucideIcons.audioLines;
    }
  }

  Widget _buildFrequencyBar(
      BuildContext context, double value, bool isSelected) {
    final theme = Theme.of(context);
    final height = (10 + (value * 25).clamp(0, 25)).toDouble();

    return Expanded(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.7)
              : theme.colorScheme.onSurfaceVariant
                  .withOpacity(0.35),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

