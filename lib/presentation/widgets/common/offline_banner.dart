import 'package:flutter/material.dart';

import '../../../core/services/offline_mode_service.dart';
import '../../theme/prism_theme.dart';

/// A sleek, animated banner indicating that offline mode is active
/// (either through network loss or manual offline toggle).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    this.offlineModeService,
    this.onTap,
  });

  final OfflineModeService? offlineModeService;
  final VoidCallback? onTap;

  OfflineModeService get _service =>
      offlineModeService ?? OfflineModeService.instance;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _service.isOfflineNotifier,
      builder: (context, isOffline, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;

        return AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: isOffline
              ? Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(PrismRadius.md),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.wifi_off_rounded,
                            size: 16,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Offline Mode • Playing downloaded tracks',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (onTap != null) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 11,
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}
