import 'package:flutter/material.dart';

import '../../../core/services/diagnostics_service.dart';
import '../../theme/prism_theme.dart';
import '../prism/prism_sheet.dart';

/// Shows an interactive diagnostics breakdown modal with one-tap copy.
void showPrismDiagnosticsSheet(
  BuildContext context, {
  Map<String, dynamic>? initialData,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return DiagnosticsSheetContent(initialData: initialData);
    },
  );
}

class DiagnosticsSheetContent extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const DiagnosticsSheetContent({super.key, this.initialData});

  @override
  State<DiagnosticsSheetContent> createState() => _DiagnosticsSheetContentState();
}

class _DiagnosticsSheetContentState extends State<DiagnosticsSheetContent> {
  bool _loading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _data = widget.initialData;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final data = await DiagnosticsService.instance.collectDiagnostics();
    if (mounted) {
      setState(() {
        _data = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading || _data == null) {
      return const SafeArea(
        child: SizedBox(
          height: 250,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final app = _data!['app'] as Map<String, dynamic>;
    final platform = _data!['platform'] as Map<String, dynamic>;
    final audio = _data!['audioSettings'] as Map<String, dynamic>;
    final storage = _data!['storage'] as Map<String, dynamic>;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.terminal_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  'System Diagnostics',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(PrismRadius.md),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _diagRow('App Version', '${app['version']}+${app['buildNumber']} (${app['buildMode']})'),
                  _diagRow('Package', '${app['packageName']}'),
                  _diagRow('Platform', '${platform['os']} (${platform['osVersion']})'),
                  _diagRow('Dart Runtime', '${platform['dartVersion']}'),
                  _diagRow('Audio Quality', '${audio['quality']}'),
                  _diagRow('Playback Features', 'FastStart: ${audio['fastStart'] == true ? "On" : "Off"}, AutoPlay: ${audio['autoPlay'] == true ? "On" : "Off"}'),
                  _diagRow('Equalizer Preset', '${audio['equalizerPreset']}'),
                  _diagRow('Cache Usage', '${storage['cacheUsage']}'),
                  _diagRow('Latest Backup', '${storage['latestBackup']} (${storage['backupItems']} items)'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () async {
                  await DiagnosticsService.instance.copyToClipboard(context);
                  if (context.mounted) {
                    showPrismToast(context, 'Diagnostics copied to clipboard');
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy diagnostics to clipboard'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _diagRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
