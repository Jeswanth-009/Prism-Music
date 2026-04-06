import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/di/injection.dart';
import '../../core/services/audio_player_service.dart';
import '../../core/services/settings_service.dart';
import 'package:share_plus/share_plus.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../blocs/player/player_state.dart';
import '../blocs/library/library_bloc.dart';
import '../blocs/library/library_event.dart' hide DownloadSongEvent;
import '../widgets/equalizer/equalizer_bottom_sheet.dart';
import 'artist_page.dart';

/// Full screen player page with modern, animated blur background
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage>
    with SingleTickerProviderStateMixin {
  final SettingsService _settingsService = SettingsService.instance;
  Color? _dominantColor;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? _lastImageUrl;
  PlayerUiStyle _playerUiStyle = PlayerUiStyle.classic;
  ValueListenable<dynamic>? _playerUiListenable;

  @override
  void initState() {
    super.initState();
    _initializeSettingsListener();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _playerUiListenable?.removeListener(_handlePlayerUiStyleChanged);
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeSettingsListener() async {
    await _settingsService.initialize();
    _playerUiStyle = _settingsService.playerUiStyle;
    _playerUiListenable = _settingsService.playerUiStyleListenable();
    _playerUiListenable?.addListener(_handlePlayerUiStyleChanged);
    if (mounted) setState(() {});
  }

  void _handlePlayerUiStyleChanged() {
    if (!mounted) return;
    setState(() {
      _playerUiStyle = _settingsService.playerUiStyle;
    });
  }

  void _openArtistPage(String artistName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArtistPage(
          artistName: artistName,
          heroTag: 'player_artist_${artistName.hashCode}',
        ),
      ),
    );
  }

  Future<void> _extractDominantColor(String imageUrl) async {
    if (imageUrl == _lastImageUrl) return;
    _lastImageUrl = imageUrl;

    try {
      final imageProvider = CachedNetworkImageProvider(imageUrl);
      final paletteGenerator =
          await PaletteGenerator.fromImageProvider(imageProvider);

      if (mounted) {
        setState(() {
          _dominantColor = paletteGenerator.dominantColor?.color ??
              paletteGenerator.vibrantColor?.color ??
              paletteGenerator.mutedColor?.color;
        });
        _animationController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) setState(() => _dominantColor = null);
    }
  }

  // ── build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerBloc, PlayerState>(
      builder: (context, state) {
        final song = state.currentSong;
        if (song == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.music,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  const Text('No song playing'),
                ],
              ),
            ),
          );
        }

        if (song.thumbnailUrl.isNotEmpty) {
          _extractDominantColor(song.thumbnailUrl);
        }

        final theme = Theme.of(context);
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        if (_playerUiStyle == PlayerUiStyle.modern) {
          return _buildModernPlayer(
            context: context,
            theme: theme,
            state: state,
            song: song,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          );
        }

        return _buildClassicPlayer(
          context: context,
          theme: theme,
          state: state,
          song: song,
          screenWidth: screenWidth,
          screenHeight: screenHeight,
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════
  //  CLASSIC PLAYER
  // ════════════════════════════════════════════════════════════════════

  Widget _buildClassicPlayer({
    required BuildContext context,
    required ThemeData theme,
    required PlayerState state,
    required dynamic song,
    required double screenWidth,
    required double screenHeight,
  }) {
    final isTablet = screenWidth > 600;
    final isLandscape = screenWidth > screenHeight;

    double artSize;
    if (isTablet) {
      artSize = isLandscape ? screenHeight * 0.45 : 320.0;
    } else {
      artSize = (screenWidth * 0.72).clamp(220.0, 320.0);
    }

    final maxArtHeight = screenHeight * 0.40;
    if (artSize > maxArtHeight) artSize = maxArtHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _buildAnimatedBackground(song, theme),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isTablet ? 500 : double.infinity,
                ),
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: isTablet ? 32 : 24),
                  child: Column(
                    children: [
                      _buildHeader(context, theme),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              SizedBox(
                                  height: isTablet
                                      ? 24
                                      : screenHeight * 0.03),
                              _buildClassicAlbumArt(
                                  context, theme, song, artSize),
                              SizedBox(
                                  height: isTablet
                                      ? 28
                                      : screenHeight * 0.03),
                              _buildClassicSongInfo(
                                  context, theme, song),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildClassicProgressBar(context, theme, state),
                          const SizedBox(height: 20),
                          _buildClassicControls(context, theme, state),
                          const SizedBox(height: 16),
                          _buildClassicExtraControls(
                              context, theme, state),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground(dynamic song, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Stack(
      children: [
        // Base gradient
        AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      (_dominantColor ?? theme.colorScheme.primary)
                          .withOpacity(0.25),
                      theme.colorScheme.surface,
                      theme.colorScheme.surfaceContainerLowest,
                    ]
                  : [
                      (_dominantColor ?? theme.colorScheme.primary)
                          .withOpacity(0.15),
                      theme.colorScheme.surface,
                      theme.colorScheme.surfaceContainerLowest,
                    ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        // Blur overlay with dominant color glow
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.3),
                      radius: 1.2,
                      colors: [
                        (_dominantColor ?? theme.colorScheme.primary)
                            .withOpacity(0.08 * _fadeAnimation.value),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Subtle noise texture effect (simulated with gradient)
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(isDark ? 0.05 : 0.02),
                    Colors.transparent,
                    Colors.black.withOpacity(isDark ? 0.08 : 0.03),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Down button with glassmorphism
          _GlassButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: LucideIcons.chevronDown,
            isDark: isDark,
          ),
          const Spacer(),
          // Now Playing label
          Column(
            children: [
              Text(
                'NOW PLAYING',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 32,
                height: 2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1),
                  color: _dominantColor ?? theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              _GlassButton(
                onPressed: () => _showEqualizerSheet(context),
                icon: LucideIcons.audioLines,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _GlassButton(
                onPressed: () => _showOptionsMenu(context),
                icon: LucideIcons.ellipsisVertical,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClassicAlbumArt(
    BuildContext context,
    ThemeData theme,
    dynamic song,
    double artSize,
  ) {
    final accentColor = _dominantColor ?? theme.colorScheme.primary;
    
    return Hero(
      tag: 'album_art_${song.youtubeId ?? song.id}',
      child: Container(
        width: artSize,
        height: artSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            // Primary glow shadow
            BoxShadow(
              color: accentColor.withOpacity(0.5),
              blurRadius: 50,
              spreadRadius: 5,
              offset: const Offset(0, 15),
            ),
            // Secondary ambient shadow
            BoxShadow(
              color: accentColor.withOpacity(0.3),
              blurRadius: 80,
              spreadRadius: 0,
              offset: const Offset(0, 30),
            ),
            // Dark shadow for depth
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 25,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Main album art
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
              ),
              child: song.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: song.thumbnailUrl,
                      fit: BoxFit.cover,
                      width: artSize,
                      height: artSize,
                      placeholder: (context, url) => _buildLoadingArt(theme, artSize),
                      errorWidget: (context, url, error) =>
                          _buildPlaceholderIcon(theme, artSize),
                    )
                  : _buildPlaceholderIcon(theme, artSize),
            ),
            // Subtle inner border for polish
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            // Light reflection effect at top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: artSize * 0.3,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLoadingArt(ThemeData theme, double artSize) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: Center(
        child: SizedBox(
          width: artSize * 0.2,
          height: artSize * 0.2,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon(ThemeData theme, double artSize) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: Icon(
        LucideIcons.music,
        size: artSize * 0.45,
        color: theme.colorScheme.onPrimaryContainer.withOpacity(0.5),
      ),
    );
  }

  Widget _buildClassicSongInfo(
      BuildContext context, ThemeData theme, dynamic song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Text(
            song.title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openArtistPage(song.artist),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.user,
                      size: 14, color: theme.colorScheme.onSurface),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    song.artist,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      decoration: TextDecoration.underline,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassicProgressBar(
    BuildContext context,
    ThemeData theme,
    PlayerState state,
  ) {
    final position = state.position;
    final duration = state.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;
    final accentColor = _dominantColor ?? theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // Custom progress slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: _GlowingThumbShape(
                color: accentColor,
                thumbRadius: 7,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: accentColor,
              inactiveTrackColor: isDark
                  ? Colors.white.withOpacity(0.15)
                  : Colors.black.withOpacity(0.1),
              overlayColor: accentColor.withOpacity(0.2),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (value) {
                final newPosition = Duration(
                  milliseconds: (value * duration.inMilliseconds).round(),
                );
                context.read<PlayerBloc>().add(SeekEvent(newPosition));
              },
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TimeLabel(
                  time: _formatDuration(position),
                  theme: theme,
                ),
                // Remaining time (negative)
                _TimeLabel(
                  time: '-${_formatDuration(duration - position)}',
                  theme: theme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassicControls(
    BuildContext context,
    ThemeData theme,
    PlayerState state,
  ) {
    final accentColor = _dominantColor ?? theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Previous button
          _AnimatedControlButton(
            icon: LucideIcons.skipBack,
            size: 28,
            enabled: state.hasPrevious || state.position.inSeconds > 3,
            isDark: isDark,
            onPressed: state.hasPrevious || state.position.inSeconds > 3
                ? () => context.read<PlayerBloc>().add(const PreviousEvent())
                : null,
          ),

          // Play/Pause button (large, prominent)
          _PlayPauseMainButton(
            isPlaying: state.isPlaying,
            isBuffering: state.isBuffering,
            accentColor: accentColor,
            onPressed: state.isBuffering
                ? null
                : () {
                    if (state.isPlaying) {
                      context.read<PlayerBloc>().add(const PauseEvent());
                    } else {
                      context.read<PlayerBloc>().add(const ResumeEvent());
                    }
                  },
          ),

          // Next button
          _AnimatedControlButton(
            icon: LucideIcons.skipForward,
            size: 28,
            enabled: state.hasNext,
            isDark: isDark,
            onPressed: state.hasNext
                ? () => context.read<PlayerBloc>().add(const NextEvent())
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildClassicExtraControls(
    BuildContext context,
    ThemeData theme,
    PlayerState state,
  ) {
    final accentColor = _dominantColor ?? theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _PillButton(
            icon: LucideIcons.shuffle,
            active: state.isShuffleEnabled,
            accentColor: accentColor,
            isDark: isDark,
            onPressed: () => context
                .read<PlayerBloc>()
                .add(const ToggleShuffleEvent()),
          ),
          _PillButton(
            icon: state.repeatMode == RepeatMode.one
                ? LucideIcons.repeat1
                : LucideIcons.repeat,
            active: state.repeatMode != RepeatMode.off,
            accentColor: accentColor,
            isDark: isDark,
            onPressed: () => context
                .read<PlayerBloc>()
                .add(const CycleRepeatModeEvent()),
          ),
          _PillButton(
            icon: LucideIcons.listMusic,
            active: false,
            accentColor: accentColor,
            isDark: isDark,
            onPressed: () => _showQueue(context, state),
          ),
          _PillButton(
            icon: LucideIcons.heart,
            active: false,
            accentColor: accentColor,
            isDark: isDark,
            onPressed: () {
              ShadToaster.of(context).show(
                ShadToast(
                  title: const Text('Added to Liked Songs'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  //  MODERN PLAYER
  // ════════════════════════════════════════════════════════════════════

  Widget _buildModernPlayer({
    required BuildContext context,
    required ThemeData theme,
    required PlayerState state,
    required dynamic song,
    required double screenWidth,
    required double screenHeight,
  }) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (_dominantColor ?? const Color(0xFF7C4DFF))
                  .withOpacity(0.9),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dialSize = _computeDialSize(
                  constraints.maxWidth, constraints.maxHeight);
              final progress = state.progress;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child:
                        _buildModernHeader(context, theme, song),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20),
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 24),
                            _buildModernAlbumDial(
                              context: context,
                              theme: theme,
                              song: song,
                              state: state,
                              dialSize: dialSize,
                              progress: progress,
                            ),
                            const SizedBox(height: 24),
                            _buildModernSongMeta(theme, song),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: _buildModernUtilityRow(context, theme),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  double _computeDialSize(double maxWidth, double maxHeight) {
    final base = math.min(maxWidth, maxHeight) * 0.58;
    const minSize = 220.0;
    final maxSize = math.max(minSize + 40, maxWidth - 32);
    return base.clamp(minSize, maxSize).toDouble();
  }

  Widget _buildModernHeader(
      BuildContext context, ThemeData theme, dynamic song) {
    return Row(
      children: [
        ShadIconButton.ghost(
          icon: const Icon(LucideIcons.chevronDown,
              color: Colors.white, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                song.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              GestureDetector(
                onTap: () => _openArtistPage(song.artist),
                child: Text(
                  song.artist,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    letterSpacing: 0.4,
                    decoration: TextDecoration.underline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        ShadIconButton.ghost(
          icon: const Icon(LucideIcons.heart,
              color: Colors.white, size: 20),
          onPressed: () {
            ShadToaster.of(context).show(
              ShadToast(title: const Text('Added to Liked Songs')),
            );
          },
        ),
        ShadIconButton.ghost(
          icon: const Icon(LucideIcons.ellipsisVertical,
              color: Colors.white, size: 20),
          onPressed: () => _showOptionsMenu(context),
        ),
      ],
    );
  }

  Widget _buildModernAlbumDial({
    required BuildContext context,
    required ThemeData theme,
    required dynamic song,
    required PlayerState state,
    required double dialSize,
    required double progress,
  }) {
    final prevSong = _neighborSong(state, -1);
    final nextSong = _neighborSong(state, 1);
    final controlDistance = dialSize / 2 + 54;

    Widget ringButton({
      required double angle,
      required Widget child,
    }) {
      final radians = angle * math.pi / 180;
      return Transform.translate(
        offset: Offset(
          controlDistance * math.cos(radians),
          controlDistance * math.sin(radians),
        ),
        child: child,
      );
    }

    Widget controlChip({
      required IconData icon,
      bool active = false,
      bool enabled = true,
      VoidCallback? onTap,
    }) {
      return Opacity(
        opacity: enabled ? 1 : 0.35,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? Colors.white
                  : Colors.white.withOpacity(0.08),
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon,
                color: active ? Colors.black : Colors.white),
          ),
        ),
      );
    }

    Widget primaryControl({
      required IconData icon,
      required VoidCallback? onTap,
      bool isBuffering = false,
    }) {
      return GestureDetector(
        onTap: isBuffering ? null : onTap,
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF9C27B0), Color(0xFF7C4DFF)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.purpleAccent.withOpacity(0.45),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Center(
            child: isBuffering
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: ShadProgress(color: Colors.white),
                  )
                : Icon(icon, color: Colors.white, size: 38),
          ),
        ),
      );
    }

    return SizedBox(
      height: dialSize + 200,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (prevSong != null)
            Align(
              alignment: Alignment.centerLeft,
              child: _buildOrbitingCover(
                  theme, prevSong, dialSize * 0.45, -18),
            ),
          if (nextSong != null)
            Align(
              alignment: Alignment.centerRight,
              child: _buildOrbitingCover(
                  theme, nextSong, dialSize * 0.45, 18),
            ),
          SizedBox(
            width: dialSize,
            height: dialSize,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanDown: (details) => _seekFromDial(
                  context, details.localPosition, dialSize, state),
              onPanUpdate: (details) => _seekFromDial(
                  context, details.localPosition, dialSize, state),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    size: Size(dialSize, dialSize),
                    painter: _ModernRingPainter(
                      progress: progress.clamp(0.0, 1.0),
                      color: _dominantColor ??
                          theme.colorScheme.primary,
                    ),
                  ),
                  GestureDetector(
                    onTap: state.isBuffering
                        ? null
                        : () {
                            if (state.isPlaying) {
                              context
                                  .read<PlayerBloc>()
                                  .add(const PauseEvent());
                            } else {
                              context
                                  .read<PlayerBloc>()
                                  .add(const ResumeEvent());
                            }
                          },
                    child: Container(
                      width: dialSize * 0.68,
                      height: dialSize * 0.68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_dominantColor ?? Colors.black)
                                    .withOpacity(0.4),
                            blurRadius: 40,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (song.thumbnailUrl.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: song.thumbnailUrl,
                              fit: BoxFit.cover,
                            )
                          else
                            Container(
                              color: theme
                                  .colorScheme.primaryContainer,
                              child: Icon(
                                LucideIcons.music,
                                color: theme.colorScheme
                                    .onPrimaryContainer,
                                size: dialSize * 0.25,
                              ),
                            ),
                          if (state.isBuffering)
                            const Center(
                              child: ShadProgress(
                                  color: Colors.white),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.positionFormatted,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(
                              color: Colors.white,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8),
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white38,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            state.durationFormatted,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(
                              color: Colors.white,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ringButton(
            angle: -120,
            child: controlChip(
              icon: LucideIcons.shuffle,
              active: state.isShuffleEnabled,
              onTap: () => context
                  .read<PlayerBloc>()
                  .add(const ToggleShuffleEvent()),
            ),
          ),
          ringButton(
            angle: -180,
            child: controlChip(
              icon: LucideIcons.skipBack,
              enabled:
                  state.hasPrevious || state.position.inSeconds > 3,
              onTap: () {
                if (state.hasPrevious ||
                    state.position.inSeconds > 3) {
                  context
                      .read<PlayerBloc>()
                      .add(const PreviousEvent());
                }
              },
            ),
          ),
          ringButton(
            angle: 90,
            child: primaryControl(
              icon: state.isPlaying
                  ? LucideIcons.pause
                  : LucideIcons.play,
              isBuffering: state.isBuffering,
              onTap: () {
                if (state.isPlaying) {
                  context
                      .read<PlayerBloc>()
                      .add(const PauseEvent());
                } else {
                  context
                      .read<PlayerBloc>()
                      .add(const ResumeEvent());
                }
              },
            ),
          ),
          ringButton(
            angle: 0,
            child: controlChip(
              icon: LucideIcons.skipForward,
              enabled: state.hasNext,
              onTap: () {
                if (state.hasNext) {
                  context
                      .read<PlayerBloc>()
                      .add(const NextEvent());
                }
              },
            ),
          ),
          ringButton(
            angle: -60,
            child: controlChip(
              icon: state.repeatMode == RepeatMode.one
                  ? LucideIcons.repeat1
                  : LucideIcons.repeat,
              active: state.repeatMode != RepeatMode.off,
              onTap: () => context
                  .read<PlayerBloc>()
                  .add(const CycleRepeatModeEvent()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrbitingCover(
    ThemeData theme,
    dynamic song,
    double size,
    double angle,
  ) {
    return Transform.rotate(
      angle: angle * math.pi / 180,
      child: Opacity(
        opacity: 0.85,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withOpacity(0.2), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: song.thumbnailUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: song.thumbnailUrl, fit: BoxFit.cover)
              : Container(
                  color: theme.colorScheme.secondaryContainer,
                  child: Icon(LucideIcons.disc,
                      color:
                          theme.colorScheme.onSecondaryContainer),
                ),
        ),
      ),
    );
  }

  Widget _buildModernSongMeta(ThemeData theme, dynamic song) {
    return Column(
      children: [
        Text(
          song.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _openArtistPage(song.artist),
          child: Text(
            song.artist,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white70,
              decoration: TextDecoration.underline,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildModernUtilityRow(
      BuildContext context, ThemeData theme) {
    return BlocBuilder<PlayerBloc, PlayerState>(
      builder: (context, state) {
        final currentSong = state.currentSong;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _modernUtilityButton(
              icon: LucideIcons.audioLines,
              label: 'EQ',
              onTap: () => _showEqualizerSheet(context),
            ),
            _modernUtilityButton(
              icon: LucideIcons.listMusic,
              label: 'Queue',
              onTap: () {
                final state = context.read<PlayerBloc>().state;
                _showQueue(context, state);
              },
            ),
            _modernUtilityButton(
              icon: LucideIcons.download,
              label: 'Download',
              onTap: currentSong == null
                  ? null
                  : () async {
                      context.read<PlayerBloc>().add(
                            DownloadSongEvent(currentSong),
                          );
                      final downloadPath =
                          SettingsService.instance.downloadFolderPath;
                      final displayPath = downloadPath ??
                          'App Documents/downloads';

                      ShadToaster.of(context).show(
                        ShadToast(
                          title: Text(
                              'Downloading "${currentSong.title}"...'),
                          description:
                              Text('Location: $displayPath'),
                        ),
                      );

                      Future.delayed(const Duration(seconds: 2), () {
                        if (context.mounted) {
                          context.read<LibraryBloc>().add(const LoadLibraryEvent());
                        }
                      });
                    },
            ),
            _modernUtilityButton(
              icon: LucideIcons.share2,
              label: 'Share',
              onTap: currentSong == null
                  ? null
                  : () {
                      final videoId = currentSong.youtubeId ?? currentSong.id;
                      final url = 'https://music.youtube.com/watch?v=$videoId';
                      Share.share('${currentSong.title} - ${currentSong.artist}\n$url');
                    },
            ),
          ],
        );
      },
    );
  }

  Widget _modernUtilityButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  Colors.white.withOpacity(isEnabled ? 0.1 : 0.05),
              border: Border.all(
                color: isEnabled ? Colors.white24 : Colors.white12,
              ),
            ),
            child: Icon(icon,
                color:
                    Colors.white.withOpacity(isEnabled ? 1.0 : 0.3)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color:
                Colors.white70.withOpacity(isEnabled ? 1.0 : 0.5),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ── shared helpers ───────────────────────────────────────────────────

  void _seekFromDial(
    BuildContext context,
    Offset localPosition,
    double dialSize,
    PlayerState state,
  ) {
    final totalMs = state.duration.inMilliseconds;
    if (totalMs <= 0) return;

    final center = Offset(dialSize / 2, dialSize / 2);
    final vector = localPosition - center;
    final distance = vector.distance;
    final innerRadius = dialSize * 0.3;
    final outerRadius = dialSize * 0.55;

    if (distance < innerRadius || distance > outerRadius) return;

    const startAngle = -math.pi / 2;
    double angle = math.atan2(vector.dy, vector.dx);
    double normalized = angle - startAngle;
    while (normalized < 0) normalized += math.pi * 2;
    while (normalized > math.pi * 2) normalized -= math.pi * 2;

    final progress =
        (normalized / (math.pi * 2)).clamp(0.0, 1.0);
    final targetMs =
        (progress * totalMs).clamp(0.0, totalMs.toDouble());

    context.read<PlayerBloc>().add(
          SeekEvent(Duration(milliseconds: targetMs.round())),
        );
  }

  dynamic _neighborSong(PlayerState state, int offset) {
    final targetIndex = state.queueIndex + offset;
    if (targetIndex >= 0 && targetIndex < state.queue.length) {
      return state.queue[targetIndex];
    }
    return null;
  }

  void _showEqualizerSheet(BuildContext context) {
    final audioPlayerService = getIt<AudioPlayerService>();

    showShadSheet(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (context) => EqualizerBottomSheet(
        equalizerService: audioPlayerService.equalizer,
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showShadSheet(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (ctx) {
        return ShadSheet(
          title: const Text('Song Options'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetAction(
                icon: LucideIcons.listPlus,
                label: 'Add to playlist',
                onTap: () {
                  Navigator.pop(ctx);
                  ShadToaster.of(context).show(
                    ShadToast(
                        title: const Text('Coming soon!')),
                  );
                },
              ),
              BlocBuilder<PlayerBloc, PlayerState>(
                builder: (context, playerState) {
                  final currentSong = playerState.currentSong;
                  return _SheetAction(
                    icon: LucideIcons.download,
                    label: 'Download',
                    onTap: currentSong == null
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            context.read<PlayerBloc>().add(
                                  DownloadSongEvent(currentSong),
                                );
                            ShadToaster.of(context).show(
                              ShadToast(
                                title: Text(
                                    'Downloading "${currentSong.title}"...'),
                              ),
                            );
                          },
                  );
                },
              ),
              _SheetAction(
                icon: LucideIcons.share2,
                label: 'Share',
                onTap: () {
                  Navigator.pop(ctx);
                  final playerState = context.read<PlayerBloc>().state;
                  final song = playerState.currentSong;
                  if (song != null) {
                    final videoId = song.youtubeId ?? song.id;
                    final url = 'https://music.youtube.com/watch?v=$videoId';
                    Share.share('${song.title} - ${song.artist}\n$url');
                  }
                },
              ),
              _SheetAction(
                icon: LucideIcons.info,
                label: 'Song info',
                onTap: () {
                  Navigator.pop(ctx);
                  ShadToaster.of(context).show(
                    ShadToast(
                        title: const Text('Coming soon!')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQueue(BuildContext context, PlayerState state) {
    showShadSheet(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (ctx) {
        return ShadSheet(
          title: const Text('Queue'),
          actions: [
            ShadButton.ghost(
              onPressed: () {
                context
                    .read<PlayerBloc>()
                    .add(const ClearQueueEvent());
                Navigator.pop(ctx);
              },
              size: ShadButtonSize.sm,
              child: const Text('Clear'),
            ),
          ],
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: ListView.builder(
              itemCount: state.queue.length,
              itemBuilder: (context, index) {
                final song = state.queue[index];
                final isPlaying = index == state.queueIndex;

                return GestureDetector(
                  onTap: isPlaying
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          context.read<PlayerBloc>().add(
                                PlaySongEvent(
                                  song: song,
                                  queue: state.queue,
                                  queueIndex: index,
                                ),
                              );
                        },
                  child: ShadCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: song.thumbnailUrl.isNotEmpty
                              ? Image.network(
                                  song.thumbnailUrl,
                                  fit: BoxFit.cover)
                              : const Icon(LucideIcons.music),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              style: TextStyle(
                                fontWeight: isPlaying
                                    ? FontWeight.bold
                                    : null,
                                color: isPlaying
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              song.artist,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (isPlaying)
                        Icon(LucideIcons.audioLines,
                            color: Theme.of(context)
                                .colorScheme
                                .primary,
                            size: 18)
                      else
                        ShadIconButton.ghost(
                          icon: const Icon(LucideIcons.x,
                              size: 16),
                          width: 32,
                          height: 32,
                          onPressed: () {
                            context.read<PlayerBloc>().add(
                                  RemoveFromQueueEvent(index),
                                );
                          },
                        ),
                    ],
                  ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

// ════════════════════════════════════════════════════════════════════════
// Sheet action helper
// ════════════════════════════════════════════════════════════════════════

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SheetAction({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ShadButton.ghost(
      onPressed: onTap,
      leading: Icon(icon, size: 18),
      width: double.infinity,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(label),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Custom ring painter (preserved from original)
// ════════════════════════════════════════════════════════════════════════

class _ModernRingPainter extends CustomPainter {
  const _ModernRingPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 14.0;
    final rect = Offset.zero & size;
    const startAngle = -math.pi / 2;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.white.withOpacity(0.08);

    canvas.drawArc(
        rect.deflate(strokeWidth / 2), 0, math.pi * 2, false, basePaint);

    final gradientPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + math.pi * 2,
        colors: [color, Colors.white],
      ).createShader(rect)
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      startAngle,
      math.pi * 2 * progress,
      false,
      gradientPaint,
    );

    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.white.withOpacity(0.05);

    canvas.drawArc(
        rect.deflate(22), 0, math.pi * 2, false, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _ModernRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color;
  }
}

// ════════════════════════════════════════════════════════════════════════
// Glass button for header
// ════════════════════════════════════════════════════════════════════════

class _GlassButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final bool isDark;

  const _GlassButton({
    required this.onPressed,
    required this.icon,
    required this.isDark,
  });

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: widget.isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
                border: Border.all(
                  color: widget.isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.08),
                ),
              ),
              child: Icon(
                widget.icon,
                size: 20,
                color: widget.isDark
                    ? Colors.white.withOpacity(0.8)
                    : Colors.black.withOpacity(0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Time label widget
// ════════════════════════════════════════════════════════════════════════

class _TimeLabel extends StatelessWidget {
  final String time;
  final ThemeData theme;

  const _TimeLabel({required this.time, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      ),
      child: Text(
        time,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.7),
          fontWeight: FontWeight.w600,
          fontFeatures: [const FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Custom glowing slider thumb
// ════════════════════════════════════════════════════════════════════════

class _GlowingThumbShape extends SliderComponentShape {
  final Color color;
  final double thumbRadius;

  const _GlowingThumbShape({
    required this.color,
    required this.thumbRadius,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // Glow effect
    final glowPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, thumbRadius + 4, glowPaint);

    // Thumb fill
    final thumbPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, thumbRadius, thumbPaint);

    // White center
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, thumbRadius * 0.4, centerPaint);
  }
}

// ════════════════════════════════════════════════════════════════════════
// Animated control button (skip, etc)
// ════════════════════════════════════════════════════════════════════════

class _AnimatedControlButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final bool enabled;
  final bool isDark;
  final VoidCallback? onPressed;

  const _AnimatedControlButton({
    required this.icon,
    required this.size,
    required this.enabled,
    required this.isDark,
    this.onPressed,
  });

  @override
  State<_AnimatedControlButton> createState() => _AnimatedControlButtonState();
}

class _AnimatedControlButtonState extends State<_AnimatedControlButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _controller.forward() : null,
      onTapUp: widget.enabled
          ? (_) {
              _controller.reverse();
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
            border: Border.all(
              color: widget.isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.black.withOpacity(0.1),
            ),
          ),
          child: Icon(
            widget.icon,
            size: widget.size,
            color: widget.enabled
                ? (widget.isDark ? Colors.white : Colors.black87)
                : (widget.isDark ? Colors.white24 : Colors.black26),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Main play/pause button
// ════════════════════════════════════════════════════════════════════════

class _PlayPauseMainButton extends StatefulWidget {
  final bool isPlaying;
  final bool isBuffering;
  final Color accentColor;
  final VoidCallback? onPressed;

  const _PlayPauseMainButton({
    required this.isPlaying,
    required this.isBuffering,
    required this.accentColor,
    this.onPressed,
  });

  @override
  State<_PlayPauseMainButton> createState() => _PlayPauseMainButtonState();
}

class _PlayPauseMainButtonState extends State<_PlayPauseMainButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isBuffering ? null : (_) => _controller.forward(),
      onTapUp: widget.isBuffering
          ? null
          : (_) {
              _controller.reverse();
              widget.onPressed?.call();
            },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.accentColor,
                widget.accentColor.withOpacity(0.85),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: widget.accentColor.withOpacity(0.3),
                blurRadius: 50,
                spreadRadius: -5,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Inner highlight
              Positioned(
                top: 4,
                left: 10,
                right: 10,
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(44),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.25),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Icon
              widget.isBuffering
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        widget.isPlaying
                            ? LucideIcons.pause
                            : LucideIcons.play,
                        key: ValueKey(widget.isPlaying),
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Pill button for extra controls (shuffle, repeat, etc)
// ════════════════════════════════════════════════════════════════════════

class _PillButton extends StatefulWidget {
  final IconData icon;
  final bool active;
  final Color accentColor;
  final bool isDark;
  final VoidCallback onPressed;

  const _PillButton({
    required this.icon,
    required this.active,
    required this.accentColor,
    required this.isDark,
    required this.onPressed,
  });

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: widget.active
                ? widget.accentColor.withOpacity(0.2)
                : (widget.isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.05)),
            border: Border.all(
              color: widget.active
                  ? widget.accentColor.withOpacity(0.4)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Icon(
            widget.icon,
            size: 20,
            color: widget.active
                ? widget.accentColor
                : (widget.isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ),
    );
  }
}
