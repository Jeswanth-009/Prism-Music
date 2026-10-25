import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/services/stream_loader_service.dart';
import '../../../core/services/verified_recording_verifier.dart';
import '../../../domain/entities/song.dart';
import '../../blocs/player/player_bloc.dart';
import '../../blocs/player/player_event.dart';
import '../../blocs/player/player_state.dart';
import '../../theme/prism_theme.dart';
import '../prism/prism_sheet.dart';

/// Shows the provider health diagnostics and safe source switching bottom sheet.
void showProviderHealthSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(PrismRadius.xl)),
    ),
    builder: (sheetContext) => const ProviderHealthSheetContent(),
  );
}

class ProviderHealthSheetContent extends StatefulWidget {
  const ProviderHealthSheetContent({super.key});

  @override
  State<ProviderHealthSheetContent> createState() =>
      _ProviderHealthSheetContentState();
}

class _ProviderHealthSheetContentState
    extends State<ProviderHealthSheetContent> {
  final Map<String, VerificationResult?> _verificationCache = {};
  final Set<String> _checkingResolvers = {};
  String? _switchingResolver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final streamLoader = getIt<StreamLoaderService>();
    final healthSummary = streamLoader.getProviderHealthSummary();

    return BlocConsumer<PlayerBloc, PlayerState>(
      listenWhen: (prev, next) =>
          prev.currentStreamInfo != next.currentStreamInfo ||
          prev.errorMessage != next.errorMessage,
      listener: (context, state) {
        if (_switchingResolver != null) {
          setState(() => _switchingResolver = null);
          if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
            showPrismToast(context, state.errorMessage!);
          } else {
            showPrismToast(context, 'Switched audio source safely');
          }
        }
      },
      builder: (context, playerState) {
        final currentSong = playerState.currentSong;
        final currentStream = playerState.currentStreamInfo;
        final activeProvenance = currentStream?.streamProvenance;

        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          expand: false,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
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
                        color: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(PrismRadius.md),
                      ),
                      child: Icon(
                        Icons.health_and_safety_rounded,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Provider Health & Audio Sources',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (currentSong != null)
                            Text(
                              currentSong.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Active Source Summary Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(PrismRadius.lg),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'CURRENTLY PLAYING SOURCE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatProvenanceName(activeProvenance),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (currentStream != null && currentStream.bitrate > 0)
                            Text(
                              '${currentStream.bitrate} kbps · .${currentStream.container}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      if (currentStream?.matchConfidence != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${(currentStream!.matchConfidence! * 100).toStringAsFixed(0)}% verified recording parity',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                Text(
                  'Available Stream Providers',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Only verified recordings matching the exact track duration (±4s) and metadata tokens can be safely switched without restarting playback.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),

                // List of Providers
                ...healthSummary.entries.map((entry) {
                  final resolverName = entry.key;
                  final health = entry.value;
                  final isActive = _isResolverActive(activeProvenance, resolverName);
                  final verification = _verificationCache[resolverName];
                  final isChecking = _checkingResolvers.contains(resolverName);
                  final isSwitching = _switchingResolver == resolverName;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isActive
                          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
                          : theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(PrismRadius.md),
                      border: Border.all(
                        color: isActive
                            ? theme.colorScheme.primary.withValues(alpha: 0.5)
                            : context.prismSpec.hairline,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildHealthIndicator(theme, health),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          health.displayName,
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isActive) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            borderRadius:
                                                BorderRadius.circular(PrismRadius.xs),
                                          ),
                                          child: Text(
                                            'ACTIVE',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              color:
                                                  theme.colorScheme.onPrimary,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${health.averageLatencyMs}ms ping · ${health.successRate.toStringAsFixed(0)}% success${health.isCircuitOpen ? ' · Cooldown active' : ''}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: health.isCircuitOpen
                                          ? theme.colorScheme.error
                                          : theme.colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isActive && currentSong != null) ...[
                              if (verification == null)
                                TextButton(
                                  onPressed: isChecking
                                      ? null
                                      : () => _checkCandidate(
                                            currentSong,
                                            resolverName,
                                            streamLoader,
                                          ),
                                  child: isChecking
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Verify'),
                                )
                              else if (verification.isVerified)
                                FilledButton.tonal(
                                  onPressed: isSwitching
                                      ? null
                                      : () => _safeSwitch(context, resolverName),
                                  child: isSwitching
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Switch'),
                                ),
                            ],
                          ],
                        ),
                        if (verification != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: verification.isVerified
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : theme.colorScheme.errorContainer
                                      .withValues(alpha: 0.3),
                              borderRadius:
                                  BorderRadius.circular(PrismRadius.xs),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  verification.isVerified
                                      ? Icons.verified_rounded
                                      : Icons.warning_amber_rounded,
                                  size: 14,
                                  color: verification.isVerified
                                      ? Colors.green
                                      : theme.colorScheme.error,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    verification.reason,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: verification.isVerified
                                          ? Colors.green.shade800
                                          : theme.colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHealthIndicator(ThemeData theme, ProviderHealthStatus health) {
    Color color;
    IconData icon;

    if (health.isCircuitOpen || health.isQuarantined) {
      color = theme.colorScheme.error;
      icon = Icons.error_outline_rounded;
    } else if (health.averageLatencyMs > 400) {
      color = Colors.amber;
      icon = Icons.access_time_rounded;
    } else {
      color = Colors.green;
      icon = Icons.check_circle_rounded;
    }

    return Icon(icon, color: color, size: 20);
  }

  bool _isResolverActive(String? activeProvenance, String resolverName) {
    if (activeProvenance == null) return false;
    if (activeProvenance.startsWith(resolverName)) return true;
    if (resolverName == 'jiosaavn' && activeProvenance.contains('jiosaavn')) return true;
    if (resolverName == 'youtube_explode' && activeProvenance.contains('youtube')) return true;
    if (resolverName == 'piped' && activeProvenance.contains('piped')) return true;
    if (resolverName == 'invidious' && activeProvenance.contains('invidious')) return true;
    return false;
  }

  String _formatProvenanceName(String? prov) {
    if (prov == null) return 'Default YouTube';
    if (prov.contains('jiosaavn')) return 'JioSaavn 320kbps High-Fi';
    if (prov.contains('youtube')) return 'YouTube Direct DASH';
    if (prov.contains('piped')) return 'Piped Audio Proxy';
    if (prov.contains('invidious')) return 'Invidious Network Instance';
    return prov;
  }

  Future<void> _checkCandidate(
    Song song,
    String resolverName,
    StreamLoaderService loader,
  ) async {
    setState(() => _checkingResolvers.add(resolverName));
    try {
      final candidate = await loader.resolveCandidateStream(song, resolverName);
      if (!mounted) return;

      if (candidate == null) {
        setState(() {
          _checkingResolvers.remove(resolverName);
          _verificationCache[resolverName] = const VerificationResult(
            isVerified: false,
            confidence: 0.0,
            durationDeltaSeconds: 0,
            reason: 'Resolver failed to return a valid audio stream',
          );
        });
        return;
      }

      final result = VerifiedRecordingVerifier.verify(
        referenceSong: song,
        candidateStream: candidate,
      );

      setState(() {
        _checkingResolvers.remove(resolverName);
        _verificationCache[resolverName] = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checkingResolvers.remove(resolverName);
        _verificationCache[resolverName] = VerificationResult(
          isVerified: false,
          confidence: 0.0,
          durationDeltaSeconds: 0,
          reason: 'Verification error: $e',
        );
      });
    }
  }

  void _safeSwitch(BuildContext context, String resolverName) {
    setState(() => _switchingResolver = resolverName);
    context.read<PlayerBloc>().add(
          SwitchStreamSourceEvent(targetResolverName: resolverName),
        );
  }
}
