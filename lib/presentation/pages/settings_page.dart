import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/di/injection.dart';
import '../../core/services/lastfm_service.dart';
import '../../core/services/local_backup_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/recommendation_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/audio_player_service.dart';
import '../../core/services/queue_persistence_service.dart';
import '../../core/localization/prism_localizations.dart';
import '../../core/utils/formatters.dart';

import '../blocs/theme/theme_bloc.dart';
import '../blocs/theme/theme_event.dart';
import '../blocs/theme/theme_state.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../blocs/player/player_state.dart';

import 'downloads_page.dart';
import '../widgets/equalizer/equalizer_bottom_sheet.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/prism/prism_artwork.dart';
import '../widgets/prism/prism_dialog.dart';
import '../widgets/prism/prism_sheet.dart';
import '../widgets/settings/about_diagnostics_sheet.dart';
import '../widgets/settings/portable_backup_sheet.dart';
import '../widgets/settings/setting_row.dart';
import '../widgets/settings/setting_section_card.dart';
import '../widgets/settings/country_selection_sheet.dart';
import '../widgets/settings/settings_dialogs.dart';

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
  bool _autoBackupEnabled = true;
  bool _sharedBackupEnabled = false;
  int _prefetchLookahead = 1;
  String _appVersion = 'Loading...';
  BackupSnapshotInfo? _latestBackupInfo;
  String? _cacheUsageSubtitle;

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
      _autoBackupEnabled = _settingsService.autoBackupEnabled;
      _sharedBackupEnabled = _settingsService.sharedBackupEnabled;
      _prefetchLookahead = _settingsService.prefetchLookahead;
      _recommendationService = getIt<RecommendationService>();

      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      _latestBackupInfo =
          await LocalBackupService.instance.getLatestBackupInfo();
      await _refreshStorageInfo();

      if (mounted) setState(() {});
    } catch (e) {
      if (kDebugMode) debugPrint('Initialization error: $e');
      _recommendationService = null;
    }
    if (mounted) setState(() => _isInitialized = true);
  }

  Future<void> _refreshStorageInfo() async {
    try {
      final breakdown = await StorageService.instance.getStorageBreakdown();
      if (mounted) {
        setState(() {
          _cacheUsageSubtitle =
              '${Formatters.formatBytes(breakdown.cacheBytes)} temporary files';
        });
      }
    } catch (_) {}
  }

  Future<void> _refreshBackupInfo() async {
    final info = await LocalBackupService.instance.getLatestBackupInfo();
    if (mounted) setState(() => _latestBackupInfo = info);
  }

  Future<void> _exportBackup() async {
    final file = await LocalBackupService.instance.getBackupFileForExport();
    if (!mounted) return;
    if (file == null) {
      showPrismToast(context, 'Unable to create backup for export');
      return;
    }
    try {
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Prism Music Backup',
        text: 'Prism Music library backup (${_formatBackupDate(DateTime.now())})',
      );
      if (mounted) {
        showPrismToast(context, 'Backup ready for export');
      }
    } catch (e) {
      if (mounted) {
        showPrismToast(context, 'Export failed: $e');
      }
    }
  }

  void _confirmAndDeleteBackup() {
    showPrismConfirmDialog(
      context: context,
      title: 'Delete Backups',
      message: 'Are you sure you want to delete all stored backup snapshot files from this device? This action cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
      onConfirm: () async {
        final count = await LocalBackupService.instance.deleteBackupFiles();
        if (!mounted) return;
        showPrismToast(context, count > 0 ? 'Deleted $count backup files' : 'No backup files were found');
        await _refreshBackupInfo();
      },
    );
  }

  String _formatBackupDate(DateTime dt) {
    final local = dt.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  Future<void> _showAppLanguageDialog() async {
    final currentCode = _settingsService.appLanguage;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => SimpleDialog(
        title: const Text('Select App Language'),
        children: supportedPrismLanguages.map((lang) {
          final isSelected = lang.code == currentCode;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogCtx, lang.code),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.nativeName,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    Text(
                      lang.englishName,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Theme.of(dialogCtx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (isSelected)
                  Icon(
                    Icons.check_rounded,
                    color: Theme.of(dialogCtx).colorScheme.primary,
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (selected != null) {
      await _settingsService.setAppLanguage(selected);
      if (!mounted) return;
      setState(() {});
      showPrismToast(
        context,
        'App language set to ${supportedPrismLanguages.firstWhere((l) => l.code == selected).nativeName}',
      );
    }
  }

  void _forceRebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(theme),
          SliverToBoxAdapter(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _buildAccountSection(),
                  const SizedBox(height: 16),
                  _buildAppExperienceSection(),
                  _buildAudioPlaybackSection(),
                  _buildDataStorageSection(),
                  _buildBackupPrivacySection(),
                  _buildAboutSection(),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const PrismPersistentMiniPlayer(),
    );
  }

  Widget _buildSliverAppBar(ThemeData theme) {
    final connected = _lastFmService.isAuthenticated;
    final recoMode = _recommendationService?.mode;
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : theme.colorScheme.onSurfaceVariant;

    return SliverAppBar(
      expandedHeight: 190.0,
      floating: false,
      pinned: true,
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      theme.colorScheme.primary.withValues(alpha: 0.55),
                      theme.colorScheme.primary.withValues(alpha: 0.12),
                      theme.colorScheme.surface,
                    ]
                  : [
                      theme.colorScheme.primary.withValues(alpha: 0.16),
                      theme.colorScheme.primary.withValues(alpha: 0.05),
                      theme.colorScheme.surface,
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Settings',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tune Prism to match your mood.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (_lastFmService.hasValidCredentials)
                      _PillBadge(
                        icon: connected
                            ? Icons.check_circle_rounded
                            : Icons.cloud_off_rounded,
                        text: connected ? 'Last.fm linked' : 'Last.fm offline',
                      ),
                    if (recoMode != null)
                      _PillBadge(
                        icon: Icons.auto_awesome_rounded,
                        text: 'Mode: ${recoMode.name}',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSection() {
    return SettingSectionCard(
      title: 'Account & Services',
      subtitle: 'Manage your connected integrations',
      icon: Icons.person_outline_rounded,
      children: [
        if (!_isInitialized)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Initializing...'),
              ],
            ),
          ),
        if (_isInitialized) ...[
          if (_lastFmService.hasValidCredentials) ...[
            if (_lastFmService.isAuthenticated) ...[
              SettingRow(
                leading: const Icon(Icons.check_circle_outline_rounded),
                title: 'Connected',
                subtitle: _lastFmService.username ?? 'Last.fm',
                trailing: TextButton(
                  onPressed: () async {
                    await _lastFmService.logout();
                    _forceRebuild();
                    if (mounted) {
                      showPrismToast(context, 'Logged out from Last.fm');
                    }
                  },
                  child: const Text('Logout'),
                ),
              ),
              SettingRow(
                leading: const Icon(Icons.history_rounded),
                title: 'Scrobbling',
                subtitle: 'Automatically track your listening history',
                trailing: Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green.shade600,
                  size: 20,
                ),
              ),
            ],
            if (!_lastFmService.isAuthenticated)
              SettingRow(
                leading: const Icon(Icons.music_note_rounded),
                title: 'Connect to Last.fm',
                subtitle:
                    'Track your listening history and get recommendations',
                trailing: FilledButton.tonal(
                  onPressed: () => SettingsDialogs.showLoginDialog(
                    context,
                    _lastFmService,
                    _forceRebuild,
                  ),
                  child: const Text('Login'),
                ),
              ),
            SettingRow(
              leading: const Icon(Icons.key_rounded),
              title: 'Last.fm API Credentials',
              subtitle: _lastFmService.hasCustomCredentials
                  ? 'Custom API credentials configured'
                  : 'Default build-time credentials active',
              trailing: TextButton(
                onPressed: () => SettingsDialogs.showLastFmCredentialsDialog(
                  context,
                  _lastFmService,
                  _forceRebuild,
                ),
                child: const Text('Configure'),
              ),
            ),
          ] else ...[
            SettingRow(
              leading: const Icon(Icons.key_off_rounded),
              title: 'Last.fm Scrobbling',
              subtitle:
                  'API credentials required to enable Last.fm login & scrobbling',
              trailing: FilledButton.tonal(
                onPressed: () => SettingsDialogs.showLastFmCredentialsDialog(
                  context,
                  _lastFmService,
                  _forceRebuild,
                ),
                child: const Text('Configure'),
              ),
            ),
          ],
        ],
        SettingRow(
          leading: const Icon(Icons.graphic_eq_rounded),
          title: 'Spotify Integration',
          subtitle: _settingsService.spotifyClientId != null
              ? 'Configured • Uncapped Web API & ISRC'
              : 'Optional • Embed fallback active (capped at 100)',
          trailing: FilledButton.tonal(
            onPressed: () => SettingsDialogs.showSpotifyCredentialsDialog(
              context,
              _forceRebuild,
            ),
            child: Text(
              _settingsService.spotifyClientId != null ? 'Edit' : 'Configure',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppExperienceSection() {
    return SettingSectionCard(
      title: 'App Experience',
      subtitle: 'Customize the look, feel, and recommendations',
      icon: Icons.palette_outlined,
      children: [
        BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, state) {
            return SettingRow(
              leading: Icon(
                state.themeMode == ThemeMode.dark
                    ? Icons.dark_mode_outlined
                    : state.themeMode == ThemeMode.light
                        ? Icons.light_mode_outlined
                        : Icons.brightness_auto_outlined,
              ),
              title: 'Theme Mode',
              subtitle: state.themeMode == ThemeMode.dark
                  ? 'Dark'
                  : state.themeMode == ThemeMode.light
                      ? 'Light'
                      : 'System Default',
              onTap: () => SettingsDialogs.showThemeModeDialog(context),
            );
          },
        ),
        BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, themeState) {
            return SettingRow(
              leading: const Icon(Icons.colorize_rounded),
              title: 'Accent from artwork',
              subtitle: themeState.isDynamicColorEnabled
                  ? 'App accent follows the playing song'
                  : 'Using the fixed Prism accent',
              trailing: Switch.adaptive(
                value: themeState.isDynamicColorEnabled,
                onChanged: (_) => context
                    .read<ThemeBloc>()
                    .add(const ToggleDynamicColorEvent()),
              ),
            );
          },
        ),
        BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, state) {
            return SettingRow(
              leading: Icon(
                state.layoutMode == LayoutMode.grid
                    ? Icons.grid_view_rounded
                    : state.layoutMode == LayoutMode.minimalist
                        ? Icons.view_headline_rounded
                        : Icons.view_list_rounded,
              ),
              title: 'Layout Mode',
              subtitle: state.layoutMode == LayoutMode.grid
                  ? 'Grid'
                  : state.layoutMode == LayoutMode.minimalist
                      ? 'Minimalist'
                      : 'List',
              onTap: () => SettingsDialogs.showLayoutModeDialog(context),
            );
          },
        ),
        SettingRow(
          leading: const Icon(Icons.dashboard_customize_outlined),
          title: 'Player Layout',
          subtitle: _settingsService.playerUiStyle.label,
          onTap: () => SettingsDialogs.showPlayerUiStyleDialog(
            context,
            _forceRebuild,
          ),
        ),
        if (_isInitialized)
          SettingRow(
            leading: Text(
              _settingsService.selectedCountry.flag,
              style: const TextStyle(fontSize: 24),
            ),
            title: 'Trending Region',
            subtitle: _settingsService.selectedCountry.name,
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () =>
                showCountrySelectionSheet(context, _settingsService, _forceRebuild),
          ),
        if (_isInitialized && _recommendationService != null)
          SettingRow(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: 'Recommendation Mode',
            subtitle: _recommendationService!.mode == RecommendationMode.similar
                ? 'Similar artists & genres'
                : 'Discover new music',
            trailing: TextButton(
              onPressed: () async {
                final newMode =
                    _recommendationService!.mode == RecommendationMode.similar
                        ? RecommendationMode.discover
                        : RecommendationMode.similar;
                await _recommendationService!.setMode(newMode);
                _forceRebuild();
              },
              child: const Text('Toggle'),
            ),
          ),
        SettingRow(
          leading: const Icon(Icons.motion_photos_off_rounded),
          title: 'Reduced Motion',
          subtitle: _settingsService.reducedMotionMode
              ? 'Animations disabled for accessibility and smoothness'
              : 'Standard motion and transitions active',
          trailing: Switch.adaptive(
            value: _settingsService.reducedMotionMode,
            onChanged: (val) async {
              await _settingsService.setReducedMotionMode(val);
              if (mounted) setState(() {});
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAudioPlaybackSection() {
    return SettingSectionCard(
      title: 'Audio & Playback',
      subtitle: 'Quality, equalizer, and behavior',
      icon: Icons.graphic_eq_rounded,
      children: [
        BlocBuilder<PlayerBloc, PlayerState>(
          builder: (context, state) {
            final quality = state.audioQuality;
            // Keep these in sync with the AudioQuality entity bitrates —
            // the labels previously advertised 96/192 kbps.
            final subtitle = quality.displayName;
            return SettingRow(
              leading: const Icon(Icons.waves_rounded),
              title: 'Audio Quality',
              subtitle: subtitle,
              onTap: () => SettingsDialogs.showAudioQualityDialog(context),
            );
          },
        ),
        SettingRow(
          leading: const Icon(Icons.tune_rounded),
          title: 'Equalizer',
          subtitle: 'Customize audio output',
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (context) => EqualizerBottomSheet(
                equalizerService: getIt<AudioPlayerService>().equalizer,
              ),
            );
          },
        ),
        SettingRow(
          leading: const Icon(Icons.bolt_rounded),
          title: 'Fast Start',
          subtitle: 'Start streams at medium quality for quicker playback',
          trailing: Switch.adaptive(
            value: _fastStartEnabled,
            onChanged: (value) async {
              await _settingsService.setFastStartEnabled(value);
              setState(() => _fastStartEnabled = value);
            },
          ),
        ),
        SettingRow(
          leading: const Icon(Icons.cloud_download_outlined),
          title: 'Prefetch Lookahead',
          subtitle: 'Prefetch the next $_prefetchLookahead track(s)',
          trailing: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('0')),
              ButtonSegment(value: 1, label: Text('1')),
              ButtonSegment(value: 2, label: Text('2')),
              ButtonSegment(value: 3, label: Text('3')),
            ],
            // The service default is 3 — the old 0–2 control rendered with
            // nothing selected on a fresh install.
            selected: {_prefetchLookahead.clamp(0, 3)},
            onSelectionChanged: (selection) async {
              final value = selection.first;
              await _settingsService.setPrefetchLookahead(value);
              setState(() => _prefetchLookahead = value);
            },
          ),
        ),
        SettingRow(
          leading: const Icon(Icons.shuffle_rounded),
          title: 'Auto Shuffle',
          subtitle: 'Shuffle queue automatically',
          trailing: Switch.adaptive(
            value: _settingsService.autoShuffle,
            onChanged: (value) async {
              await _settingsService.setAutoShuffle(value);
              setState(() {});
            },
          ),
        ),
        SettingRow(
          leading: const Icon(Icons.autorenew_rounded),
          title: 'Auto-Play',
          subtitle: 'Keep playing similar songs when queue ends',
          trailing: Switch.adaptive(
            value: _settingsService.autoPlay,
            onChanged: (value) async {
              await _settingsService.setAutoPlay(value);
              setState(() {});
            },
          ),
        ),
        SettingRow(
          leading: const Icon(Icons.history_toggle_off_rounded),
          title: 'Restore Queue on Launch',
          subtitle: 'Restore previous queue safely paused without surprise playback',
          trailing: Switch.adaptive(
            value: _settingsService.restoreQueueOnLaunch,
            onChanged: (value) async {
              await _settingsService.setRestoreQueueOnLaunch(value);
              setState(() {});
            },
          ),
        ),
        SettingRow(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: 'Exclude Incognito Sessions',
          subtitle: 'Do not persist private listening sessions to disk',
          trailing: Switch.adaptive(
            value: _settingsService.excludeIncognitoQueue,
            onChanged: (value) async {
              await _settingsService.setExcludeIncognitoQueue(value);
              setState(() {});
            },
          ),
        ),
        SettingRow(
          leading: const Icon(Icons.delete_sweep_outlined),
          title: 'Clear Saved Queue',
          subtitle: 'Erase persisted listening queue from private storage',
          trailing: TextButton(
            onPressed: () async {
              await QueuePersistenceService.instance.clearSession();
              if (!mounted) return;
              context.read<PlayerBloc>().add(const ClearPersistedQueueEvent());
              showPrismToast(context, 'Saved queue session cleared');
            },
            child: const Text('Clear'),
          ),
        ),
        SettingRow(
          leading: const Icon(Icons.translate_rounded),
          title: 'App Language',
          subtitle: supportedPrismLanguages
              .firstWhere(
                (l) => l.code == _settingsService.appLanguage,
                orElse: () => supportedPrismLanguages.first,
              )
              .nativeName,
          onTap: _showAppLanguageDialog,
        ),
        SettingRow(
          leading: const Icon(Icons.language_rounded),
          title: 'Music Languages',
          subtitle: _settingsService.preferredLanguages.join(', '),
          onTap: () async {
            await SettingsDialogs.showLanguagePreferencesDialog(context, _forceRebuild);
          },
        ),
        SettingRow(
          leading: const Icon(Icons.thumb_down_outlined),
          title: 'Not Interested Feedback',
          subtitle: '${_settingsService.notInterestedSongs.length} songs, ${_settingsService.notInterestedArtists.length} artists hidden',
          onTap: () async {
            await SettingsDialogs.showNotInterestedDialog(context, _forceRebuild);
          },
        ),
        SettingRow(
          leading: const Icon(Icons.tune_rounded),
          title: 'Track Transition (Fade Out / In)',
          subtitle: _settingsService.crossfadeDuration <= 0
              ? 'Off — seamless cut between songs'
              : 'Currently ${_settingsService.crossfadeDuration.toStringAsFixed(1)}s (fade out & in)',
          onTap: () async {
            await SettingsDialogs.showTrackTransitionDialog(context);
            _forceRebuild();
          },
        ),
        if (Platform.isAndroid)
          SettingRow(
            leading: const Icon(Icons.battery_charging_full_rounded),
            title: 'Unrestricted Battery Usage',
            subtitle:
                'Prevents Android from stopping audio playback in the background',
            trailing: FutureBuilder<bool>(
              future: PermissionService.hasIgnoreBatteryOptimizations(),
              builder: (context, snapshot) {
                final isIgnored = snapshot.data ?? false;
                if (isIgnored) {
                  return Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green.shade600,
                    size: 20,
                  );
                }
                return TextButton(
                  onPressed: () async {
                    await PermissionService.requestIgnoreBatteryOptimizations();
                    _forceRebuild();
                  },
                  child: const Text('Optimize'),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildDataStorageSection() {
    return SettingSectionCard(
      title: 'Data & Storage',
      subtitle: 'Downloads and cache management',
      icon: Icons.storage_outlined,
      children: [
        SettingRow(
          leading: const Icon(Icons.wifi_rounded),
          title: 'Download over Wi-Fi only',
          subtitle: _settingsService.downloadWifiOnly
              ? 'Only download audio tracks when connected to Wi-Fi'
              : 'Allow downloads over cellular/mobile data networks',
          trailing: Switch.adaptive(
            value: _settingsService.downloadWifiOnly,
            onChanged: (val) async {
              await _settingsService.setDownloadWifiOnly(val);
              if (mounted) setState(() {});
            },
          ),
        ),
        SettingRow(
          leading: const Icon(Icons.data_saver_on_rounded),
          title: 'Cellular Data Saver',
          subtitle: _settingsService.cellularDataSaver
              ? 'Data saver active: conservative bitrates on mobile networks'
              : 'Prefer high quality playback regardless of network type',
          trailing: Switch.adaptive(
            value: _settingsService.cellularDataSaver,
            onChanged: (val) async {
              await _settingsService.setCellularDataSaver(val);
              if (mounted) setState(() {});
            },
          ),
        ),
        SettingRow(
          leading: const Icon(Icons.image_outlined),
          title: 'Save Offline Artwork',
          subtitle: _settingsService.offlineArtworkPersistence
              ? 'Cache high-resolution artwork for offline playback'
              : 'Save audio file only without local artwork caching',
          trailing: Switch.adaptive(
            value: _settingsService.offlineArtworkPersistence,
            onChanged: (val) async {
              await _settingsService.setOfflineArtworkPersistence(val);
              if (mounted) setState(() {});
            },
          ),
        ),
        SettingRow(
          leading: const Icon(Icons.folder_outlined),
          title: 'Download Folder',
          subtitle: _settingsService.downloadFolderPath ?? 'Default',
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: () => SettingsDialogs.showDownloadFolderDialog(
            context,
            _settingsService,
          ),
        ),
        SettingRow(
          leading: const Icon(Icons.download_rounded),
          title: 'Downloads',
          subtitle: 'Manage downloaded songs',
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DownloadsPage()),
            );
          },
        ),
        SettingRow(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: 'Cache',
          subtitle: _cacheUsageSubtitle ?? 'Clear temporary files',
          onTap: () => SettingsDialogs.showClearCacheDialog(
            context,
            onCleared: _refreshStorageInfo,
          ),
        ),
      ],
    );
  }

  Widget _buildBackupPrivacySection() {
    return SettingSectionCard(
      title: 'Backup & Privacy',
      subtitle: 'Where your library backup lives',
      icon: Icons.backup_outlined,
      children: [
        SettingRow(
          leading: const Icon(Icons.backup_outlined),
          title: 'Automatic backup',
          subtitle: _autoBackupEnabled
              ? 'Saves your library, history and searches after changes '
                  '(app-private storage)'
              : 'Automatic backups are off',
          trailing: Switch.adaptive(
            value: _autoBackupEnabled,
            onChanged: (value) async {
              await _settingsService.setAutoBackupEnabled(value);
              if (mounted) setState(() => _autoBackupEnabled = value);
            },
          ),
        ),
        SettingRow(
          leading: const Icon(Icons.folder_shared_outlined),
          title: 'Keep a copy in shared storage',
          subtitle: _sharedBackupEnabled
              ? 'Extra copy in Downloads survives an uninstall — but other '
                  'apps with storage access can read it'
              : 'Off — backups stay private to the app',
          trailing: Switch.adaptive(
            value: _sharedBackupEnabled,
            onChanged: (value) async {
              await _settingsService.setSharedBackupEnabled(value);
              if (mounted) setState(() => _sharedBackupEnabled = value);
              if (value) await LocalBackupService.instance.backup();
            },
          ),
        ),
        SettingRow(
          leading: const Icon(Icons.info_outline_rounded),
          title: 'Backup Status',
          subtitle: _latestBackupInfo != null
              ? '${_latestBackupInfo!.totalItems} items · ${Formatters.formatBytes(_latestBackupInfo!.fileSizeBytes)}\nLast backup: ${_formatBackupDate(_latestBackupInfo!.timestamp)}'
              : 'No backup snapshot found on this device',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _autoBackupEnabled
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _autoBackupEnabled ? 'Active' : 'Disabled',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _autoBackupEnabled
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
        SettingRow(
          leading: const Icon(Icons.cloud_sync_outlined),
          title: 'Back up now',
          subtitle: 'Write local backup snapshot immediately',
          onTap: () async {
            final result = await LocalBackupService.instance.backup();
            if (!mounted) return;
            if (result.isSuccess) {
              showPrismToast(
                context,
                'Backup saved: ${result.totalItems} items (${Formatters.formatBytes(result.bytesWritten)})',
              );
            } else {
              showPrismToast(
                context,
                'Backup failed: ${result.error ?? 'unknown error'}',
              );
            }
            await _refreshBackupInfo();
          },
        ),
        SettingRow(
          leading: const Icon(Icons.file_upload_outlined),
          title: 'Export backup',
          subtitle: 'Share or export backup JSON archive',
          onTap: _exportBackup,
        ),
        SettingRow(
          leading: const Icon(Icons.settings_backup_restore_rounded),
          title: 'Portable Backup & Restore',
          subtitle: 'Export, inspect, merge or restore library backups',
          onTap: () => showPortableBackupSheet(context, onBackupChanged: _refreshBackupInfo),
        ),
        SettingRow(
          leading: Icon(
            Icons.delete_outline_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          title: 'Delete backup files',
          subtitle: 'Remove all local backup snapshot files',
          onTap: _confirmAndDeleteBackup,
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return SettingSectionCard(
      title: 'About',
      subtitle: 'Build details, diagnostics, source code & licenses',
      icon: Icons.info_outline_rounded,
      children: [
        SettingRow(
          leading: const PrismLogoMark(size: 24),
          title: 'Version',
          subtitle: 'Prism Music $_appVersion',
          trailing: const Icon(Icons.copy_rounded, size: 16),
          onTap: () {
            Clipboard.setData(ClipboardData(text: 'Prism Music $_appVersion'));
            showPrismToast(context, 'Version copied to clipboard');
          },
        ),
        SettingRow(
          leading: const Icon(Icons.code_rounded),
          title: 'Source Code',
          subtitle: 'GitHub repository (Jeswanth-009/Prism-Music)',
          trailing: const Icon(Icons.open_in_new_rounded, size: 18),
          onTap: () => _openUrl('https://github.com/Jeswanth-009/Prism-Music'),
        ),
        SettingRow(
          leading: const Icon(Icons.bug_report_outlined),
          title: 'Support & Issues',
          subtitle: 'Report a bug or suggest improvements',
          trailing: const Icon(Icons.open_in_new_rounded, size: 18),
          onTap: () => _openUrl('https://github.com/Jeswanth-009/Prism-Music/issues'),
        ),
        SettingRow(
          leading: const Icon(Icons.description_outlined),
          title: 'Open Source Licenses',
          subtitle: 'Third-party libraries & license texts',
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: () {
            showLicensePage(
              context: context,
              applicationName: 'Prism Music',
              applicationVersion: _appVersion,
              applicationIcon: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: PrismLogoMark(size: 54),
              ),
              applicationLegalese: 'Crafted with precision for private, offline-first music listening.',
            );
          },
        ),
        SettingRow(
          leading: const Icon(Icons.terminal_rounded),
          title: 'Diagnostics & System Info',
          subtitle: 'Platform, audio engine, cache & backup details',
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: () => showPrismDiagnosticsSheet(context),
        ),
      ],
    );
  }

  Future<void> _openUrl(String urlString) async {
    final url = Uri.parse(urlString);
    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        showPrismToast(context, 'Could not open the browser');
      }
    } catch (_) {
      if (mounted) showPrismToast(context, 'Could not open the browser');
    }
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.22)
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.25)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark ? Colors.white : theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: isDark ? Colors.white : theme.colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
