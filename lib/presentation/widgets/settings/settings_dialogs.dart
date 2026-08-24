import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/services/settings_service.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/theme/theme_event.dart';
import '../lastfm_login_dialog.dart';
import '../../../core/services/lastfm_service.dart';

class SettingsDialogs {
  static void showLoginDialog(
    BuildContext context, 
    LastFmService lastFmService, 
    VoidCallback onStateChanged
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
            ShadToaster.of(context).show(
              ShadToast(title: const Text('Successfully logged in to Last.fm!')),
            );
            onStateChanged();
          } else {
            Navigator.pop(context);
            if (!context.mounted) return;
            ShadToaster.of(context).show(
              ShadToast.destructive(
                title: const Text('Failed to login. Check your credentials.'),
              ),
            );
          }
        },
      ),
    );
  }

  static void showThemeModeDialog(BuildContext context) {
    final currentTheme = context.read<ThemeBloc>().state.themeMode;

    showShadDialog(
      context: context,
      builder: (dialogContext) {
        return ShadDialog(
          title: const Text('Theme Mode'),
          child: ShadRadioGroup<ThemeMode>(
            initialValue: currentTheme,
            onChanged: (value) {
              if (value != null) {
                context.read<ThemeBloc>().add(SetThemeModeEvent(value));
                Navigator.pop(dialogContext);
              }
            },
            items: [
              ShadRadio<ThemeMode>(
                value: ThemeMode.light,
                label: const Text('Light'),
                sublabel: const Text('Always use light theme'),
              ),
              ShadRadio<ThemeMode>(
                value: ThemeMode.dark,
                label: const Text('Dark'),
                sublabel: const Text('Always use dark theme'),
              ),
              ShadRadio<ThemeMode>(
                value: ThemeMode.system,
                label: const Text('System Default'),
                sublabel: const Text('Follow system settings'),
              ),
            ],
          ),
          actions: [
            ShadButton.ghost(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  static void showPlayerUiStyleSheet(BuildContext context, SettingsService settingsService, VoidCallback onStateChanged) {
    final currentStyle = settingsService.playerUiStyle;
    final descriptions = {
      PlayerUiStyle.classic: 'Detailed layout with glassmorphism',
      PlayerUiStyle.modern: 'Minimal circular dial inspired by modern players',
    };

    showShadSheet(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (sheetContext) {
        return ShadSheet(
          title: const Text('Player UI Style'),
          child: ShadRadioGroup<PlayerUiStyle>(
            initialValue: currentStyle,
            onChanged: (value) async {
              if (value != null) {
                Navigator.pop(sheetContext);
                await settingsService.setPlayerUiStyle(value);
                onStateChanged();
              }
            },
            items: PlayerUiStyle.values
                .map(
                  (style) => ShadRadio<PlayerUiStyle>(
                    value: style,
                    label: Text(style.label),
                    sublabel: Text(descriptions[style] ?? ''),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  static void showAudioQualityDialog(BuildContext context) {
    showShadDialog(
      context: context,
      builder: (dialogContext) {
        return ShadDialog(
          title: const Text('Audio Quality'),
          child: ShadRadioGroup<String>(
            initialValue: 'high',
            onChanged: (value) {
              ShadToaster.of(context).show(
                ShadToast(title: const Text('Coming soon!')),
              );
              Navigator.pop(dialogContext);
            },
            items: [
              ShadRadio<String>(
                value: 'low',
                label: const Text('Low (96 kbps)'),
                sublabel: const Text('Save data, lower quality'),
              ),
              ShadRadio<String>(
                value: 'medium',
                label: const Text('Medium (128 kbps)'),
                sublabel: const Text('Balanced quality'),
              ),
              ShadRadio<String>(
                value: 'high',
                label: const Text('High (192 kbps)'),
                sublabel: const Text('Best quality, more data'),
              ),
            ],
          ),
        );
      },
    );
  }

  static void showRepeatModeDialog(BuildContext context) {
    showShadDialog(
      context: context,
      builder: (dialogContext) {
        return ShadDialog(
          title: const Text('Default Repeat Mode'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShadButton.ghost(
                leading: const Icon(LucideIcons.x, size: 18),
                width: double.infinity,
                onPressed: () => Navigator.pop(dialogContext),
                child: const Align(alignment: Alignment.centerLeft, child: Text('Off')),
              ),
              ShadButton.ghost(
                leading: const Icon(LucideIcons.repeat, size: 18),
                width: double.infinity,
                onPressed: () => Navigator.pop(dialogContext),
                child: const Align(alignment: Alignment.centerLeft, child: Text('Repeat All')),
              ),
              ShadButton.ghost(
                leading: const Icon(LucideIcons.repeat1, size: 18),
                width: double.infinity,
                onPressed: () => Navigator.pop(dialogContext),
                child: const Align(alignment: Alignment.centerLeft, child: Text('Repeat One')),
              ),
            ],
          ),
        );
      },
    );
  }

  static void showCrossfadeDialog(BuildContext context) {
    double duration = 2.0;
    showShadDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return ShadDialog(
              title: const Text('Crossfade Duration'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${duration.toStringAsFixed(1)}s', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  ShadSlider(
                    initialValue: duration / 10.0,
                    min: 0,
                    max: 1,
                    onChanged: (value) {
                      setDialogState(() => duration = value * 10.0);
                    },
                  ),
                ],
              ),
              actions: [
                ShadButton.ghost(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ShadButton(
                  onPressed: () {
                    ShadToaster.of(context).show(
                      ShadToast(title: Text('Crossfade set to ${duration.toStringAsFixed(1)}s')),
                    );
                    Navigator.pop(dialogContext);
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
    showShadDialog(
      context: context,
      builder: (dialogContext) {
        return ShadDialog(
          title: const Text('Clear Cache'),
          description: const Text('This will remove all temporary files to free up space. Continue?'),
          actions: [
            ShadButton.ghost(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ShadButton.destructive(
              onPressed: () {
                ShadToaster.of(context).show(
                  ShadToast(title: const Text('Cache cleared successfully')),
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
  }

  static void showDownloadFolderDialog(BuildContext context, SettingsService settingsService) {
    final currentPath = settingsService.downloadFolderPath;
    final controller = TextEditingController(text: currentPath ?? '');

    showShadDialog(
      context: context,
      builder: (dialogContext) => ShadDialog(
        title: const Text('Download Folder'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose where to save downloaded songs:', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            ShadInput(
              controller: controller,
              placeholder: Text(Platform.isAndroid ? '/storage/emulated/0/Download/Music' : 'C:\\Music\\PrismDownloads'),
              trailing: ShadIconButton.ghost(
                icon: const Icon(LucideIcons.folderOpen, size: 18),
                width: 32,
                height: 32,
                onPressed: () async {
                  if (Platform.isAndroid) {
                    final result = await showShadDialog<String>(
                      context: context,
                      builder: (ctx) {
                        final pathController = TextEditingController(text: controller.text);
                        return ShadDialog(
                          title: const Text('Enter Folder Path'),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Common Android paths:', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              const Text(
                                '- /storage/emulated/0/Download\n- /storage/emulated/0/Music\n- /storage/emulated/0/Documents',
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 16),
                              ShadInput(controller: pathController, placeholder: const Text('Full Path')),
                            ],
                          ),
                          actions: [
                            ShadButton.ghost(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                            ShadButton(
                              onPressed: () {
                                if (pathController.text.isNotEmpty) {
                                  Navigator.pop(ctx, pathController.text);
                                }
                              },
                              child: const Text('Confirm'),
                            ),
                          ],
                        );
                      },
                    );
                    if (result != null && result.isNotEmpty) {
                      controller.text = result;
                    }
                  } else {
                    ShadToaster.of(context).show(
                      ShadToast(title: const Text('Folder picker not implemented on this platform yet.')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          ShadButton.ghost(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ShadButton(
            onPressed: () async {
              final path = controller.text.trim();
              await settingsService.setDownloadFolderPath(path.isEmpty ? null : path);
              if (context.mounted) {
                Navigator.pop(dialogContext);
                ShadToaster.of(context).show(
                  ShadToast(title: const Text('Download folder updated')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
