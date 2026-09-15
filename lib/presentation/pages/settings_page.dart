import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
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
import '../widgets/prism/prism_sheet.dart';
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
      expandedHeight: 190.0,
      floating: false,
      pinned: true,
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.55),
                theme.colorScheme.primary.withValues(alpha: 0.12),
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
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tune Prism to match your mood.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
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
        if (_isInitialized && _lastFmService.isAuthenticated) ...[
          SettingRow(
            leading: const Icon(Icons.check_circle_outline_rounded),
            title: 'Connected',
            subtitle: _lastFmService.username ?? 'Last.fm',
            trailing: TextButton(
              onPressed: () async {
                await _lastFmService.logout();
                _forceRebuild();
                if (mounted) showPrismToast(context, 'Logged out from Last.fm');
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
        if (_isInitialized && !_lastFmService.isAuthenticated)
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
            final subtitle = switch (quality) {
              AudioQuality.low => 'Low (96 kbps)',
              AudioQuality.medium => 'Medium (128 kbps)',
              AudioQuality.high => 'High (192 kbps)',
              AudioQuality.lossless => 'Lossless (FLAC/ALAC)',
            };
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
            ],
            selected: {_prefetchLookahead},
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
          leading: const Icon(Icons.timer_outlined),
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
      icon: Icons.storage_outlined,
      children: [
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
      icon: Icons.info_outline_rounded,
      children: [
        SettingRow(
          leading: const Icon(Icons.smartphone_outlined),
          title: 'Version',
          subtitle: 'Prism Music $_appVersion',
        ),
        SettingRow(
          leading: const Icon(Icons.code_rounded),
          title: 'Open Source',
          subtitle: 'View on GitHub',
          trailing: const Icon(Icons.open_in_new_rounded, size: 18),
          onTap: () async {
            final url =
                Uri.parse('https://github.com/Jeswanth-009/Prism-Music');
            if (await canLaunchUrl(url)) await launchUrl(url);
          },
        ),
      ],
    );
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
