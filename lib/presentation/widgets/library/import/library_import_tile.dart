import 'package:flutter/material.dart';

import '../../../theme/prism_theme.dart';

/// Full-width entry pointing at the Spotify/YouTube import flow with progress indicator.
class LibraryImportTile extends StatelessWidget {
  const LibraryImportTile({
    super.key,
    required this.onTap,
    this.isImporting = false,
    this.importProgress,
    this.currentTrack,
    this.totalTracks,
    this.onCancel,
  });

  final VoidCallback onTap;
  final bool isImporting;
  final double? importProgress;
  final int? currentTrack;
  final int? totalTracks;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressPercent =
        importProgress != null ? (importProgress! * 100).toInt() : null;

    final subtitle = isImporting
        ? (totalTracks != null && totalTracks! > 0
            ? 'Matching track ${currentTrack ?? 0} of $totalTracks ($progressPercent%)'
            : 'Extracting tracks and matching songs…')
        : 'Bring a Spotify or YouTube playlist into Prism';

    return Material(
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        side: BorderSide(color: context.prismSpec.hairline),
      ),
      child: InkWell(
        onTap: isImporting ? null : onTap,
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (isImporting)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    value: importProgress != null && importProgress! > 0
                        ? importProgress
                        : null,
                    strokeWidth: 2.5,
                    color: theme.colorScheme.primary,
                  ),
                )
              else
                Icon(Icons.download_for_offline_outlined,
                    color: theme.colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isImporting ? 'Import in progress…' : 'Import playlist',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isImporting && onCancel != null)
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: theme.colorScheme.error,
                  ),
                  child: const Text('Cancel'),
                )
              else if (!isImporting)
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
