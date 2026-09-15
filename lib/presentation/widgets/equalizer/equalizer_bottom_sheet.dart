import 'package:flutter/material.dart';

import '../../../core/services/equalizer_service.dart';
import '../../../core/models/reverb_preset.dart';

/// Equalizer bottom sheet with presets and manual controls.
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
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.equalizer_rounded,
                        color: theme.colorScheme.primary, size: 24),
                    const SizedBox(width: 12),
                    Text('Equalizer',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Reset',
                      icon: Icon(Icons.restart_alt_rounded,
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

            return Material(
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  setState(() {
                    _selectedPreset = presetName;
                    _bassBoostLevel = preset.bassBoost;
                    _bassBoostEnabled = preset.bassBoost > 0.0;
                    _trebleLevel = preset.treble;
                    _selectedReverb = preset.reverb;
                  });
                  await widget.equalizerService.applyPreset(presetName);
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getPresetIcon(presetName),
                            size: 18,
                            color: isSelected
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              presetName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isSelected
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
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
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Bass Boost
        _ManualSection(
          icon: Icons.speaker_rounded,
          title: 'Bass Boost',
          trailing: Switch.adaptive(
            value: _bassBoostEnabled,
            onChanged: (value) async {
              setState(() => _bassBoostEnabled = value);
              await widget.equalizerService
                  .setBassBoost(_bassBoostLevel, value);
            },
          ),
          child: _SliderRow(
            value: _bassBoostLevel,
            enabled: _bassBoostEnabled,
            onChanged: _bassBoostEnabled
                ? (value) => setState(() => _bassBoostLevel = value)
                : null,
            onChangeEnd: _bassBoostEnabled
                ? (value) async {
                    await widget.equalizerService.setBassBoost(value, true);
                  }
                : null,
          ),
        ),

        const SizedBox(height: 14),

        // Treble
        _ManualSection(
          icon: Icons.hearing_rounded,
          title: 'Treble',
          child: _SliderRow(
            value: _trebleLevel,
            enabled: true,
            onChanged: (value) => setState(() => _trebleLevel = value),
            onChangeEnd: (value) async {
              await widget.equalizerService.setTreble(value);
            },
          ),
        ),

        const SizedBox(height: 14),

        // Reverb
        _ManualSection(
          icon: Icons.waves_rounded,
          title: 'Reverb',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ReverbPreset.values.map((preset) {
                  final isSelected = _selectedReverb == preset;
                  return ChoiceChip(
                    label: Text(preset.displayName),
                    selected: isSelected,
                    onSelected: (_) async {
                      setState(() => _selectedReverb = preset);
                      await widget.equalizerService.setReverb(preset);
                    },
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
        return Icons.speaker_rounded;
      case 'Treble Boost':
        return Icons.hearing_rounded;
      case 'Rock':
        return Icons.music_note_rounded;
      case 'Pop':
        return Icons.radio_rounded;
      case 'Classical':
        return Icons.piano_rounded;
      case 'Jazz':
        return Icons.album_rounded;
      case 'Electronic':
        return Icons.bolt_rounded;
      default:
        return Icons.equalizer_rounded;
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
              ? theme.colorScheme.primary.withValues(alpha: 0.7)
              : theme.colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _ManualSection extends StatelessWidget {
  const _ManualSection({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              Text(title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final bool enabled;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: value.clamp(0.0, 1.0),
            min: 0.0,
            max: 1.0,
            divisions: 20,
            onChanged: enabled ? onChanged : null,
            onChangeEnd: enabled ? onChangeEnd : null,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(1),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
