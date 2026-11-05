import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/services/collaborative_queue_service.dart';
import '../../theme/prism_theme.dart';
import '../prism/prism_sheet.dart';

/// Modal sheet to activate, monitor, and share the local Party Mode server.
class PartyModeSheet extends StatefulWidget {
  const PartyModeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showPrismSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const PartyModeSheet(),
    );
  }

  @override
  State<PartyModeSheet> createState() => _PartyModeSheetState();
}

class _PartyModeSheetState extends State<PartyModeSheet> {
  final _service = CollaborativeQueueService.instance;
  bool _loading = false;

  Future<void> _toggleServer(bool start) async {
    setState(() => _loading = true);
    if (start) {
      await _service.startServer();
    } else {
      await _service.stopServer();
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = context.prismSpec;
    final isRunning = _service.isRunning;
    final pin = _service.pin;
    final shareUrl = '${_service.serverUrl}?pin=$pin';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(PrismRadius.sm),
                      ),
                      child: Icon(
                        Icons.celebration_rounded,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Party Mode',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Collaborative Queue via Wi-Fi',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_loading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                else
                  Switch.adaptive(
                    value: isRunning,
                    onChanged: _toggleServer,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (!isRunning)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(PrismRadius.md),
                  border: Border.all(color: spec.hairline),
                ),
                child: Text(
                  'Turn on Party Mode to let friends on the same Wi-Fi search and add songs directly to your queue without installing the app.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              )
            else ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(PrismRadius.md),
                  ),
                  child: QrImageView(
                    data: shareUrl,
                    version: QrVersions.auto,
                    size: 160,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(PrismRadius.md),
                  border: Border.all(color: spec.hairline),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WEB LINK & PIN',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _service.serverUrl,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'PIN: $pin',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      tooltip: 'Copy Link',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: shareUrl));
                        showPrismToast(context, 'Copied Party link to clipboard');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Live Guest Activity',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<PartyActivityEntry>>(
                stream: _service.activityStream,
                initialData: _service.activityLog,
                builder: (context, snapshot) {
                  final log = snapshot.data ?? const [];
                  if (log.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(PrismRadius.sm),
                      ),
                      child: Text(
                        'Waiting for guests to queue songs…',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 140),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: log.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final entry = log[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(PrismRadius.sm),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.queue_music_rounded,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${entry.guestName} queued "${entry.songTitle}"',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
