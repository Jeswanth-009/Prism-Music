import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../core/error/error_message_mapper.dart';
import '../../core/services/settings_service.dart';
import '../../domain/entities/song.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../blocs/player/player_state.dart';
import '../theme/prism_theme.dart';
import '../widgets/common/adaptive_layout.dart';
import '../widgets/player/layouts/classic_player_layout.dart';
import '../widgets/player/layouts/landscape_player_layout.dart';
import '../widgets/player/layouts/vinyl_player_layout.dart';
import '../widgets/player/player_action_bar.dart';
import '../widgets/player/player_ambient_background.dart';
import '../widgets/player/player_artwork_section.dart';
import '../widgets/player/player_controls_section.dart';
import '../widgets/player/player_lyrics_sheet.dart';
import '../widgets/player/player_metadata_row.dart';
import '../widgets/player/player_sheets.dart';
import '../widgets/player/player_slider_widget.dart';
import '../widgets/prism/prism_states.dart';
import 'artist_page.dart';

// Export for backward compatibility with existing tests
export '../widgets/player/layouts/vinyl_player_layout.dart'
    show AudiophileTonearm, VinylPlayerLayout;
export '../widgets/player/layouts/classic_player_layout.dart'
    show ClassicPlayerLayout;
export '../widgets/player/layouts/landscape_player_layout.dart'
    show LandscapePlayerLayout;
export '../widgets/player/player_action_bar.dart';
export '../widgets/player/player_ambient_background.dart';
export '../widgets/player/player_artwork_section.dart';
export '../widgets/player/player_controls_section.dart';
export '../widgets/player/player_metadata_row.dart';
export '../widgets/player/player_sheets.dart';
export '../widgets/player/player_slider_widget.dart';

