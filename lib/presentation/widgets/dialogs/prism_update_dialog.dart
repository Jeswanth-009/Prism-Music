import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/app_update_service.dart';
import '../../theme/prism_theme.dart';
import '../prism/prism_sheet.dart';

/// A modern, glassmorphic Prism-styled dialog notifying the user of an app update.
class PrismUpdateDialog extends StatelessWidget {
  const PrismUpdateDialog({
    super.key,
    required this.info,
    this.onDismiss,
  });

  final AppUpdateInfo info;
  final VoidCallback? onDismiss;

  /// Shows the dialog safely.
  static Future<void> show(BuildContext context, AppUpdateInfo info) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => PrismUpdateDialog(info: info),
    );
  }

  Future<void> _handleUpdate(BuildContext context) async {
    final targetUrl = info.apkDownloadUrl ?? info.releaseUrl;
    final uri = Uri.parse(targetUrl);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        showPrismToast(context, 'Could not open the download link');
      }
    } catch (_) {
      if (context.mounted) {
        showPrismToast(context, 'Could not open the download link');
      }
    }
  }

  void _handleDismiss(BuildContext context) {
    AppUpdateService.instance.dismissVersion(info.latestVersion);
    onDismiss?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = Theme.of(context).extension<PrismSpec>();
    final primary = theme.colorScheme.primary;
    final accent = spec?.accent ?? primary;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(PrismRadius.lg),
            border: Border.all(
              color: primary.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: primary.withValues(alpha: 0.12),
                blurRadius: 24,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top header icon + title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primary,
                            accent,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Update Available',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'A new release of Prism Music is ready',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Version comparison pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      _VersionChip(
                        label: 'Current',
                        version: 'v${info.currentVersion}',
                        isNew: false,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ),
                      _VersionChip(
                        label: 'New',
                        version: 'v${info.latestVersion}',
                        isNew: true,
                        buildNumber: info.latestBuildNumber > 0
                            ? '+${info.latestBuildNumber}'
                            : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Changelog title
                Text(
                  "What's New",
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),

                // Scrollable changelog view
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        info.changelog,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.45,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.88),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _handleDismiss(context),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Later'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _handleUpdate(context),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Update Now'),
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VersionChip extends StatelessWidget {
  const _VersionChip({
    required this.label,
    required this.version,
    required this.isNew,
    this.buildNumber,
  });

  final String label;
  final String version;
  final bool isNew;
  final String? buildNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isNew
                    ? primary.withValues(alpha: 0.16)
                    : theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isNew
                      ? primary.withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
              ),
              child: Text(
                '$version${buildNumber ?? ''}',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isNew ? primary : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
