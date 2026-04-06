import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/di/injection.dart';
import '../../core/services/lastfm_service.dart';
import '../../core/services/recommendation_service.dart';
import '../../core/services/settings_service.dart';
import '../../domain/repositories/music_repository.dart';
import '../../domain/repositories/library_repository.dart';
import '../blocs/theme/theme_bloc.dart';
import '../blocs/theme/theme_event.dart';
import '../blocs/theme/theme_state.dart';
import '../widgets/lastfm_login_dialog.dart';

/// Comprehensive settings page for Prism Music
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final LastFmService _lastFmService = LastFmService();
  final SettingsService _settingsService = SettingsService.instance;
  RecommendationService? _recommendationService;
  bool _isInitialized = false;
  bool _hasInitialized = false;
  bool _fastStartEnabled = true;
  int _prefetchLookahead = 1;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitialized) {
      _hasInitialized = true;
      _initialize();
    }
  }

  Future<void> _initialize() async {
    try {
      await _lastFmService.initialize();
      await _settingsService.initialize();
      _fastStartEnabled = _settingsService.fastStartEnabled;
      _prefetchLookahead = _settingsService.prefetchLookahead;
      final musicRepository = getIt<MusicRepository>();
      final libraryRepository = getIt<LibraryRepository>();
      _recommendationService = RecommendationService(musicRepository, libraryRepository);
      await _recommendationService?.initialize();
      if (kDebugMode) {
        debugPrint('RecommendationService initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Initialization error: $e');
        debugPrint('Stack trace: ${StackTrace.current}');
      }
      _recommendationService = null;
    }
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  Future<void> _showLoginDialog() async {
    await showDialog(
      context: context,
      builder: (context) => LastFmLoginDialog(
        onLogin: (username, password) async {
          final success =
              await _lastFmService.authenticate(username, password);
          if (!context.mounted) return;

          if (success) {
            Navigator.pop(context);
            if (!mounted) return;
            ShadToaster.of(context).show(
              ShadToast(
                  title: const Text('Successfully logged in to Last.fm!')),
            );
            setState(() {});
          } else {
            Navigator.pop(context);
            if (!mounted) return;
            ShadToaster.of(context).show(
              ShadToast.destructive(
                title: const Text(
                    'Failed to login. Check your credentials.'),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildHeroHeader(context, theme),
            _buildSection(
              context,
              title: 'Last.fm',
              icon: LucideIcons.music,
              children: [
                if (!_isInitialized)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const SizedBox(
                            width: 20, height: 20, child: ShadProgress()),
                        const SizedBox(width: 12),
                        const Text('Initializing...'),
                      ],
                    ),
                  ),
                if (_isInitialized && _lastFmService.isAuthenticated) ...[
                  _SettingRow(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD51007),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.check,
                          color: Colors.white, size: 20),
                    ),
                    title: 'Connected',
                    subtitle: _lastFmService.username ?? 'Last.fm',
                    trailing: ShadButton.ghost(
                      onPressed: () async {
                        await _lastFmService.logout();
                        if (!context.mounted) return;
                        setState(() {});
                        ShadToaster.of(context).show(
                          ShadToast(
                              title:
                                  const Text('Logged out from Last.fm')),
                        );
                      },
                      size: ShadButtonSize.sm,
                      child: const Text('Logout'),
                    ),
                  ),
                  _SettingRow(
                    leading: const Icon(LucideIcons.history, size: 20),
                    title: 'Scrobbling',
                    subtitle:
                        'Automatically track your listening history',
                    trailing: Icon(LucideIcons.circleCheck,
                        color: Colors.green.shade600, size: 20),
                  ),
                ],
                if (_isInitialized && !_lastFmService.isAuthenticated)
                  _SettingRow(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD51007),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.music,
                          color: Colors.white, size: 20),
                    ),
                    title: 'Connect to Last.fm',
                    subtitle:
                        'Track your listening history and get recommendations',
                    trailing: ShadButton(
                      onPressed: _showLoginDialog,
                      size: ShadButtonSize.sm,
                      child: const Text('Login'),
                    ),
                  ),
              ],
            ),
            _buildSection(
              context,
              title: 'Recommendations',
              icon: LucideIcons.sparkles,
              children: [
                if (!_isInitialized)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const SizedBox(
                            width: 20, height: 20, child: ShadProgress()),
                        const SizedBox(width: 12),
                        const Text('Initializing...'),
                      ],
                    ),
                  ),
                if (_isInitialized && _recommendationService == null)
                  _SettingRow(
                    leading: Icon(LucideIcons.triangleAlert,
                        color: Colors.orange.shade600, size: 20),
                    title: 'Failed to initialize',
                    subtitle: 'Please restart the app',
                  ),
                if (_isInitialized &&
                    _recommendationService != null) ...[
                  _SettingRow(
                    leading: const Icon(LucideIcons.music, size: 20),
                    title: 'Similar',
                    subtitle:
                        'Play similar songs from same artist or genre',
                    trailing: ShadButton(
                      onPressed: () async {
                        await _recommendationService
                            ?.setMode(RecommendationMode.similar);
                        if (!context.mounted) return;
                        setState(() {});
                        ShadToaster.of(context).show(
                          ShadToast(
                              title: const Text(
                                  'Mode set to Similar')),
                        );
                      },
                      size: ShadButtonSize.sm,
                      child: Text(
                        _recommendationService!.mode ==
                                RecommendationMode.similar
                            ? 'Active'
                            : 'Select',
                      ),
                    ),
                  ),
                  _SettingRow(
                    leading: const Icon(LucideIcons.compass, size: 20),
                    title: 'Discover',
                    subtitle:
                        'Discover new music from different genres',
                    trailing: ShadButton(
                      onPressed: () async {
                        await _recommendationService
                            ?.setMode(RecommendationMode.discover);
                        if (!context.mounted) return;
                        setState(() {});
                        ShadToaster.of(context).show(
                          ShadToast(
                              title: const Text(
                                  'Mode set to Discover')),
                        );
                      },
                      size: ShadButtonSize.sm,
                      child: Text(
                        _recommendationService!.mode ==
                                RecommendationMode.discover
                            ? 'Active'
                            : 'Select',
                      ),
                    ),
                  ),
                ],
              ],
            ),
            _buildSection(
              context,
              title: 'Playback performance',
              icon: LucideIcons.gauge,
              children: [
                _SettingRow(
                  leading: const Icon(LucideIcons.zap, size: 20),
                  title: 'Fast start (medium first)',
                  subtitle:
                      'Start streams at medium quality for quicker playback',
                  trailing: ShadSwitch(
                    value: _fastStartEnabled,
                    onChanged: (value) async {
                      await _settingsService.setFastStartEnabled(value);
                      if (!mounted) return;
                      setState(() => _fastStartEnabled = value);
                      ShadToaster.of(context).show(
                        ShadToast(
                          title: Text(value
                              ? 'Fast start enabled'
                              : 'Fast start disabled'),
                        ),
                      );
                    },
                  ),
                ),
                _SettingRow(
                  leading:
                      const Icon(LucideIcons.cloudDownload, size: 20),
                  title: 'Prefetch lookahead',
                  subtitle:
                      'Prefetch the next $_prefetchLookahead track(s)',
                  trailing: ShadSelect<int>(
                    selectedOptionBuilder: (ctx, value) =>
                        Text('$value'),
                    initialValue: _prefetchLookahead,
                    onChanged: (value) async {
                      if (value == null) return;
                      await _settingsService
                          .setPrefetchLookahead(value);
                      if (!mounted) return;
                      setState(() => _prefetchLookahead = value);
                    },
                    options: const [0, 1, 2]
                        .map(
                          (v) => ShadOption(
                            value: v,
                            child: Text('$v'),
                          ),
                        )
                        .toList(),
                    minWidth: 80,
                    maxWidth: 100,
                  ),
                ),
              ],
            ),
            _buildSection(
              context,
              title: 'Region',
              icon: LucideIcons.globe,
              children: [
                if (!_isInitialized)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const SizedBox(
                            width: 20, height: 20, child: ShadProgress()),
                        const SizedBox(width: 12),
                        const Text('Loading...'),
                      ],
                    ),
                  ),
                if (_isInitialized) ...[
                  _SettingRow(
                    leading: Text(
                      _settingsService.selectedCountry.flag,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: 'Your Country',
                    subtitle: _settingsService.selectedCountry.name,
                    trailing: ShadIconButton.ghost(
                      icon: const Icon(LucideIcons.chevronRight,
                          size: 18),
                      onPressed: () =>
                          _showCountrySelectionDialog(context),
                    ),
                    onTap: () =>
                        _showCountrySelectionDialog(context),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      'Your country affects trending charts and music recommendations.',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ],
            ),
            _buildSection(
              context,
              title: 'Appearance',
              icon: LucideIcons.palette,
              children: [
                BlocBuilder<ThemeBloc, ThemeState>(
                  builder: (context, state) {
                    return _SettingRow(
                      leading: Icon(
                        state.themeMode == ThemeMode.dark
                            ? LucideIcons.moon
                            : state.themeMode == ThemeMode.light
                                ? LucideIcons.sun
                                : LucideIcons.sunMoon,
                        size: 20,
                      ),
                      title: 'Theme Mode',
                      subtitle: state.themeMode == ThemeMode.dark
                          ? 'Dark'
                          : state.themeMode == ThemeMode.light
                              ? 'Light'
                              : 'System Default',
                      onTap: () => _showThemeModeDialog(context),
                    );
                  },
                ),
                _SettingRow(
                  leading: const Icon(LucideIcons.paintbrush, size: 20),
                  title: 'Color Scheme',
                  subtitle: 'Dynamic colors from album art',
                  trailing: ShadSwitch(
                    value: true,
                    onChanged: (value) {
                      ShadToaster.of(context).show(
                        ShadToast(
                            title: const Text('Coming soon!')),
                      );
                    },
                  ),
                ),
                _SettingRow(
                  leading: const Icon(LucideIcons.disc, size: 20),
                  title: 'Player UI',
                  subtitle: _settingsService.playerUiStyle.label,
                  trailing: ShadIconButton.ghost(
                    icon: const Icon(LucideIcons.chevronRight,
                        size: 18),
                    onPressed: _showPlayerUiStyleSheet,
                  ),
                  onTap: _showPlayerUiStyleSheet,
                ),
              ],
            ),
            _buildSection(
              context,
              title: 'Audio',
              icon: LucideIcons.audioLines,
              children: [
                _SettingRow(
                  leading:
                      const Icon(LucideIcons.audioWaveform, size: 20),
                  title: 'Audio Quality',
                  subtitle: 'High (192 kbps)',
                  onTap: () => _showAudioQualityDialog(context),
                ),
                _SettingRow(
                  leading: Icon(LucideIcons.slidersHorizontal, size: 20),
                  title: 'Equalizer',
                  subtitle: 'Customize audio output',
                  onTap: () {
                    ShadToaster.of(context).show(
                      ShadToast(
                        title: const Text(
                            'Open equalizer from the player screen'),
                      ),
                    );
                  },
                ),
                _SettingRow(
                  leading: const Icon(LucideIcons.headphones, size: 20),
                  title: 'Bass Boost',
                  subtitle: 'Enhanced low frequencies',
                  trailing: ShadSwitch(
                    value: true,
                    onChanged: (value) {},
                  ),
                ),
              ],
            ),
            _buildSection(
              context,
              title: 'Playback',
              icon: LucideIcons.circlePlay,
              children: [
                _SettingRow(
                  leading: const Icon(LucideIcons.repeat, size: 20),
                  title: 'Default Repeat Mode',
                  subtitle: 'Off',
                  onTap: () => _showRepeatModeDialog(context),
                ),
                _SettingRow(
                  leading: const Icon(LucideIcons.shuffle, size: 20),
                  title: 'Auto Shuffle',
                  subtitle: 'Shuffle queue automatically',
                  trailing: ShadSwitch(
                    value: false,
                    onChanged: (value) {},
                  ),
                ),
                _SettingRow(
                  leading: const Icon(LucideIcons.timer, size: 20),
                  title: 'Crossfade Duration',
                  subtitle: 'Smooth transition between songs',
                  onTap: () => _showCrossfadeDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSection(
              context,
              title: 'Storage',
              icon: LucideIcons.hardDrive,
              children: [
                _SettingRow(
                  leading: const Icon(LucideIcons.folderOpen, size: 20),
                  title: 'Download Folder',
                  subtitle: _settingsService.downloadFolderPath ??
                      'Default (Android/data/.../Downloads/PrismMusic/Audio)',
                  onTap: () => _showDownloadFolderDialog(context),
                ),
                _SettingRow(
                  leading: const Icon(LucideIcons.download, size: 20),
                  title: 'Downloads',
                  subtitle: 'Manage downloaded songs',
                  onTap: () {
                    ShadToaster.of(context).show(
                      ShadToast(
                          title: const Text('Coming soon!')),
                    );
                  },
                ),
                _SettingRow(
                  leading: const Icon(LucideIcons.database, size: 20),
                  title: 'Cache',
                  subtitle: 'Clear temporary files',
                  onTap: () => _showClearCacheDialog(context),
                ),
              ],
            ),
            _buildSection(
              context,
              title: 'About',
              icon: LucideIcons.info,
              children: [
                _SettingRow(
                  leading:
                      const Icon(LucideIcons.smartphone, size: 20),
                  title: 'Version',
                  subtitle: 'Prism Music 1.0.0',
                ),
                _SettingRow(
                  leading: const Icon(LucideIcons.code, size: 20),
                  title: 'Open Source',
                  subtitle: 'View on GitHub',
                  onTap: () {
                    ShadToaster.of(context).show(
                      ShadToast(
                          title: const Text('Coming soon!')),
                    );
                  },
                ),
                _SettingRow(
                  leading: const Icon(LucideIcons.shield, size: 20),
                  title: 'Privacy Policy',
                  onTap: () {
                    ShadToaster.of(context).show(
                      ShadToast(
                          title: const Text('Coming soon!')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── hero header ──────────────────────────────────────────────────────

  Widget _buildHeroHeader(BuildContext context, ThemeData theme) {
    final connected = _lastFmService.isAuthenticated;
    final recoMode = _recommendationService?.mode;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: ShadCard(
        padding: const EdgeInsets.all(24),
        backgroundColor: theme.colorScheme.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShadIconButton.outline(
              icon: const Icon(LucideIcons.arrowLeft,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: 8),
            Text(
              'Settings',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tune Prism to match your mood, devices, and rituals.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ShadBadge.secondary(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        connected
                            ? LucideIcons.circleCheck
                            : LucideIcons.cloudOff,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        connected
                            ? 'Last.fm linked'
                            : 'Last.fm offline',
                        style:
                            const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                if (recoMode != null)
                  ShadBadge.secondary(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.sparkles,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'Mode: ${recoMode.name}',
                          style: const TextStyle(
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ShadButton(
                  onPressed: () =>
                      _showThemeModeDialog(context),
                  leading: const Icon(LucideIcons.sunMoon,
                      size: 16),
                  size: ShadButtonSize.sm,
                  child: const Text('Theme mode'),
                ),
                const SizedBox(width: 12),
                ShadButton.outline(
                  onPressed: _showPlayerUiStyleSheet,
                  leading:
                      const Icon(LucideIcons.disc, size: 16),
                  size: ShadButtonSize.sm,
                  child: const Text('Player UI'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── section wrapper ──────────────────────────────────────────────────

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ShadCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary
                          .withOpacity(0.12),
                    ),
                    child: Icon(icon,
                        color: theme.colorScheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Customize ${title.toLowerCase()}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ShadSeparator.horizontal(),
            Column(
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20),
                      child: ShadSeparator.horizontal(),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── dialogs ──────────────────────────────────────────────────────────

  void _showThemeModeDialog(BuildContext context) {
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
                context
                    .read<ThemeBloc>()
                    .add(SetThemeModeEvent(value));
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

  void _showPlayerUiStyleSheet() {
    final currentStyle = _settingsService.playerUiStyle;
    final descriptions = {
      PlayerUiStyle.classic:
          'Detailed layout with glassmorphism',
      PlayerUiStyle.modern:
          'Minimal circular dial inspired by modern players',
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
                await _settingsService.setPlayerUiStyle(value);
                if (mounted) setState(() {});
              }
            },
            items: PlayerUiStyle.values
                .map(
                  (style) => ShadRadio<PlayerUiStyle>(
                    value: style,
                    label: Text(style.label),
                    sublabel:
                        Text(descriptions[style] ?? ''),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  void _showAudioQualityDialog(BuildContext context) {
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

  void _showRepeatModeDialog(BuildContext context) {
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
                child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Off')),
              ),
              ShadButton.ghost(
                leading: const Icon(LucideIcons.repeat, size: 18),
                width: double.infinity,
                onPressed: () => Navigator.pop(dialogContext),
                child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Repeat All')),
              ),
              ShadButton.ghost(
                leading: const Icon(LucideIcons.repeat1, size: 18),
                width: double.infinity,
                onPressed: () => Navigator.pop(dialogContext),
                child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Repeat One')),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCrossfadeDialog(BuildContext context) {
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
                  Text('${duration.toStringAsFixed(1)}s',
                      style: Theme.of(context).textTheme.headlineSmall),
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
                      ShadToast(
                        title: Text(
                            'Crossfade set to ${duration.toStringAsFixed(1)}s'),
                      ),
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

  void _showClearCacheDialog(BuildContext context) {
    showShadDialog(
      context: context,
      builder: (dialogContext) {
        return ShadDialog(
          title: const Text('Clear Cache'),
          description: const Text(
            'This will remove all temporary files to free up space. Continue?',
          ),
          actions: [
            ShadButton.ghost(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ShadButton.destructive(
              onPressed: () {
                ShadToaster.of(context).show(
                  ShadToast(
                      title:
                          const Text('Cache cleared successfully')),
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

  void _showDownloadFolderDialog(BuildContext context) {
    final theme = Theme.of(context);
    final currentPath = _settingsService.downloadFolderPath;
    final controller =
        TextEditingController(text: currentPath ?? '');

    showShadDialog(
      context: context,
      builder: (dialogContext) => ShadDialog(
        title: const Text('Download Folder'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose where to save downloaded songs:',
                style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            ShadInput(
              controller: controller,
              placeholder: Text(
                Platform.isAndroid
                    ? '/storage/emulated/0/Download/Music'
                    : 'C:\\Music\\PrismDownloads',
              ),
              trailing: ShadIconButton.ghost(
                icon: const Icon(LucideIcons.folderOpen, size: 18),
                width: 32,
                height: 32,
                onPressed: () async {
                  if (Platform.isAndroid) {
                    final result = await showShadDialog<String>(
                      context: context,
                      builder: (ctx) {
                        final pathController =
                            TextEditingController(
                                text: controller.text);
                        return ShadDialog(
                          title: const Text('Enter Folder Path'),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text('Common Android paths:',
                                  style: TextStyle(
                                      fontWeight:
                                          FontWeight.bold)),
                              const SizedBox(height: 8),
                              const Text(
                                '- /storage/emulated/0/Download\n'
                                '- /storage/emulated/0/Music\n'
                                '- /storage/emulated/0/Documents',
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 16),
                              ShadInput(
                                controller: pathController,
                                placeholder:
                                    const Text('Full Path'),
                              ),
                            ],
                          ),
                          actions: [
                            ShadButton.ghost(
                              onPressed: () =>
                                  Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            ShadButton(
                              onPressed: () => Navigator.pop(
                                  ctx,
                                  pathController.text),
                              child: const Text('OK'),
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
                      ShadToast(
                        title: const Text(
                            'Enter path manually for desktop'),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Leave empty to use default location',
              style: TextStyle(
                  fontSize: 12, color: theme.colorScheme.outline),
            ),
          ],
        ),
        actions: [
          ShadButton.ghost(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ShadButton.outline(
            onPressed: () async {
              await _settingsService.setDownloadFolderPath(null);
              if (!mounted) return;
              Navigator.pop(dialogContext);
              setState(() {});
              ShadToaster.of(context).show(
                ShadToast(
                    title: const Text(
                        'Using default download folder')),
              );
            },
            child: const Text('Use Default'),
          ),
          ShadButton(
            onPressed: () async {
              final path = controller.text.trim();
              if (path.isEmpty) {
                await _settingsService
                    .setDownloadFolderPath(null);
              } else {
                try {
                  final dir = Directory(path);
                  if (!await dir.exists()) {
                    await dir.create(recursive: true);
                  }
                  await _settingsService
                      .setDownloadFolderPath(path);
                } catch (e) {
                  if (!mounted) return;
                  ShadToaster.of(context).show(
                    ShadToast.destructive(
                      title: Text('Invalid folder path: $e'),
                    ),
                  );
                  return;
                }
              }
              if (!mounted) return;
              Navigator.pop(dialogContext);
              setState(() {});
              ShadToaster.of(context).show(
                ShadToast(
                  title: Text(path.isEmpty
                      ? 'Using default download folder'
                      : 'Download folder set to: $path'),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCountrySelectionDialog(BuildContext context) {
    final theme = Theme.of(context);
    final searchController = TextEditingController();
    List<CountryInfo> filteredCountries =
        List.from(supportedCountries);

    showShadSheet(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ShadSheet(
              title: Row(
                children: [
                  const Icon(LucideIcons.globe, size: 24),
                  const SizedBox(width: 12),
                  const Text('Select Your Country'),
                ],
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8),
                      child: ShadInput(
                        controller: searchController,
                        placeholder:
                            const Text('Search countries...'),
                        leading:
                            const Icon(LucideIcons.search, size: 18),
                        onChanged: (value) {
                          setModalState(() {
                            if (value.isEmpty) {
                              filteredCountries =
                                  List.from(supportedCountries);
                            } else {
                              filteredCountries = supportedCountries
                                  .where((c) =>
                                      c.name
                                          .toLowerCase()
                                          .contains(value
                                              .toLowerCase()) ||
                                      c.code
                                          .toLowerCase()
                                          .contains(
                                              value.toLowerCase()))
                                  .toList();
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredCountries.length,
                        itemBuilder: (context, index) {
                          final country =
                              filteredCountries[index];
                          final isSelected = country.code ==
                              _settingsService.countryCode;

                          return ShadButton.ghost(
                            width: double.infinity,
                            onPressed: () async {
                              await _settingsService
                                  .setCountryCode(country.code);
                              if (!context.mounted ||
                                  !mounted) return;
                              Navigator.pop(sheetContext);
                              setState(() {});
                              if (mounted) {
                                ShadToaster.of(context).show(
                                  ShadToast(
                                    title: Text(
                                        'Region set to ${country.name} ${country.flag}'),
                                  ),
                                );
                              }
                            },
                            child: Row(
                              children: [
                                Text(country.flag,
                                    style: const TextStyle(
                                        fontSize: 28)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        country.name,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight
                                                  .normal,
                                          color: isSelected
                                              ? theme.colorScheme
                                                  .primary
                                              : null,
                                        ),
                                      ),
                                      Text(
                                        country.code,
                                        style: theme
                                            .textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    LucideIcons.circleCheck,
                                    color:
                                        theme.colorScheme.primary,
                                    size: 20,
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
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

// ════════════════════════════════════════════════════════════════════════
// Reusable setting row
// ════════════════════════════════════════════════════════════════════════

class _SettingRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingRow({
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w500)),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
