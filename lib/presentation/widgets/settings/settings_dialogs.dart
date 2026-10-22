import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/di/injection.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/stream_cache_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/entities.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/theme/theme_event.dart';
import '../../blocs/player/player.dart';
import '../prism/prism_sheet.dart';
import '../lastfm_login_dialog.dart';
import '../../../core/services/lastfm_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/services/spotify_auth_service.dart';

extension _AudioQualityLabel on AudioQuality {
  String get label => switch (this) {
    AudioQuality.low => 'Low',
    AudioQuality.medium => 'Medium',
    AudioQuality.high => 'High',
    AudioQuality.lossless => 'Ultra',
  };

  String get subtitle => switch (this) {
    AudioQuality.low => '64 kbps — saves the most data',
    AudioQuality.medium => '128 kbps — balanced',
    AudioQuality.high => '160–256 kbps — high fidelity',
    AudioQuality.lossless => 'Up to 320 kbps (Source Dependent) — maximum available fidelity',
  };
}

class SettingsDialogs {
  static void showLoginDialog(
    BuildContext context,
    LastFmService lastFmService,
    VoidCallback onStateChanged,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => LastFmLoginDialog(
        onLogin: (username, password) async {
          final success = await lastFmService.authenticate(username, password);
          if (!context.mounted) return;

          if (success) {
            Navigator.pop(context);
            if (!context.mounted) return;
            showPrismToast(context, 'Successfully logged in to Last.fm!');
            onStateChanged();
          } else {
            Navigator.pop(context);
            if (!context.mounted) return;
            showPrismToast(
              context,
              'Failed to login. Check your credentials.',
            );
          }
        },
      ),
    );
  }

  static void showThemeModeDialog(BuildContext context) {
    final currentTheme = context.read<ThemeBloc>().state.themeMode;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Theme Mode'),
          children: [
            for (final mode in const [
              (ThemeMode.light, 'Light', 'Always use light theme'),
              (ThemeMode.dark, 'Dark', 'Always use dark theme'),
              (ThemeMode.system, 'System Default', 'Follow system settings'),
            ])
              RadioListTile<ThemeMode>(
                value: mode.$1,
                groupValue: currentTheme,
                onChanged: (value) {
                  if (value != null) {
                    dialogContext.read<ThemeBloc>().add(
                      SetThemeModeEvent(value),
                    );
                    Navigator.pop(dialogContext);
                  }
                },
                title: Text(mode.$2),
                subtitle: Text(mode.$3),
              ),
          ],
        );
      },
    );
  }

  static void showLayoutModeDialog(BuildContext context) {
    final currentLayout = context.read<ThemeBloc>().state.layoutMode;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Layout Mode'),
          children: [
            for (final item in const [
              (LayoutMode.list, 'List', 'Standard scrolling list layout'),
              (LayoutMode.grid, 'Grid', 'Card-based grid layout'),
              (LayoutMode.minimalist, 'Minimalist', 'Compact, text-focused display'),
            ])
              RadioListTile<LayoutMode>(
                value: item.$1,
                groupValue: currentLayout,
                onChanged: (value) {
                  if (value != null) {
                    dialogContext.read<ThemeBloc>().add(
                      SetLayoutModeEvent(value),
                    );
                    Navigator.pop(dialogContext);
                  }
                },
                title: Text(item.$2),
                subtitle: Text(item.$3),
              ),
          ],
        );
      },
    );
  }

  static void showPlayerUiStyleDialog(
    BuildContext context,
    VoidCallback onSelected,
  ) {
    final currentStyle = SettingsService.instance.playerUiStyle;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Player Layout'),
          children: [
            for (final style in PlayerUiStyle.values)
              RadioListTile<PlayerUiStyle>(
                value: style,
                groupValue: currentStyle,
                onChanged: (value) async {
                  if (value != null) {
                    await SettingsService.instance.setPlayerUiStyle(value);
                    onSelected();
                    Navigator.pop(dialogContext);
                  }
                },
                title: Text(style.label),
                subtitle: Text(
                  style == PlayerUiStyle.modern
                      ? 'Dynamic blur, expanded artwork and modern floating controls'
                      : 'Classic compact layout with 5-button transport bar',
                ),
              ),
          ],
        );
      },
    );
  }

  static void showAudioQualityDialog(BuildContext context) {
    final currentQuality = SettingsService.instance.audioQuality;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Audio Quality'),
          children: [
            for (final quality in AudioQuality.values)
              RadioListTile<String>(
                value: quality.name,
                groupValue: currentQuality,
                onChanged: (value) {
                  if (value == null) return;
                  SettingsService.instance.setAudioQuality(value);
                  dialogContext.read<PlayerBloc>().add(
                    SetAudioQualityEvent(quality),
                  );
                  Navigator.pop(dialogContext);
                  showPrismToast(
                    dialogContext,
                    'Audio quality set to ${quality.label} — applies on the next song',
                  );
                },
                title: Text(quality.label),
                subtitle: Text(quality.subtitle),
              ),
          ],
        );
      },
    );
  }

  /// Opens the crossfade slider pre-set to the saved duration.
  /// Resolves once the dialog is closed so callers can refresh their rows.
  static Future<void> showCrossfadeDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        // Previously always opened at 2.0s, ignoring the persisted value.
        double duration =
            SettingsService.instance.crossfadeDuration.clamp(0.0, 10.0);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Crossfade Duration'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${duration.toStringAsFixed(1)}s',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: duration / 10.0,
                    onChanged: (value) {
                      setDialogState(() => duration = value * 10.0);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    await SettingsService.instance
                        .setCrossfadeDuration(duration);
                    if (dialogContext.mounted) {
                      showPrismToast(
                        dialogContext,
                        'Crossfade set to ${duration.toStringAsFixed(1)}s',
                      );
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Future<int> _getDiskCacheBytes() async {
    int total = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await for (final entity in tempDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              total += await entity.length();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    return total;
  }

  static void showClearCacheDialog(BuildContext context) async {
    final stats = getIt<StreamCacheService>().getStats();
    final validStreams = stats['valid'] as int? ?? 0;
    final diskBytes = await _getDiskCacheBytes();
    final diskFormatted = Formatters.formatBytes(diskBytes);

    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Clear cache?'),
          content: Text(
            'This frees approximately $diskFormatted of temporary storage, clearing '
            '${Formatters.formatCount(validStreams, 'pre-resolved stream')}, cached album art, '
            'and lyrics cache. Downloaded songs are safely kept.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                getIt<StreamCacheService>().clearAll();
                PaintingBinding.instance.imageCache.clear();
                PaintingBinding.instance.imageCache.clearLiveImages();
                try {
                  await DefaultCacheManager().emptyCache();
                } catch (_) {}
                try {
                  if (Hive.isBoxOpen('lyrics_cache')) {
                    await Hive.box<Map>('lyrics_cache').clear();
                  } else {
                    final b = await Hive.openBox<Map>('lyrics_cache');
                    await b.clear();
                  }
                } catch (_) {}
                try {
                  if (Hive.isBoxOpen('song_cache')) {
                    await Hive.box('song_cache').clear();
                  }
                } catch (_) {}
                if (dialogContext.mounted) {
                  showPrismToast(dialogContext, 'Cache cleared ($diskFormatted freed)');
                  Navigator.pop(dialogContext);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
  }

  static void showDownloadFolderDialog(
    BuildContext context,
    SettingsService settingsService,
  ) {
    final currentPath = settingsService.downloadFolderPath;
    final controller = TextEditingController(text: currentPath ?? '');

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Download Folder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose where to save downloaded songs:'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: Platform.isAndroid
                      ? '/storage/emulated/0/Download/Music'
                      : 'C:\\Music\\PrismDownloads',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.folder_open_rounded, size: 20),
                    onPressed: () async {
                      if (Platform.isAndroid) {
                        final pathController = TextEditingController(
                          text: controller.text,
                        );
                        final result = await showDialog<String>(
                          context: dialogContext,
                          builder: (ctx) {
                            return AlertDialog(
                              title: const Text('Enter folder path'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Common Android paths:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    '- /storage/emulated/0/Download\n'
                                    '- /storage/emulated/0/Music\n'
                                    '- /storage/emulated/0/Documents',
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: pathController,
                                    decoration: const InputDecoration(
                                      hintText: 'Full path',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    if (pathController.text.isNotEmpty) {
                                      Navigator.pop(
                                        ctx,
                                        pathController.text,
                                      );
                                    }
                                  },
                                  child: const Text('Confirm'),
                                ),
                              ],
                            );
                          },
                        ).whenComplete(() => pathController.dispose());
                        if (result != null && result.isNotEmpty) {
                          setDialogState(() => controller.text = result);
                        }
                      } else {
                        if (dialogContext.mounted) {
                          showPrismToast(
                            dialogContext,
                            'Folder picker not implemented on this platform yet.',
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final path = controller.text.trim();
                if (path.isNotEmpty && Platform.isAndroid) {
                  final granted =
                      await PermissionService.requestStoragePermission();
                  if (!granted && dialogContext.mounted) {
                    showPrismToast(
                      dialogContext,
                      'Storage permission not granted. Custom folder may not be writable.',
                    );
                  }
                }
                await settingsService.setDownloadFolderPath(
                  path.isEmpty ? null : path,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  showPrismToast(dialogContext, 'Download folder updated');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog to enter and test Spotify Developer Client ID & Client Secret.
  static void showSpotifyCredentialsDialog(
    BuildContext context,
    VoidCallback onSaved,
  ) {
    final settingsService = SettingsService.instance;
    final idController =
        TextEditingController(text: settingsService.spotifyClientId ?? '');
    final secretController =
        TextEditingController(text: settingsService.spotifyClientSecret ?? '');
    bool isTesting = false;
    String? statusMessage;
    bool? isSuccess;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Spotify API Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Optional developer credentials allow unlimited playlist imports (up to 10,000 tracks) and exact ISRC matching. Completely free with any Spotify account.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: idController,
                  decoration: const InputDecoration(
                    labelText: 'Client ID',
                    hintText: 'e.g. 7a8b9c...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: secretController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Client Secret',
                    hintText: 'e.g. 1d2e3f...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (statusMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          isSuccess == true
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          size: 16,
                          color: isSuccess == true
                              ? Colors.green
                              : Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            statusMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSuccess == true
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: isTesting
                      ? null
                      : () async {
                          final id = idController.text.trim();
                          final secret = secretController.text.trim();
                          if (id.isEmpty || secret.isEmpty) {
                            setDialogState(() {
                              statusMessage =
                                  'Please enter both Client ID & Secret';
                              isSuccess = false;
                            });
                            return;
                          }
                          setDialogState(() {
                            isTesting = true;
                            statusMessage = 'Testing connection...';
                            isSuccess = null;
                          });
                          final authService = getIt<SpotifyAuthService>();
                          final ok = await authService.testConnection(
                            clientId: id,
                            clientSecret: secret,
                          );
                          setDialogState(() {
                            isTesting = false;
                            isSuccess = ok;
                            statusMessage = ok
                                ? 'Connection verified successfully!'
                                : 'Failed to authenticate with Spotify';
                          });
                        },
                  icon: isTesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cable_rounded, size: 16),
                  label: const Text('Test Connection'),
                ),
              ],
            ),
          ),
          actions: [
            if (settingsService.spotifyClientId != null)
              TextButton(
                onPressed: () async {
                  await settingsService.setSpotifyClientId(null);
                  await settingsService.setSpotifyClientSecret(null);
                  getIt<SpotifyAuthService>().invalidateToken();
                  onSaved();
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    showPrismToast(
                        dialogContext, 'Spotify credentials cleared');
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Clear'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final id = idController.text.trim();
                final secret = secretController.text.trim();
                await settingsService
                    .setSpotifyClientId(id.isEmpty ? null : id);
                await settingsService.setSpotifyClientSecret(
                    secret.isEmpty ? null : secret);
                getIt<SpotifyAuthService>().invalidateToken();
                onSaved();
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  showPrismToast(
                    dialogContext,
                    id.isNotEmpty
                        ? 'Spotify credentials saved'
                        : 'Spotify credentials cleared',
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      idController.dispose();
      secretController.dispose();
    });
  }
}
