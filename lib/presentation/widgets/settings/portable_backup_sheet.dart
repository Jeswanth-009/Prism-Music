import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/local_backup_service.dart';
import '../../../core/utils/formatters.dart';
import '../../blocs/library/library_bloc.dart';
import '../../blocs/library/library_event.dart';
import '../prism/prism_dialog.dart';
import '../prism/prism_sheet.dart';

/// Shows an interactive bottom sheet for managing portable backups.
void showPortableBackupSheet(
  BuildContext context, {
  VoidCallback? onBackupChanged,
  BackupSnapshotInfo? initialInfo,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return PortableBackupSheetContent(
        onBackupChanged: onBackupChanged,
        initialInfo: initialInfo,
      );
    },
  );
}

class PortableBackupSheetContent extends StatefulWidget {
  final VoidCallback? onBackupChanged;
  final BackupSnapshotInfo? initialInfo;
  final bool? initiallyLoading;

  const PortableBackupSheetContent({
    super.key,
    this.onBackupChanged,
    this.initialInfo,
    this.initiallyLoading,
  });

  @override
  State<PortableBackupSheetContent> createState() =>
      _PortableBackupSheetContentState();
}

class _PortableBackupSheetContentState extends State<PortableBackupSheetContent> {
  bool _loading = true;
  bool _exporting = false;
  BackupSnapshotInfo? _latestInfo;

  final TextEditingController _pathController = TextEditingController();
  bool _inspecting = false;
  BackupSnapshotInfo? _inspectedFileInfo;
  String? _inspectError;

