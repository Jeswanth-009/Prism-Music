import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/benchmark/playback_benchmark_matrix.dart';
import '../../../core/services/artifact_verification_service.dart';
import '../../../core/services/diagnostics_service.dart';
import '../../../core/services/settings_service.dart';
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
  bool _runningBenchmark = false;
  PlaybackBenchmarkReport? _benchmarkReport;
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
      child: SingleChildScrollView(
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
            const SizedBox(height: 12),
            if (_benchmarkReport != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(PrismRadius.md),
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
                          _benchmarkReport!.meetsReleaseSlo
                              ? Icons.check_circle_rounded
                              : Icons.info_rounded,
                          color: _benchmarkReport!.meetsReleaseSlo
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Playback Benchmark Matrix',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _diagRow('Cold Start P50/P90', '${_benchmarkReport!.coldStartLatency.p50Ms.toStringAsFixed(0)}ms / ${_benchmarkReport!.coldStartLatency.p90Ms.toStringAsFixed(0)}ms'),
                    _diagRow('High Latency Rec.', '${(_benchmarkReport!.networkResilience.highLatencyRecoveryRate * 100).toStringAsFixed(0)}%'),
                    _diagRow('Fallback Delay', '${_benchmarkReport!.networkResilience.averageFallbackDelay.inMilliseconds}ms'),
                    _diagRow('Buffer Profile', '${_benchmarkReport!.lowEndProfile.estimatedHeapUsageKb ~/ 1024}MB heap (${_benchmarkReport!.lowEndProfile.minBufferDuration.inSeconds}s pre-buffer)'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final text = _benchmarkReport!.toMarkdownSummary();
                        await Clipboard.setData(ClipboardData(text: text));
                        if (context.mounted) {
                          showPrismToast(context, 'Benchmark report copied');
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Benchmark Matrix'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _runningBenchmark ? null : _runBenchmark,
                icon: _runningBenchmark
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.speed_rounded, size: 18),
                label: Text(_runningBenchmark ? 'Running Playback Benchmark...' : 'Run Playback Benchmark'),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(PrismRadius.md),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.security_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Anonymous Diagnostics Consent',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          SettingsService.instance.telemetryConsent
                              ? 'Consent active: crash statistics sanitized locally'
                              : 'Consent disabled: 100% offline, zero network telemetry',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: SettingsService.instance.telemetryConsent,
                    onChanged: (val) async {
                      await SettingsService.instance.setTelemetryConsent(val);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final sanitizedJson =
                      await DiagnosticsService.instance.exportSanitizedLocalBundleJson();
                  await Clipboard.setData(ClipboardData(text: sanitizedJson));
                  if (context.mounted) {
                    showPrismToast(context, 'Sanitized local bundle copied');
                  }
                },
                icon: const Icon(Icons.shield_outlined, size: 18),
                label: const Text('Export Sanitized Diagnostics (Local Only)'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showArtifactVerificationDialog(context),
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: const Text('Artifact & Checksum Verification'),
              ),
            ),
            const SizedBox(height: 8),
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

  void _showArtifactVerificationDialog(BuildContext context) {
    final theme = Theme.of(context);
    final service = ArtifactVerificationService.instance;
    final arch = service.detectCurrentArch();
    final choices = service.getArtifactChoices(detectedArch: arch);
    final cert = service.getSigningCertificateMetadata();
    final verifyCmd = service.getHashVerificationCommand(filename: 'prism-music-release.apk');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Verified Artifact Downloads',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Detected Architecture: ${arch.displayName}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Official builds are built via GitHub Actions and verified with automated SBOM and SHA-256 provenance attestations.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Available Device & Emulator Choices:',
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              ...choices.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: c.isRecommended
                            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(PrismRadius.sm),
                        border: Border.all(
                          color: c.isRecommended
                              ? theme.colorScheme.primary.withValues(alpha: 0.4)
                              : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                c.title,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (c.isRecommended) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(PrismRadius.xs),
                                  ),
                                  child: Text(
                                    'Recommended',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onPrimary,
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
                            c.targetAudience,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(PrismRadius.sm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verify SHA-256 Checksum Command:',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      verifyCmd,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: verifyCmd));
                        if (context.mounted) {
                          showPrismToast(context, 'Verification command copied');
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Command'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        final uri = Uri.parse(cert['sbomUrl'] ?? 'https://github.com/Jeswanth-009/Prism-Music/releases');
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('View Releases'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _runBenchmark() async {
    setState(() => _runningBenchmark = true);
    try {
      final report = await DiagnosticsService.instance.runPlaybackBenchmark();
      if (mounted) {
        setState(() {
          _benchmarkReport = report;
          _runningBenchmark = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _runningBenchmark = false);
    }
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
