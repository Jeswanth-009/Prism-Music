import 'package:flutter/material.dart';

import '../../../core/services/stats_export_service.dart';
import '../../../domain/entities/listening_stats.dart';

/// Modal bottom sheet allowing users to share a listening summary card,
/// export a JSON data archive, or copy text to clipboard.
class StatsExportSheet extends StatefulWidget {
  final ListeningStats stats;
  final List<HistoryEntry> entries;
  final StatsExportService exportService;

  const StatsExportSheet({
    super.key,
    required this.stats,
    this.entries = const [],
    this.exportService = StatsExportService.instance,
  });

  static Future<void> show(
    BuildContext context, {
    required ListeningStats stats,
    List<HistoryEntry> entries = const [],
    StatsExportService exportService = StatsExportService.instance,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatsExportSheet(
        stats: stats,
        entries: entries,
        exportService: exportService,
      ),
    );
  }

  @override
  State<StatsExportSheet> createState() => _StatsExportSheetState();
}

class _StatsExportSheetState extends State<StatsExportSheet> {
  bool _isExporting = false;

  Future<void> _shareText() async {
    Navigator.of(context).pop();
    await widget.exportService.shareTextSummary(widget.stats);
  }

  Future<void> _exportJson() async {
    setState(() => _isExporting = true);
    final file = await widget.exportService.exportStatsJson(
      widget.stats,
      widget.entries,
    );
    if (!mounted) return;
    setState(() => _isExporting = false);
    Navigator.of(context).pop();

    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export listening stats.')),
      );
    }
  }

  Future<void> _copyText() async {
    Navigator.of(context).pop();
    await widget.exportService.copySummaryToClipboard(widget.stats);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Listening stats summary copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export Listening Stats',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Share your music summary or export a portable data backup',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_isExporting)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.share_rounded, size: 20),
                  ),
                  title: const Text('Share Summary Card'),
                  subtitle: const Text(
                    'Formatted stats overview with plays, hours & top songs',
                  ),
                  onTap: _shareText,
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.data_object_rounded, size: 20),
                  ),
                  title: const Text('Export JSON Archive (.json)'),
                  subtitle: Text(
                    'Raw data archive with metrics and ${widget.entries.length} recent plays',
                  ),
                  onTap: _exportJson,
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.copy_rounded, size: 20),
                  ),
                  title: const Text('Copy to Clipboard'),
                  subtitle: const Text('Quickly copy the text summary to paste anywhere'),
                  onTap: _copyText,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
