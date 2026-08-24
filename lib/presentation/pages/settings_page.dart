import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/di/injection.dart';
import '../../core/services/lastfm_service.dart';
import '../../core/services/recommendation_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/audio_player_service.dart';
import '../../domain/entities/entities.dart';

import '../blocs/theme/theme_bloc.dart';
import '../blocs/theme/theme_state.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_state.dart';

import 'downloads_page.dart';
import '../widgets/equalizer/equalizer_bottom_sheet.dart';
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
  int _prefetchLookahead = 1;
  String _appVersion = 'Loading...';

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
      _recommendationService = getIt<RecommendationService>();
      
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      
      if (mounted) setState(() {});
    } catch (e) {
      if (kDebugMode) debugPrint('Initialization error: $e');
      _recommendationService = null;
    }
    if (mounted) setState(() => _isInitialized = true);
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
                  _buildAppExperienceSection(),
                  _buildAudioPlaybackSection(),
                  _buildDataStorageSection(),
                  _buildAboutSection(),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(ThemeData theme) {
    final connected = _lastFmService.isAuthenticated;
    final recoMode = _recommendationService?.mode;

    return SliverAppBar(
      expandedHeight: 220.0,
      floating: false,
      pinned: true,
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.8),
                theme.colorScheme.primary.withValues(alpha: 0.2),
                theme.colorScheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 70, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Settings',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tune Prism to match your mood.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (connected)
                      _buildPillBadge(Icons.check_circle, 'Last.fm linked', theme),
                    if (!connected)
                      _buildPillBadge(Icons.cloud_off, 'Last.fm offline', theme),
                    if (recoMode != null)
                      _buildPillBadge(Icons.auto_awesome, 'Mode: ${recoMode.name}', theme),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillBadge(IconData icon, String text, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    return SettingSectionCard(
      title: 'Account & Services',
      subtitle: 'Manage your connected integrations',
      icon: LucideIcons.user,
      children: [
        if (!_isInitialized)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(width: 20, height: 20, child: ShadProgress()),
                SizedBox(width: 12),
                Text('Initializing...'),
              ],
            ),
          ),
        if (_isInitialized && _lastFmService.isAuthenticated) ...[
          SettingRow(
            leading: const Icon(LucideIcons.checkCheck),
            title: 'Connected',
            subtitle: _lastFmService.username ?? 'Last.fm',
            trailing: ShadButton.ghost(
              onPressed: () async {
                await _lastFmService.logout();
                _forceRebuild();
                if (mounted) ShadToaster.of(context).show(const ShadToast(title: Text('Logged out from Last.fm')));
              },
              size: ShadButtonSize.sm,
              child: const Text('Logout'),
            ),
          ),
          SettingRow(
            leading: const Icon(LucideIcons.history),
            title: 'Scrobbling',
            subtitle: 'Automatically track your listening history',
            trailing: Icon(LucideIcons.circleCheck, color: Colors.green.shade600, size: 20),
          ),
        ],
        if (_isInitialized && !_lastFmService.isAuthenticated)
          SettingRow(
            leading: const Icon(LucideIcons.music),
            title: 'Connect to Last.fm',
            subtitle: 'Track your listening history and get recommendations',
            trailing: ShadButton(
              onPressed: () => SettingsDialogs.showLoginDialog(context, _lastFmService, _forceRebuild),
              size: ShadButtonSize.sm,
              child: const Text('Login'),
            ),
          ),
      ],
    );
  }

  Widget _buildAppExperienceSection() {
    return SettingSectionCard(
      title: 'App Experience',
      subtitle: 'Customize the look, feel, and recommendations',
      icon: LucideIcons.palette,
      children: [
        BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, state) {
            return SettingRow(
              leading: Icon(
                state.themeMode == ThemeMode.dark
                    ? LucideIcons.moon
                    : state.themeMode == ThemeMode.light
                        ? LucideIcons.sun
                        : LucideIcons.sunMoon,
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
        SettingRow(
          leading: const Icon(LucideIcons.disc),
          title: 'Player UI',
          subtitle: _settingsService.playerUiStyle.label,
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => SettingsDialogs.showPlayerUiStyleSheet(context, _settingsService, _forceRebuild),
        ),
        if (_isInitialized)
          SettingRow(
            leading: Text(_settingsService.selectedCountry.flag, style: const TextStyle(fontSize: 24)),
            title: 'Trending Region',
            subtitle: _settingsService.selectedCountry.name,
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => showCountrySelectionSheet(context, _settingsService, _forceRebuild),
          ),
        if (_isInitialized && _recommendationService != null) ...[
          SettingRow(
            leading: const Icon(LucideIcons.sparkles),
            title: 'Recommendation Mode',
            subtitle: _recommendationService!.mode == RecommendationMode.similar 
                ? 'Similar artists & genres' 
                : 'Discover new music',
            trailing: ShadButton.ghost(
              onPressed: () async {
                final newMode = _recommendationService!.mode == RecommendationMode.similar 
                    ? RecommendationMode.discover 
                    : RecommendationMode.similar;
                await _recommendationService!.setMode(newMode);
                _forceRebuild();
              },
              size: ShadButtonSize.sm,
              child: const Text('Toggle'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAudioPlaybackSection() {
    return SettingSectionCard(
      title: 'Audio & Playback',
      subtitle: 'Quality, equalizer, and behavior',
      icon: LucideIcons.audioLines,
      children: [
        BlocBuilder<PlayerBloc, PlayerState>(
          builder: (context, state) {
            final quality = state.audioQuality;
            final subtitle = switch (quality) {
              AudioQuality.low => 'Low (96 kbps)',
              AudioQuality.medium => 'Medium (128 kbps)',
              AudioQuality.high => 'High (192 kbps)',
              AudioQuality.lossless => 'Lossless (FLAC/ALAC)',
            };
            return SettingRow(
              leading: const Icon(LucideIcons.audioWaveform),
              title: 'Audio Quality',
              subtitle: subtitle,
              onTap: () => SettingsDialogs.showAudioQualityDialog(context),
            );
          },
        ),
        SettingRow(
          leading: const Icon(LucideIcons.slidersHorizontal),
          title: 'Equalizer',
          subtitle: 'Customize audio output',
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () {
            showShadSheet(
              context: context,
              side: ShadSheetSide.bottom,
              builder: (context) => EqualizerBottomSheet(
                equalizerService: getIt<AudioPlayerService>().equalizer,
              ),
            );
          },
        ),
        SettingRow(
          leading: const Icon(LucideIcons.zap),
          title: 'Fast Start',
          subtitle: 'Start streams at medium quality for quicker playback',
          trailing: ShadSwitch(
            value: _fastStartEnabled,
            onChanged: (value) async {
              await _settingsService.setFastStartEnabled(value);
              setState(() => _fastStartEnabled = value);
            },
          ),
        ),
        SettingRow(
          leading: const Icon(LucideIcons.cloudDownload),
          title: 'Prefetch Lookahead',
          subtitle: 'Prefetch the next $_prefetchLookahead track(s)',
          trailing: ShadSelect<int>(
            selectedOptionBuilder: (ctx, value) => Text('$value'),
            initialValue: _prefetchLookahead,
            onChanged: (value) async {
              if (value == null) return;
              await _settingsService.setPrefetchLookahead(value);
              setState(() => _prefetchLookahead = value);
            },
            options: const [0, 1, 2]
                .map((v) => ShadOption(value: v, child: Text('$v')))
                .toList(),
            minWidth: 80,
            maxWidth: 100,
          ),
        ),
        SettingRow(
          leading: const Icon(LucideIcons.shuffle),
          title: 'Auto Shuffle',
          subtitle: 'Shuffle queue automatically',
          trailing: ShadSwitch(
            value: _settingsService.autoShuffle,
            onChanged: (value) async {
              await _settingsService.setAutoShuffle(value);
              setState(() {});
            },
          ),
        ),
        SettingRow(
          leading: const Icon(LucideIcons.timer),
          title: 'Crossfade Duration',
          subtitle: 'Smooth transition between songs',
          onTap: () => SettingsDialogs.showCrossfadeDialog(context),
        ),
      ],
    );
  }

  Widget _buildDataStorageSection() {
    return SettingSectionCard(
      title: 'Data & Storage',
      subtitle: 'Downloads and cache management',
      icon: LucideIcons.hardDrive,
      children: [
        SettingRow(
          leading: const Icon(LucideIcons.folderOpen),
          title: 'Download Folder',
          subtitle: _settingsService.downloadFolderPath ?? 'Default',
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => SettingsDialogs.showDownloadFolderDialog(context, _settingsService),
        ),
        SettingRow(
          leading: const Icon(LucideIcons.download),
          title: 'Downloads',
          subtitle: 'Manage downloaded songs',
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DownloadsPage()),
            );
          },
        ),
        SettingRow(
          leading: const Icon(LucideIcons.database),
          title: 'Cache',
          subtitle: 'Clear temporary files',
          onTap: () => SettingsDialogs.showClearCacheDialog(context),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return SettingSectionCard(
      title: 'About',
      subtitle: 'Prism Music information',
      icon: LucideIcons.info,
      children: [
        SettingRow(
          leading: const Icon(LucideIcons.smartphone),
          title: 'Version',
          subtitle: 'Prism Music $_appVersion',
        ),
        SettingRow(
          leading: const Icon(LucideIcons.code),
          title: 'Open Source',
          subtitle: 'View on GitHub',
          trailing: const Icon(LucideIcons.externalLink, size: 16),
          onTap: () async {
            final url = Uri.parse('https://github.com/Jeswanth-009/Prism-Music');
            if (await canLaunchUrl(url)) await launchUrl(url);
          },
        ),
      ],
    );
  }
}
