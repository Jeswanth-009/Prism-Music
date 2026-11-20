import 'package:flutter/material.dart';
import '../../theme/prism_theme.dart';
import '../prism/prism_sheet.dart';

/// Shows an explanatory sheet about Prism's offline download model, storage locations,
/// and audio playback guarantees.
Future<void> showOfflineStorageInfoSheet(BuildContext context) {
  return showPrismSheet<void>(
    context: context,
    builder: (sheetContext) => const OfflineStorageInfoSheet(),
  );
}

class OfflineStorageInfoSheet extends StatelessWidget {
  const OfflineStorageInfoSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(PrismRadius.xs),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.offline_pin_rounded,
                  color: scheme.onPrimaryContainer,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offline & Downloads Model',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'How offline audio is stored and guaranteed',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _InfoTile(
            icon: Icons.wifi_off_rounded,
            title: '100% Offline Guarantee',
            description:
                'Downloaded tracks are fully saved to your device. Playback never requires an active internet connection, never consumes mobile data, and does not stream or buffer.',
          ),
          const SizedBox(height: 14),
          const _InfoTile(
            icon: Icons.folder_special_rounded,
            title: 'Where Files Live',
            description:
                'Audio files are saved in your device\'s high-speed app storage under Downloads/PrismMusic/Audio (or your custom directory set in Settings). Other apps cannot modify them.',
          ),
          const SizedBox(height: 14),
          const _InfoTile(
            icon: Icons.high_quality_rounded,
            title: 'Audio Quality & Integrity',
            description:
                'Music is saved at your chosen download quality (up to 320 kbps high fidelity). File headers and byte ranges are validated upon completion to ensure skip-free playback.',
          ),
          const SizedBox(height: 14),
          const _InfoTile(
            icon: Icons.security_rounded,
            title: 'Privacy & Device-Only Data',
            description:
                'Downloaded tracks remain strictly on your local device with zero cloud syncing, zero accounts, and zero tracking. You can delete songs anytime.',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
