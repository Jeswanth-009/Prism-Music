import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/stream_cache_service.dart';
import '../../../domain/entities/entities.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/theme/theme_event.dart';
import '../../blocs/player/player.dart';
import '../prism/prism_sheet.dart';
import '../lastfm_login_dialog.dart';
import '../../../core/services/lastfm_service.dart';

extension _AudioQualityLabel on AudioQuality {
  String get label => switch (this) {
    AudioQuality.low => 'Low',
    AudioQuality.medium => 'Medium',
    AudioQuality.high => 'High',
    AudioQuality.lossless => 'Lossless',
  };

  String get subtitle => switch (this) {
    AudioQuality.low => '64 kbps — saves the most data',
    AudioQuality.medium => '128 kbps — balanced',
    AudioQuality.high => '256 kbps — detailed',
    AudioQuality.lossless => '320 kbps — maximum fidelity',
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

  static void showPlayerUiStyleSheet(
    BuildContext context,
    SettingsService settingsService,
    VoidCallback onStateChanged,
  ) {
    final currentStyle = settingsService.playerUiStyle;
    final descriptions = {
      PlayerUiStyle.classic: 'Detailed layout with glassmorphism',
      PlayerUiStyle.modern: 'Minimal circular dial inspired by modern players',
    };

    showPrismSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  'Player UI Style',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final style in PlayerUiStyle.values)
                RadioListTile<PlayerUiStyle>(
                  value: style,
                  groupValue: currentStyle,
                  onChanged: (value) async {
                    if (value != null) {
                      Navigator.pop(sheetContext);
                      await settingsService.setPlayerUiStyle(value);
                      onStateChanged();
                    }
                  },
                  title: Text(style.label),
                  subtitle: Text(descriptions[style] ?? ''),
                ),
              const SizedBox(height: 8),
            ],
          ),
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

  static void showRepeatModeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Default Repeat Mode'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext),
              child: const ListTile(
                leading: Icon(Icons.close_rounded),
                title: Text('Off'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext),
              child: const ListTile(
                leading: Icon(Icons.repeat_rounded),
                title: Text('Repeat All'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext),
              child: const ListTile(
                leading: Icon(Icons.repeat_one_rounded),
                title: Text('Repeat One'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        );
      },
    );
  }

  static void showCrossfadeDialog(BuildContext context) {
    double duration = 2.0;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
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
                    value: (duration / 10.0).clamp(0.0, 1.0),
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

  static void showClearCacheDialog(BuildContext context) {
    final stats = getIt<StreamCacheService>().getStats();
    final validStreams = stats['valid'] as int? ?? 0;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Clear cache?'),
          content: Text(
            'This drops $validStreams pre-resolved stream${validStreams == 1 ? '' : 's'} '
            'and the in-memory artwork cache. Downloads are kept.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                getIt<StreamCacheService>().clearAll();
                PaintingBinding.instance.imageCache.clear();
                PaintingBinding.instance.imageCache.clearLiveImages();
                showPrismToast(context, 'Cache cleared');
                Navigator.pop(dialogContext);
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
                        final result = await showDialog<String>(
                          context: dialogContext,
                          builder: (ctx) {
                            final pathController = TextEditingController(
                              text: controller.text,
                            );
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
                        );
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
}