  @override
  void initState() {
    super.initState();
    if (widget.initialInfo != null || widget.initiallyLoading == false) {
      _latestInfo = widget.initialInfo;
      _loading = false;
    } else {
      _loadBackupInfo();
    }
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _loadBackupInfo() async {
    final info = await LocalBackupService.instance.getLatestBackupInfo();
    if (mounted) {
      setState(() {
        _latestInfo = info;
        _loading = false;
      });
    }
  }

  Future<void> _exportBackup() async {
    setState(() => _exporting = true);
    try {
      final file = await LocalBackupService.instance.exportPortableBackup();
      if (!mounted) return;
      if (file == null) {
        showPrismToast(context, 'Unable to create backup for export');
        return;
      }
      final dateStr = DateFormat('MMM d, yyyy · h:mm a').format(DateTime.now());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Prism Music Portable Backup',
        text: 'Prism Music library backup ($dateStr)',
      );
      if (mounted) {
        showPrismToast(context, 'Backup exported successfully');
        await _loadBackupInfo();
        widget.onBackupChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        showPrismToast(context, 'Export failed: $e');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _inspectPath() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      setState(() {
        _inspectError = 'Please enter a valid file path';
        _inspectedFileInfo = null;
      });
      return;
    }

    setState(() {
      _inspecting = true;
      _inspectError = null;
    });

    final file = File(path);
    final info = await LocalBackupService.instance.inspectBackupFile(file);

    if (mounted) {
      setState(() {
        _inspecting = false;
        if (info == null) {
          _inspectError =
              'File is not a valid Prism backup or exceeds size limits';
          _inspectedFileInfo = null;
        } else {
          _inspectError = null;
          _inspectedFileInfo = info;
        }
      });
    }
  }

  Future<void> _restore({required File file, required bool isMerge}) async {
    final res = isMerge
        ? await LocalBackupService.instance.mergeBackupFromFile(file)
        : await LocalBackupService.instance.importBackupFromFile(file, overwrite: true);

    if (!mounted) return;

    if (res.isSuccess) {
      context.read<LibraryBloc>().add(const LoadLibraryEvent());
      final mode = isMerge ? 'Merged' : 'Restored';
      showPrismToast(context, '$mode ${res.totalRestored} items into library');
      await _loadBackupInfo();
      widget.onBackupChanged?.call();
    } else {
      showPrismToast(context, 'Restore failed: ${res.error ?? 'unknown error'}');
    }
  }

  void _confirmDelete() {
    showPrismConfirmDialog(
      context: context,
      title: 'Delete All Backups',
      message:
          'Are you sure you want to delete all stored backup snapshot files from this device? This action cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
      onConfirm: () async {
        final count = await LocalBackupService.instance.deleteBackupFiles();
        if (!mounted) return;
        showPrismToast(
          context,
          count > 0 ? 'Deleted $count backup files' : 'No backup files found',
        );
        await _loadBackupInfo();
        widget.onBackupChanged?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            mediaQuery.viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.settings_backup_restore_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Portable Library Backup',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Offline snapshot and identity reconciliation',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSnapshotCard(theme),
                        const SizedBox(height: 16),
                        _buildExportCard(theme),
                        const SizedBox(height: 16),
                        _buildFileRestoreCard(theme),
                        const SizedBox(height: 16),
                        if (_latestInfo != null)
                          Center(
                            child: TextButton.icon(
                              onPressed: _confirmDelete,
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              label: const Text('Delete Local Backups'),
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSnapshotCard(ThemeData theme) {
    if (_latestInfo == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Latest Device Backup',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'No automatic backup found yet. Create a portable backup below to safeguard your playlists, likes, and listening history.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final info = _latestInfo!;
    final dateStr = DateFormat('MMM d, yyyy · h:mm a').format(info.timestamp);
    final sizeStr = Formatters.formatBytes(info.fileSizeBytes);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Latest Device Snapshot',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${info.totalItems} items · $sizeStr',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Created $dateStr',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildCountChip(theme, 'Likes', info.boxCounts['liked_songs'] ?? 0),
              _buildCountChip(theme, 'Playlists', info.boxCounts['playlists'] ?? 0),
              _buildCountChip(theme, 'Plays', info.boxCounts['listening_history'] ?? 0),
              _buildCountChip(theme, 'Downloads', info.boxCounts['downloads'] ?? 0),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _restore(file: File(info.filePath), isMerge: true),
                  icon: const Icon(Icons.merge_type_rounded, size: 16),
                  label: const Text('Merge with Library'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _restore(file: File(info.filePath), isMerge: false),
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: const Text('Clean Restore'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountChip(ThemeData theme, String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        '$count $label',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildExportCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.file_upload_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Export Portable Snapshot',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Export a portable, versioned JSON backup file to share or save to external storage, cloud drives, or other devices.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _exporting ? null : _exportBackup,
              icon: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_rounded, size: 18),
              label: Text(_exporting ? 'Generating Backup…' : 'Export & Share Backup'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileRestoreCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.file_download_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Import / Restore from File',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Inspect and restore from a previously exported Prism backup file.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pathController,
                  decoration: const InputDecoration(
                    hintText: '/path/to/prism_backup.json',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _inspecting ? null : _inspectPath,
                child: _inspecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Inspect'),
              ),
            ],
          ),
          if (_inspectError != null) ...[
            const SizedBox(height: 8),
            Text(
              _inspectError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (_inspectedFileInfo != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detected Valid Backup Snapshot',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_inspectedFileInfo!.totalItems} total items (${Formatters.formatBytes(_inspectedFileInfo!.fileSizeBytes)})\n'
                    'Date: ${DateFormat('MMM d, yyyy · h:mm a').format(_inspectedFileInfo!.timestamp)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _restore(
                            file: File(_inspectedFileInfo!.filePath),
                            isMerge: true,
                          ),
                          icon: const Icon(Icons.merge_type_rounded, size: 16),
                          label: const Text('Merge with Library'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => _restore(
                            file: File(_inspectedFileInfo!.filePath),
                            isMerge: false,
                          ),
                          icon: const Icon(Icons.restore_rounded, size: 16),
                          label: const Text('Clean Replace'),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