/// Full-screen immersive player. Artwork colour drives the ambient
/// background; controls stay quiet and centred.
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  static final Map<String, Color?> _paletteCache = {};
  Color? _dominantColor;
  bool _showLyrics = false;
  String? _lastSongId;
  int _colorExtractionGen = 0;

  @override
  void initState() {
    super.initState();
    final currentSong = context.read<PlayerBloc>().state.currentSong;
    if (currentSong != null) {
      _extractDominantColor(currentSong);
    }
  }

  void _openArtistPage(String artistName) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ArtistPage(artistName: artistName)),
    );
  }

  Future<void> _extractDominantColor(Song song) async {
    final songId = song.playableId;
    if (songId == _lastSongId) return;
    _lastSongId = songId;

    final cached = _paletteCache[songId];
    if (cached != null) {
      if (mounted) setState(() => _dominantColor = cached);
      return;
    }

    final imageUrl = song.thumbnailUrl;
    if (imageUrl.isEmpty) {
      if (mounted) setState(() => _dominantColor = null);
      return;
    }

    final gen = ++_colorExtractionGen;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(imageUrl),
      );
      if (!mounted || gen != _colorExtractionGen) return;
      final extracted = palette.dominantColor?.color ??
          palette.vibrantColor?.color ??
          palette.mutedColor?.color;
      _paletteCache[songId] = extracted;
      setState(() => _dominantColor = extracted);
    } catch (_) {
      if (mounted && gen == _colorExtractionGen) {
        setState(() => _dominantColor = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PlayerBloc, PlayerState>(
      listenWhen: (prev, curr) =>
          prev.currentSong?.playableId != curr.currentSong?.playableId,
      listener: (context, state) {
        if (state.currentSong != null) {
          _extractDominantColor(state.currentSong!);
        }
      },
      builder: (context, state) {
        final song = state.currentSong;
        if (song == null) {
          return const Scaffold(
            body: PrismEmptyState(
              icon: Icons.music_note_rounded,
              message: 'No song playing',
            ),
          );
        }

        final theme = Theme.of(context);
        final isTablet = MediaQuery.sizeOf(context).width > 600;
        final style = SettingsService.instance.playerUiStyle;

        return Scaffold(
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              PlayerAmbientBackground(dominantColor: _dominantColor),
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(context, theme, song),
                    if (state.errorMessage != null &&
                        state.status == PlayerStatus.error)
                      _buildErrorBanner(context, theme, song, state),
                    if (AdaptiveBreakpoints.isLandscape(context) || (AdaptiveBreakpoints.isTablet(context) && MediaQuery.sizeOf(context).aspectRatio > 1.1))
                      Expanded(
                        child: LandscapePlayerLayout(
                          song: song,
                          state: state,
                          dominantColor: _dominantColor,
                          showLyrics: _showLyrics,
                          onToggleLyrics: () =>
                              setState(() => _showLyrics = !_showLyrics),
                          onArtistTap: _openArtistPage,
                          onProvenanceTap: () => showPlayerStreamDetailsSheet(
                            context,
                            song,
                            state.currentStreamInfo,
                          ),
                        ),
                      )
                    else if (style == PlayerUiStyle.classic)
                      Expanded(
                        child: ClassicPlayerLayout(
                          song: song,
                          state: state,
                          showLyrics: _showLyrics,
                          onToggleLyrics: () =>
                              setState(() => _showLyrics = !_showLyrics),
                          onArtistTap: _openArtistPage,
                          onProvenanceTap: () => showPlayerStreamDetailsSheet(
                            context,
                            song,
                            state.currentStreamInfo,
                          ),
                        ),
                      )
                    else if (style == PlayerUiStyle.vinyl)
                      Expanded(
                        child: VinylPlayerLayout(
                          song: song,
                          state: state,
                          showLyrics: _showLyrics,
                          onToggleLyrics: () =>
                              setState(() => _showLyrics = !_showLyrics),
                          onArtistTap: _openArtistPage,
                          onProvenanceTap: () => showPlayerStreamDetailsSheet(
                            context,
                            song,
                            state.currentStreamInfo,
                          ),
                        ),
                      )
                    else ...[
                      // Modern Default Layout
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: PrismMotion.base,
                          child: _showLyrics
                              ? PlayerLyricsView(
                                  key: ValueKey('lyrics_${song.id}'),
                                  song: song,
                                )
                              : SingleChildScrollView(
                                  key: const ValueKey('artwork'),
                                  physics: const BouncingScrollPhysics(),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: 0,
                                      maxWidth:
                                          isTablet ? 500 : double.infinity,
                                    ),
                                    child: Column(
                                      children: [
                                        const SizedBox(height: 12),
                                        PlayerArtworkSection(
                                          song: song,
                                          dominantColor: _dominantColor,
                                        ),
                                        const SizedBox(height: 28),
                                        PlayerMetadataRow(
                                          song: song,
                                          streamInfo: state.currentStreamInfo,
                                          onArtistTap: _openArtistPage,
                                          onProvenanceTap: () =>
                                              showPlayerStreamDetailsSheet(
                                            context,
                                            song,
                                            state.currentStreamInfo,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      PlayerSliderWidget(state: state),
                      const SizedBox(height: 12),
                      PlayerControlsSection(state: state),
                      const SizedBox(height: 8),
                      PlayerActionBar(
                        song: song,
                        state: state,
                        showLyrics: _showLyrics,
                        onToggleLyrics: () =>
                            setState(() => _showLyrics = !_showLyrics),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, Song song) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 26),
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                _showLyrics ? 'LYRICS' : 'NOW PLAYING',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: .55),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 28,
                height: 2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1),
                  color: _dominantColor ?? theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => showPlayerEqualizerSheet(context),
            tooltip: 'Equalizer',
            icon: const Icon(Icons.equalizer_rounded),
          ),
          IconButton(
            onPressed: () => showPlayerOptionsMenu(context, song),
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(
    BuildContext context,
    ThemeData theme,
    Song song,
    PlayerState state,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(PrismRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: theme.colorScheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ErrorMessageMapper.map(state.errorMessage!),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              context.read<PlayerBloc>().add(
                    PlaySongEvent(
                      song: song,
                      queue: state.queue,
                      queueIndex: state.queueIndex,
                    ),
                  );
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
