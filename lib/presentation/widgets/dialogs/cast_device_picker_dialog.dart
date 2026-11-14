import 'package:flutter/material.dart';
import '../../../core/services/cast_service.dart';

/// Shows the Cast Device Picker modal bottom sheet
Future<void> showCastDevicePickerDialog(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const CastDevicePickerDialog(),
  );
}

class CastDevicePickerDialog extends StatefulWidget {
  const CastDevicePickerDialog({super.key});

  @override
  State<CastDevicePickerDialog> createState() => _CastDevicePickerDialogState();
}

class _CastDevicePickerDialogState extends State<CastDevicePickerDialog> {
  double _volume = 0.8;

  @override
  void initState() {
    super.initState();
    CastService.instance.startDiscovery();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cast = CastService.instance;

    return StreamBuilder<CastState>(
      stream: cast.stateStream,
      initialData: cast.state,
      builder: (context, stateSnap) {
        final state = stateSnap.data ?? CastState.disconnected;
        final currentDevice = cast.currentDevice;

        return StreamBuilder<List<CastDevice>>(
          stream: cast.devicesStream,
          initialData: cast.discoveredDevices,
          builder: (context, devicesSnap) {
            final devices = devicesSnap.data ?? [];

            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
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
                        const Icon(Icons.cast_rounded, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Cast to Speaker',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (state == CastState.discovering)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          IconButton(
                            onPressed: () => cast.startDiscovery(),
                            icon: const Icon(Icons.refresh_rounded),
                            tooltip: 'Refresh devices',
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Active device card
                    if (currentDevice != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
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
                                  Icons.cast_connected_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentDevice.name,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Connected via ${currentDevice.protocol.name.toUpperCase()}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: () async {
                                    await cast.disconnect();
                                    if (mounted) setState(() {});
                                  },
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('Disconnect'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.volume_down_rounded, size: 20),
                                Expanded(
                                  child: Slider(
                                    value: _volume,
                                    onChanged: (val) {
                                      setState(() => _volume = val);
                                      cast.setVolume(val);
                                    },
                                  ),
                                ),
                                const Icon(Icons.volume_up_rounded, size: 20),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Text(
                      'Available Devices',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (devices.isEmpty && state == CastState.discovering)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('Scanning local network for speakers...'),
                        ),
                      )
                    else if (devices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.speaker_group_outlined,
                                size: 36,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 8),
                              const Text('No DLNA or Chromecast speakers found'),
                              const SizedBox(height: 4),
                              Text(
                                'Make sure devices are on the same Wi-Fi network',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          final isCurrent = currentDevice?.id == device.id;

                          return ListTile(
                            leading: Icon(
                              device.protocol == CastProtocol.chromecast
                                  ? Icons.cast_rounded
                                  : Icons.speaker_rounded,
                              color: isCurrent ? theme.colorScheme.primary : null,
                            ),
                            title: Text(device.name),
                            subtitle: Text('${device.protocol.name.toUpperCase()} · ${device.host}'),
                            trailing: isCurrent
                                ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                                : null,
                            onTap: isCurrent
                                ? null
                                : () async {
                                    await cast.connect(device);
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
