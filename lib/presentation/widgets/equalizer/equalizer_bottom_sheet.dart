import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/services/equalizer_service.dart';
import '../../../core/models/reverb_preset.dart';
import '../../theme/prism_theme.dart';
import '../../../domain/entities/song.dart';

/// Equalizer bottom sheet with presets and manual controls.
class EqualizerBottomSheet extends StatefulWidget {
  final EqualizerService equalizerService;
  final Song? currentSong;

  const EqualizerBottomSheet({
    super.key,
    required this.equalizerService,
    this.currentSong,
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
  bool _hasSongCustomEq = false;

  void _syncSongEqIfEnabled() {
    if (_hasSongCustomEq && widget.currentSong != null) {
      widget.equalizerService.saveCurrentForSong(widget.currentSong!.playableId);
    }
  }

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
    _hasSongCustomEq = widget.currentSong != null &&
        widget.equalizerService.hasSongEqualizer(widget.currentSong!.playableId);
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

              if (!widget.equalizerService.isSupported)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.equalizerService.audioSessionId == 0
                              ? 'Native effects activate once playback begins on Android.'
                              : 'Native audio effects are unsupported on this session.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
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

  Future<void> _showSavePresetDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Save Custom Preset'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Preset Name',
            hintText: 'e.g., My Acoustic',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(dialogCtx).pop(text);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name != null && name.isNotEmpty) {
      await widget.equalizerService.saveCustomPreset(name);
      _syncSongEqIfEnabled();
      setState(() {
        _selectedPreset = name;
      });
    }
  }

  // ── Presets Tab ──────────────────────────────────────────────────────

  Widget _buildPresetsTab(ThemeData theme) {
    final allPresets = widget.equalizerService.allPresets;
    final presetNames = allPresets.keys.toList();

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.currentSong != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SwitchListTile.adaptive(
              title: Text(
                'Remember EQ for this song',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                widget.currentSong!.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              secondary: Icon(Icons.music_note_rounded, color: theme.colorScheme.primary),
              value: _hasSongCustomEq,
              onChanged: (enabled) async {
                setState(() => _hasSongCustomEq = enabled);
                if (enabled) {
                  await widget.equalizerService.saveCurrentForSong(widget.currentSong!.playableId);
                } else {
                  await widget.equalizerService.clearForSong(widget.currentSong!.playableId);
                }
              },
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Presets (${presetNames.length})',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: const Text('Save Preset'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _showSavePresetDialog(context),
              ),
            ],
          ),
        ),
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
          itemCount: presetNames.length,
          itemBuilder: (context, index) {
            final presetName = presetNames[index];
            final isSelected = _selectedPreset == presetName;
            final preset = allPresets[presetName]!;

            return Material(
              color: isSelected
                  ? context.prismSpec.accentSoft
                  : theme.colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PrismRadius.md),
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : context.prismSpec.hairline,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(PrismRadius.md),
                onTap: () async {
                  setState(() {
                    _selectedPreset = presetName;
                    _bassBoostLevel = preset.bassBoost;
                    _bassBoostEnabled = preset.bassBoost > 0.0;
                    _trebleLevel = preset.treble;
                    _selectedReverb = preset.reverb;
                  });
                  await widget.equalizerService.applyPreset(presetName);
                  _syncSongEqIfEnabled();
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getPresetIcon(presetName),
                            size: PrismIconSize.sm + 2,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              presetName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (preset.isCustom)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () async {
                                await widget.equalizerService.deleteCustomPreset(presetName);
                                setState(() {
                                  _selectedPreset = widget.equalizerService.currentPreset;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 26,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _EqCurvePainter(
                            gains: preset.bandGains,
                            bassBoost: preset.bassBoost,
                            treble: preset.treble,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
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
        // 10-Band Graphic Equalizer
        _ManualSection(
          icon: Icons.graphic_eq_rounded,
          title: '10-Band Graphic Equalizer',
          trailing: TextButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Flat'),
            onPressed: () async {
              await widget.equalizerService.setAllBandGains(List.filled(10, 0.0));
              setState(() {});
              _syncSongEqIfEnabled();
            },
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 180,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(10, (index) {
                    final label = EqualizerService.bandLabels[index];
                    final gain = widget.equalizerService.bandGains[index];

                    return Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${gain > 0 ? "+" : ""}${gain.toStringAsFixed(0)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: gain != 0
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 10),
                                ),
                                child: Slider(
                                  value: gain,
                                  min: -12.0,
                                  max: 12.0,
                                  onChanged: (val) {
                                    setState(() {
                                      widget.equalizerService
                                          .setBandGain(index, val);
                                    });
                                  },
                                  onChangeEnd: (_) => _syncSongEqIfEnabled(),
                                ),
                              ),
                            ),
                          ),
                          Text(
                            label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 8,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  '-12 dB to +12 dB biquad peaking filters',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

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
              _syncSongEqIfEnabled();
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
                    _syncSongEqIfEnabled();
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
              _syncSongEqIfEnabled();
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
                      _syncSongEqIfEnabled();
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


/// Smooth 10-band gain curve for a preset preview. Falls back to a bass/
/// treble-derived arc when the preset carries no per-band gains.
class _EqCurvePainter extends CustomPainter {
  const _EqCurvePainter({
    required this.gains,
    required this.bassBoost,
    required this.treble,
    required this.color,
  });

  final List<double>? gains;
  final double bassBoost;
  final double treble;
  final Color color;

  static const _bandCount = 10;

  List<double> get _values {
    if (gains != null && gains!.length == _bandCount) {
      return gains!;
    }
    // Derived shape: bass hump, mids flat, treble shoulder.
    return [
      bassBoost,
      bassBoost * 0.85,
      bassBoost * 0.55,
      (bassBoost + treble) / 2 * 0.4,
      0,
      0,
      treble * 0.5,
      treble * 0.8,
      treble,
      treble * 0.9,
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final values = _values;
    final n = values.length;
    final peak = values.fold(0.001, math.max);
    final step = size.width / (n - 1);
    final points = <Offset>[
      for (var i = 0; i < n; i++)
        Offset(
          i * step,
          size.height - 2 - (values[i] / peak) * (size.height - 6),
        ),
    ];

    final fillPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final midX = (a.dx + b.dx) / 2;
      fillPath.quadraticBezierTo(a.dx, a.dy, midX, (a.dy + b.dy) / 2);
    }
    fillPath
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final midX = (a.dx + b.dx) / 2;
      linePath.quadraticBezierTo(a.dx, a.dy, midX, (a.dy + b.dy) / 2);
    }
    linePath.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_EqCurvePainter oldDelegate) =>
      oldDelegate.gains != gains ||
      oldDelegate.bassBoost != bassBoost ||
      oldDelegate.treble != treble ||
      oldDelegate.color != color;
}
