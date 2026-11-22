import 'package:flutter/material.dart';
import '../../../core/services/app_update_service.dart';
import '../../theme/prism_theme.dart';

/// Reimagined, elevated in-app update capsule for the Home screen.
/// Features live download progress, circular ring, laser gradient accent,
/// expandable changelog, and one-tap direct native installation.
class PrismUpdateCapsule extends StatefulWidget {
  final AppUpdateInfo updateInfo;
  final VoidCallback? onDismiss;

  const PrismUpdateCapsule({
    super.key,
    required this.updateInfo,
    this.onDismiss,
  });

  @override
  State<PrismUpdateCapsule> createState() => _PrismUpdateCapsuleState();
}

class _PrismUpdateCapsuleState extends State<PrismUpdateCapsule> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = AppUpdateService.instance;

    return ValueListenableBuilder<UpdateDownloadState>(
      valueListenable: service.downloadState,
      builder: (context, downloadState, _) {
        final isDownloading = downloadState.isDownloading;
        final isReady = downloadState.isReady;
        final isFailed = downloadState.isFailed;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF161922),
            borderRadius: BorderRadius.circular(PrismRadius.lg),
            border: Border.all(
              color: isReady
                  ? const Color(0xFF81C995).withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(PrismRadius.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  child: Row(
                    children: [
                      // Status visual (circular ring or badge)
                      _buildStatusIndicator(downloadState, theme),
                      const SizedBox(width: 14),

                      // Text info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    isDownloading
                                        ? 'Downloading Prism ${widget.updateInfo.latestVersion}'
                                        : (isReady
                                            ? 'Prism ${widget.updateInfo.latestVersion} Ready'
                                            : 'Update Available'),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!isDownloading && !isReady) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'v${widget.updateInfo.latestVersion}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isDownloading
                                  ? '${downloadState.receivedMb} / ${downloadState.totalMb} MB (${downloadState.percent}%)'
                                  : (isReady
                                      ? 'Tap install to finish updating'
                                      : (isFailed
                                          ? (downloadState.errorMessage ?? 'Download failed. Tap to retry.')
                                          : 'New features, lyrics & performance updates')),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isFailed
                                    ? Colors.redAccent.withValues(alpha: 0.8)
                                    : (isReady
                                        ? const Color(0xFF81C995)
                                        : Colors.white.withValues(alpha: 0.6)),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Action Button
                      if (isDownloading)
                        IconButton(
                          tooltip: 'Cancel download',
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: Colors.white.withValues(alpha: 0.6),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => service.cancelDownload(),
                        )
                      else if (isReady)
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF81C995),
                            foregroundColor: const Color(0xFF13151A),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(PrismRadius.md),
                            ),
                          ),
                          onPressed: () {
                            if (downloadState.localApkPath != null) {
                              service.installDownloadedApk(downloadState.localApkPath!);
                            }
                          },
                          child: const Text(
                            'Install',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(PrismRadius.md),
                                ),
                              ),
                              onPressed: () => service.startDownload(widget.updateInfo),
                              child: const Text(
                                'Update',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Dismiss',
                              icon: const Icon(Icons.close_rounded, size: 16),
                              color: Colors.white.withValues(alpha: 0.4),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              onPressed: () {
                                service.dismissVersion(widget.updateInfo.latestVersion);
                                widget.onDismiss?.call();
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Expandable changelog highlight
                if (!isDownloading && widget.updateInfo.changelog.isNotEmpty) ...[
                  InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            _expanded ? 'Hide details' : "What's new",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_expanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.updateInfo.changelog,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                            height: 1.4,
                            fontSize: 11,
                          ),
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],

                // Laser gradient hairline / progress bar
                if (isDownloading)
                  LinearProgressIndicator(
                    value: downloadState.progress > 0 ? downloadState.progress : null,
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  )
                else
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isReady
                            ? [
                                const Color(0xFF81C995).withValues(alpha: 0.1),
                                const Color(0xFF81C995),
                                const Color(0xFF81C995).withValues(alpha: 0.1),
                              ]
                            : [
                                Colors.transparent,
                                theme.colorScheme.primary.withValues(alpha: 0.4),
                                Colors.transparent,
                              ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusIndicator(UpdateDownloadState state, ThemeData theme) {
    if (state.isDownloading) {
      return SizedBox(
        width: 38,
        height: 38,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: state.progress > 0 ? state.progress : null,
              strokeWidth: 3,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
            Text(
              '${state.percent}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (state.isReady) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF81C995).withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_circle_outline_rounded,
          color: Color(0xFF81C995),
          size: 22,
        ),
      );
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.system_update_rounded,
        color: theme.colorScheme.primary,
        size: 20,
      ),
    );
  }
}
