
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../core/di/injection.dart';
import '../../core/services/audio_player_service.dart';
import '../../core/services/media_resolver_service.dart';
import '../../core/services/settings_service.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/stream_info.dart';
import '../widgets/prism/prism_artwork.dart';
import '../blocs/library/library_bloc.dart';
import '../blocs/library/library_event.dart' hide DownloadSongEvent;
import '../blocs/library/library_state.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../blocs/player/player_state.dart';
import '../theme/prism_theme.dart';
import '../widgets/equalizer/equalizer_bottom_sheet.dart';
import '../widgets/player/player_lyrics_sheet.dart';
import '../widgets/player/player_queue_sheet.dart';
import '../widgets/player/provider_health_sheet.dart';
import '../widgets/prism/prism_sheet.dart';
import '../widgets/prism/prism_song_actions.dart';
import '../widgets/prism/prism_states.dart';
import '../widgets/common/adaptive_layout.dart';
import 'artist_page.dart';

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
          return Scaffold(
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
              _AmbientBackground(dominantColor: _dominantColor),
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(context, theme, song),
                    if (state.errorMessage != null &&
                        state.status == PlayerStatus.error)
                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer
                              .withValues(alpha: 0.88),
                          borderRadius:
                              BorderRadius.circular(PrismRadius.md),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded,
                                color: theme.colorScheme.error, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                state.errorMessage!,
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
                      ),
                    if (AdaptiveBreakpoints.isExpanded(context))
                      Expanded(
                        child: _LandscapePlayerLayout(
                          song: song,
                          state: state,
                          dominantColor: _dominantColor,
                          showLyrics: _showLyrics,
                          onToggleLyrics: () =>
                              setState(() => _showLyrics = !_showLyrics),
                          onArtistTap: _openArtistPage,
                          onProvenanceTap: () => _showStreamDetailsSheet(
                            context,
                            song,
                            state.currentStreamInfo,
                          ),
                        ),
                      )
                    else if (style == PlayerUiStyle.classic)
                      Expanded(
                        child: _ClassicPlayerLayout(
                          song: song,
                          state: state,
                          showLyrics: _showLyrics,
                          onToggleLyrics: () =>
                              setState(() => _showLyrics = !_showLyrics),
                          onArtistTap: _openArtistPage,
                          onProvenanceTap: () => _showStreamDetailsSheet(
                            context,
                            song,
                            state.currentStreamInfo,
                          ),
                        ),
                      )
                    else if (style == PlayerUiStyle.vinyl)
                      Expanded(
                        child: _VinylPlayerLayout(
                          song: song,
                          state: state,
                          showLyrics: _showLyrics,
                          onToggleLyrics: () =>
                              setState(() => _showLyrics = !_showLyrics),
                          onArtistTap: _openArtistPage,
                          onProvenanceTap: () => _showStreamDetailsSheet(
                            context,
                            song,
                            state.currentStreamInfo,
                          ),
                        ),
                      )
                    else ...[
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
                                      maxWidth: isTablet ? 500 : double.infinity,
                                    ),
                                    child: Column(
                                      children: [
                                        const SizedBox(height: 12),
                                        _AlbumArtwork(
                                          song: song,
                                          dominantColor: _dominantColor,
                                        ),
                                        const SizedBox(height: 28),
                                        _SongInfo(
                                          song: song,
                                          streamInfo: state.currentStreamInfo,
                                          onArtistTap: _openArtistPage,
                                          onProvenanceTap: () =>
                                              _showStreamDetailsSheet(
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
                      _ProgressBar(state: state),
                      const SizedBox(height: 12),
                      _MainControls(state: state),
                      const SizedBox(height: 8),
                      _SecondaryControls(
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
            onPressed: () => _showEqualizerSheet(context),
            tooltip: 'Equalizer',
            icon: const Icon(Icons.equalizer_rounded),
          ),
          IconButton(
            onPressed: () => _showOptionsMenu(context, song),
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
    );
  }

  void _showEqualizerSheet(BuildContext context) {
    final audioPlayerService = getIt<AudioPlayerService>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          EqualizerBottomSheet(equalizerService: audioPlayerService.equalizer),
    );
  }

  void _showOptionsMenu(BuildContext context, Song song) {
    showPrismSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            PrismSheetAction(
              icon: Icons.playlist_add_rounded,
              label: 'Add to queue',
              onTap: () {
                Navigator.pop(sheetContext);
                context.read<PlayerBloc>().add(AddToQueueEvent(song: song));
                showPrismToast(context, 'Added to queue');
              },
            ),
            PrismSheetAction(
              icon: Icons.playlist_add_rounded,
              label: 'Add to playlist',
              onTap: () {
                Navigator.pop(sheetContext);
                showPrismPlaylistPicker(context, song);
              },
            ),
            BlocBuilder<LibraryBloc, LibraryState>(
              builder: (context, libraryState) => PrismSheetAction(
                icon: libraryState.isSongLiked(song.id)
                    ? Icons.favorite_rounded
                    : Icons.favorite_outline_rounded,
                label: libraryState.isSongLiked(song.id)
                    ? 'Remove from liked'
                    : 'Add to liked songs',
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.read<LibraryBloc>().add(ToggleLikeSongEvent(song));
                },
              ),
            ),
            PrismSheetAction(
              icon: Icons.download_rounded,
              label: 'Download',
              onTap: () {
                Navigator.pop(sheetContext);
                context.read<PlayerBloc>().add(DownloadSongEvent(song));
                showPrismToast(context, 'Downloading "${song.title}"…');
              },
            ),
            PrismSheetAction(
              icon: Icons.share_rounded,
              label: 'Share',
              onTap: () {
                Navigator.pop(sheetContext);
                ShareSong.shareSong(song);
              },
            ),            BlocBuilder<PlayerBloc, PlayerState>(
              builder: (context, playerState) {
                final end = playerState.sleepTimerEnd;
                final remaining = end?.difference(DateTime.now());
                Widget? trailingWidget;
                if (playerState.sleepTimerEndOfTrack) {
                  trailingWidget = Text(
                    'End of track',
                    style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                          color: Theme.of(sheetContext).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  );
                } else if (remaining != null && !remaining.isNegative) {
                  trailingWidget = Text(
                    '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                          color: Theme.of(sheetContext).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  );
                }

                return PrismSheetAction(
                  icon: Icons.bedtime_rounded,
                  label: 'Sleep timer',
                  trailing: trailingWidget,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showSleepTimerSheet(context, playerState);
                  },
                );
              },
            ),
            PrismSheetAction(
              icon: Icons.health_and_safety_rounded,
              label: 'Provider health & audio sources',
              onTap: () {
                Navigator.pop(sheetContext);
                showProviderHealthSheet(context);
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  /// Off / end-of-track / fixed durations. Dispatches [SetSleepTimerEvent];
  /// null cancels an active timer.
  void _showSleepTimerSheet(BuildContext context, PlayerState state) {
    final options = <({String label, Duration? duration, bool endOfTrack})>[
      const (label: 'Off', duration: null, endOfTrack: false),
      const (label: 'End of track', duration: null, endOfTrack: true),
      ...const [5, 10, 15, 30, 45, 60, 90].map(
        (minutes) => (
          label: '$minutes minutes',
          duration: Duration(minutes: minutes),
          endOfTrack: false,
        ),
      ),
    ];

    showPrismSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sleep timer',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            for (final option in options)
              ListTile(
                leading: const Icon(Icons.bedtime_rounded),
                title: Text(option.label),
                trailing: (option.endOfTrack && state.sleepTimerEndOfTrack) ||
                        (!option.endOfTrack &&
                            option.duration == null &&
                            !state.sleepTimerEndOfTrack &&
                            state.sleepTimerEnd == null)
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(sheetContext).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.read<PlayerBloc>().add(
                    SetSleepTimerEvent(
                      option.duration,
                      endOfTrack: option.endOfTrack,
                    ),
                  );
                  if (option.duration != null || option.endOfTrack) {
                    showPrismToast(context, 'Sleep timer set: ${option.label}');
                  } else {
                    showPrismToast(context, 'Sleep timer cancelled');
                  }
                },
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  void _showStreamDetailsSheet(
    BuildContext context,
    Song song,
    StreamInfo? streamInfo,
  ) {
    showPrismSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(sheetContext)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(PrismRadius.md),
                    ),
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: Theme.of(sheetContext).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Audio Stream Diagnostics',
                          style: Theme.of(sheetContext)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(sheetContext)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(sheetContext)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext)
                      .colorScheme
                      .surfaceContainerLow,
                  borderRadius: BorderRadius.circular(PrismRadius.lg),
                  border: Border.all(
                    color: Theme.of(sheetContext)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    _diagnosticRow(
                      sheetContext,
                      'Resolution Source',
                      _formatProvenance(streamInfo?.streamProvenance, song),
                    ),
                    const Divider(height: 16),
                    _diagnosticRow(
                      sheetContext,
                      'Audio Codec',
                      streamInfo?.codec.toUpperCase() ?? 'Direct Media',
                    ),
                    const Divider(height: 16),
                    _diagnosticRow(
                      sheetContext,
                      'Nominal Bitrate',
                      streamInfo != null && streamInfo.bitrate > 0
                          ? '${streamInfo.bitrate} kbps'
                          : 'Standard',
                    ),
                    const Divider(height: 16),
                    _diagnosticRow(
                      sheetContext,
                      'Container Format',
                      streamInfo?.container != null && streamInfo!.container.isNotEmpty
                          ? '.${streamInfo.container}'
                          : 'Stream (HTTP Live)',
                    ),
                    if (streamInfo?.matchConfidence != null) ...[
                      const Divider(height: 16),
                      _diagnosticRow(
                        sheetContext,
                        'Match Confidence',
                        '${(streamInfo!.matchConfidence! * 100).round()}% Verified',
                        trailingIcon: Icons.verified_rounded,
                        trailingColor: Theme.of(sheetContext).colorScheme.primary,
                      ),
                    ],
                  ],
                ),
              ),
              if (song.source != MusicSource.local) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: Icon(
                      streamInfo?.streamProvenance == 'jiosaavn_matched'
                          ? Icons.play_circle_fill_rounded
                          : Icons.graphic_eq_rounded,
                      size: 17,
                    ),
                    label: Text(
                      streamInfo?.streamProvenance == 'jiosaavn_matched'
                          ? 'Switch to YouTube Audio'
                          : 'Try JioSaavn Match',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(PrismRadius.md),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      final playerBloc = context.read<PlayerBloc>();
                      final state = playerBloc.state;
                      final targetResolver = streamInfo?.streamProvenance == 'jiosaavn_matched'
                          ? 'youtube_explode'
                          : 'jiosaavn';
                      playerBloc.add(
                        PlaySongEvent(
                          song: song,
                          queue: state.queue,
                          queueIndex: state.queueIndex,
                          userInitiated: true,
                          preferredResolver: targetResolver,
                        ),
                      );
                      showPrismToast(
                        context,
                        targetResolver == 'youtube_explode'
                            ? 'Switching to YouTube Audio...'
                            : 'Attempting JioSaavn match...',
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.health_and_safety_rounded, size: 17),
                    label: const Text('Provider Health & Safe Switch'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(PrismRadius.md),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      showProviderHealthSheet(context);
                    },
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Reload Fresh Stream'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PrismRadius.md),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    final mediaResolver = getIt<MediaResolverService>();
                    mediaResolver.invalidate(song.playableId);
                    final playerBloc = context.read<PlayerBloc>();
                    final state = playerBloc.state;
                    playerBloc.add(
                      PlaySongEvent(
                        song: song,
                        queue: state.queue,
                        queueIndex: state.queueIndex,
                        userInitiated: true,
                      ),
                    );
                    showPrismToast(context, 'Re-resolving fresh audio stream...');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatProvenance(String? provenance, Song song) {
    if (song.source == MusicSource.local) return 'Local Offline Storage';
    switch (provenance) {
      case 'jiosaavn_matched':
        return 'JioSaavn High-Fidelity Match';
      case 'youtube_explode':
        return 'YouTube Explode Audio-Only';
      case 'piped_proxy':
        return 'Piped Private Proxy';
      case 'invidious_instance':
        return 'Invidious Community Node';
      default:
        return 'Direct Stream Provider';
    }
  }

  static Widget _diagnosticRow(
    BuildContext context,
    String label,
    String value, {
    IconData? trailingIcon,
    Color? trailingColor,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (trailingIcon != null) ...[
                Icon(trailingIcon, size: 14, color: trailingColor),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Ambient background
// ════════════════════════════════════════════════════════════════════════════

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground({required this.dominantColor});

  final Color? dominantColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = dominantColor ?? theme.colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  accent.withValues(alpha: 0.34),
                  theme.colorScheme.surfaceContainerLow.withValues(alpha: .6),
                  theme.colorScheme.surface,
                ]
              : [
                  accent.withValues(alpha: 0.16),
                  theme.colorScheme.surface,
                  theme.colorScheme.surfaceContainerLow,
                ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Artwork + song info
// ════════════════════════════════════════════════════════════════════════════

class _AlbumArtwork extends StatelessWidget {
  const _AlbumArtwork({required this.song, required this.dominantColor});

  final Song song;
  final Color? dominantColor;

  @override
  Widget build(BuildContext context) {
    final size = (MediaQuery.sizeOf(context).width * 0.74)
        .clamp(220.0, 320.0)
        .toDouble();
    final maxArtHeight = MediaQuery.sizeOf(context).height * 0.40;
    final artSize = size > maxArtHeight ? maxArtHeight : size;
    final accent = dominantColor ?? Theme.of(context).colorScheme.primary;

    return Hero(
      tag: 'album_art_${song.youtubeId ?? song.id}',
      child: Container(
        width: artSize,
        height: artSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PrismRadius.xl),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.35),
              blurRadius: 44,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(PrismRadius.xl),
          child: song.thumbnailUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: song.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _fallback(context),
                  errorWidget: (_, __, ___) => _fallback(context),
                )
              : _fallback(context),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Icon(
        Icons.music_note_rounded,
        size: 48,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: .4),
      ),
    );
  }
}

class _SongInfo extends StatelessWidget {
  const _SongInfo({
    required this.song,
    this.streamInfo,
    required this.onArtistTap,
    this.onProvenanceTap,
  });

  final Song song;
  final StreamInfo? streamInfo;
  final void Function(String) onArtistTap;
  final VoidCallback? onProvenanceTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Text(
            song.title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          _ClickableArtistText(
            artistString: song.artist,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: .75),
              fontWeight: FontWeight.w500,
            ),
            onArtistTap: onArtistTap,
          ),
          if (streamInfo != null || song.source == MusicSource.local) ...[
            const SizedBox(height: 8),
            _AudioProvenanceBadge(
              song: song,
              streamInfo: streamInfo,
              onTap: onProvenanceTap ?? () {},
            ),
          ],
        ],
      ),
    );
  }
}

class _AudioProvenanceBadge extends StatelessWidget {
  const _AudioProvenanceBadge({
    required this.song,
    required this.streamInfo,
    required this.onTap,
  });

  final Song song;
  final StreamInfo? streamInfo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOffline = song.source == MusicSource.local;
    final provenance = streamInfo?.streamProvenance;

    IconData sourceIcon;
    String sourceName;
    if (isOffline) {
      sourceIcon = Icons.offline_pin_rounded;
      sourceName = 'Offline';
    } else {
      switch (provenance) {
        case 'jiosaavn_matched':
          sourceIcon = Icons.graphic_eq_rounded;
          sourceName = 'JioSaavn';
          break;
        case 'youtube_explode':
          sourceIcon = Icons.play_circle_fill_rounded;
          sourceName = 'YouTube';
          break;
        case 'piped_proxy':
          sourceIcon = Icons.shield_outlined;
          sourceName = 'Piped';
          break;
        case 'invidious_instance':
          sourceIcon = Icons.dns_rounded;
          sourceName = 'Invidious';
          break;
        default:
          sourceIcon = Icons.music_note_rounded;
          sourceName = song.source == MusicSource.spotify ? 'Spotify' : 'Direct';
          break;
      }
    }

    final bitrate = streamInfo?.bitrate ?? 0;
    final codec = (streamInfo?.codec ?? '').toUpperCase();
    final formatText = bitrate > 0
        ? '$bitrate kbps · $codec'
        : (codec.isNotEmpty ? codec : '');
    final matchConfidence = streamInfo?.matchConfidence;
    final hasMatchConfidence = matchConfidence != null && provenance == 'jiosaavn_matched';
    final matchPercent = matchConfidence != null ? (matchConfidence * 100).round() : null;

    return Semantics(
      button: true,
      label: 'Audio stream details: $sourceName $formatText',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PrismRadius.pill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(PrismRadius.pill),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                width: 0.5,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  sourceIcon,
                  size: 13,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  sourceName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                if (formatText.isNotEmpty) ...[
                  Text(
                    ' · ',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    formatText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (hasMatchConfidence) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: (matchPercent != null && matchPercent >= 85)
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(PrismRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 9,
                          color: (matchPercent != null && matchPercent >= 85)
                              ? theme.colorScheme.primary
                              : Colors.amber,
                        ),
                        const SizedBox(width: 2.5),
                        Text(
                          '$matchPercent%',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: (matchPercent != null && matchPercent >= 85)
                                ? theme.colorScheme.primary
                                : Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(
                  Icons.info_outline_rounded,
                  size: 11,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tappable multi-artist line ("A, B, C" → each name is a link).
class _ClickableArtistText extends StatefulWidget {
  const _ClickableArtistText({
    required this.artistString,
    required this.style,
    required this.onArtistTap,
  });

  final String artistString;
  final TextStyle? style;
  final void Function(String) onArtistTap;

  @override
  State<_ClickableArtistText> createState() => _ClickableArtistTextState();
}

class _ClickableArtistTextState extends State<_ClickableArtistText> {
  late List<TapGestureRecognizer> _recognizers;

  @override
  void initState() {
    super.initState();
    _buildRecognizers();
  }

  @override
  void didUpdateWidget(covariant _ClickableArtistText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artistString != widget.artistString) {
      _disposeRecognizers();
      _buildRecognizers();
    }
  }

  void _buildRecognizers() {
    final artistCount = widget.artistString.split(RegExp(r',\s*')).length;
    _recognizers = List.generate(
      artistCount,
      (_) => TapGestureRecognizer()..onTap = () {},
    );
    // Tap handlers need the artist names; rebuild with context-free lookup.
    final names = widget.artistString.split(RegExp(r',\s*'));
    for (var i = 0; i < names.length && i < _recognizers.length; i++) {
      final name = names[i].trim();
      _recognizers[i].onTap = () => widget.onArtistTap(name);
    }
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = widget.artistString.split(RegExp(r',\s*'));
    final spans = <InlineSpan>[];
    for (var i = 0; i < names.length; i++) {
      if (i > 0) {
        spans.add(TextSpan(text: ', ', style: widget.style));
      }
      if (i < _recognizers.length) {
        spans.add(
          TextSpan(
            text: names[i].trim(),
            style: widget.style?.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: widget.style?.color?.withValues(alpha: .4),
            ),
            recognizer: _recognizers[i],
          ),
        );
      } else {
        spans.add(TextSpan(text: names[i].trim(), style: widget.style));
      }
    }
    return RichText(
      text: TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Progress + controls
// ════════════════════════════════════════════════════════════════════════════

class _ProgressBar extends StatefulWidget {
  const _ProgressBar({required this.state});

  final PlayerState state;

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  double? _dragValue;

  String _format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = widget.state.duration;
    final progress = duration.inMilliseconds > 0
        ? (widget.state.position.inMilliseconds / duration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    final displayProgress = _dragValue ?? progress;
    final displayPosition = _dragValue != null
        ? Duration(
            milliseconds: (_dragValue! * duration.inMilliseconds).round(),
          )
        : widget.state.position;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: displayProgress.clamp(0.0, 1.0),
              onChanged: (value) {
                setState(() => _dragValue = value);
              },
              onChangeEnd: (value) {
                final newPosition = Duration(
                  milliseconds: (value * duration.inMilliseconds).round(),
                );
                context.read<PlayerBloc>().add(SeekEvent(newPosition));
                setState(() => _dragValue = null);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _format(displayPosition),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  '-${_format(duration - displayPosition > Duration.zero ? duration - displayPosition : Duration.zero)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MainControls extends StatelessWidget {
  const _MainControls({required this.state});

  final PlayerState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: state.canSkipPrevious
                ? () => context.read<PlayerBloc>().add(const PreviousEvent())
                : null,
            iconSize: 30,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          _PlayPauseButton(state: state),
          IconButton(
            onPressed: state.canSkipNext
                ? () => context.read<PlayerBloc>().add(const NextEvent())
                : null,
            iconSize: 30,
            icon: const Icon(Icons.skip_next_rounded),
          ),
        ],
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.state});

  final PlayerState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPlaying = state.isPlaying;
    final isError = state.status == PlayerStatus.error;

    return Semantics(
      button: true,
      label: isError ? 'Retry' : (isPlaying ? 'Pause' : 'Play'),
      child: GestureDetector(
        onTap: state.isBuffering
            ? null
            : () => context.read<PlayerBloc>().add(
                isPlaying ? const PauseEvent() : const ResumeEvent(),
              ),
        child: AnimatedContainer(
          duration: PrismMotion.fast,
          curve: PrismMotion.curve,
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary,
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: .30),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: state.isBuffering
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  isError
                      ? Icons.refresh_rounded
                      : (isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                  size: 38,
                  color: scheme.onPrimary,
                ),
        ),
      ),
    );
  }
}

class _SecondaryControls extends StatelessWidget {
  const _SecondaryControls({
    required this.song,
    required this.state,
    required this.showLyrics,
    required this.onToggleLyrics,
  });

  final Song song;
  final PlayerState state;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return BlocBuilder<LibraryBloc, LibraryState>(
      builder: (context, library) {
        final isLiked = library.isSongLiked(song.id);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: 'Shuffle',
                onPressed: () =>
                    context.read<PlayerBloc>().add(const ToggleShuffleEvent()),
                icon: Icon(
                  Icons.shuffle_rounded,
                  color: state.isShuffleEnabled
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
              IconButton(
                tooltip: switch (state.repeatMode) {
                  RepeatMode.off => 'Repeat: Off',
                  RepeatMode.all => 'Repeat: All',
                  RepeatMode.one => 'Repeat: One',
                },
                onPressed: () {
                  context.read<PlayerBloc>().add(
                    const CycleRepeatModeEvent(),
                  );
                  final nextMode = switch (state.repeatMode) {
                    RepeatMode.off => 'Repeat All',
                    RepeatMode.all => 'Repeat One',
                    RepeatMode.one => 'Repeat Off',
                  };
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(nextMode),
                      duration: const Duration(milliseconds: 900),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: Icon(
                  switch (state.repeatMode) {
                    RepeatMode.one => Icons.repeat_one_rounded,
                    RepeatMode.all => Icons.repeat_rounded,
                    RepeatMode.off => Icons.repeat_rounded,
                  },
                  color: state.repeatMode != RepeatMode.off
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
              IconButton(
                tooltip: isLiked ? 'Unlike' : 'Like',
                onPressed: () =>
                    context.read<LibraryBloc>().add(ToggleLikeSongEvent(song)),
                icon: Icon(
                  isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_outline_rounded,
                  color: isLiked ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              IconButton(
                tooltip: 'Lyrics',
                onPressed: onToggleLyrics,
                icon: Icon(
                  Icons.lyrics_outlined,
                  color: showLyrics ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              IconButton(
                tooltip: 'Queue',
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const PlayerQueueSheet(),
                ),
                icon: Icon(
                  Icons.queue_music_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LandscapePlayerLayout extends StatelessWidget {
  final Song song;
  final PlayerState state;
  final Color? dominantColor;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;
  final void Function(String artistName) onArtistTap;
  final VoidCallback onProvenanceTap;

  const _LandscapePlayerLayout({
    required this.song,
    required this.state,
    required this.dominantColor,
    required this.showLyrics,
    required this.onToggleLyrics,
    required this.onArtistTap,
    required this.onProvenanceTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Pane: Artwork or Lyrics
          Expanded(
            flex: 5,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340, maxWidth: 340),
                child: showLyrics
                    ? PlayerLyricsView(
                        key: ValueKey('lyrics_${song.id}'),
                        song: song,
                      )
                    : _AlbumArtwork(
                        song: song,
                        dominantColor: dominantColor,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Right Pane: Song Info + Scrubber + Controls
          Expanded(
            flex: 6,
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SongInfo(
                      song: song,
                      streamInfo: state.currentStreamInfo,
                      onArtistTap: onArtistTap,
                      onProvenanceTap: onProvenanceTap,
                    ),
                    const SizedBox(height: 12),
                    _ProgressBar(state: state),
                    const SizedBox(height: 8),
                    _MainControls(state: state),
                    const SizedBox(height: 4),
                    _SecondaryControls(
                      song: song,
                      state: state,
                      showLyrics: showLyrics,
                      onToggleLyrics: onToggleLyrics,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassicPlayerLayout extends StatelessWidget {
  final Song song;
  final PlayerState state;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;
  final void Function(String artistName) onArtistTap;
  final VoidCallback onProvenanceTap;

  const _ClassicPlayerLayout({
    required this.song,
    required this.state,
    required this.showLyrics,
    required this.onToggleLyrics,
    required this.onArtistTap,
    required this.onProvenanceTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.sizeOf(context).width > 600;

    return Column(
      children: [
        Expanded(
          child: showLyrics
              ? PlayerLyricsView(
                  key: ValueKey('lyrics_${song.id}'),
                  song: song,
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? 480 : double.infinity,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 12),
                          // Classic framed album artwork
                          AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: PrismArtwork(
                                  url: song.thumbnailUrl,
                                  width: double.infinity,
                                  height: double.infinity,
                                  borderRadius: 0,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Track info with inline like button
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    GestureDetector(
                                      onTap: () => onArtistTap(song.artist),
                                      child: Text(
                                        song.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    if (song.album != null && song.album!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        song.album!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              BlocBuilder<LibraryBloc, LibraryState>(
                                builder: (context, lib) {
                                  final isLiked = lib.isSongLiked(song.id);
                                  return IconButton(
                                    icon: Icon(
                                      isLiked
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_outline_rounded,
                                      color: isLiked
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    onPressed: () => context
                                        .read<LibraryBloc>()
                                        .add(ToggleLikeSongEvent(song)),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        // Classic Scrubber
        _ProgressBar(state: state),
        const SizedBox(height: 12),
        // Classic 5-button transport bar
        _ClassicTransportControls(state: state),
        const SizedBox(height: 12),
        // Classic bottom utilities: Diagnostics, Lyrics, Queue
        _ClassicUtilityRow(
          song: song,
          state: state,
          showLyrics: showLyrics,
          onToggleLyrics: onToggleLyrics,
          onProvenanceTap: onProvenanceTap,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _ClassicTransportControls extends StatelessWidget {
  final PlayerState state;

  const _ClassicTransportControls({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            tooltip: 'Shuffle',
            iconSize: 22,
            icon: Icon(
              Icons.shuffle_rounded,
              color: state.isShuffleEnabled ? scheme.primary : scheme.onSurfaceVariant,
            ),
            onPressed: () => context.read<PlayerBloc>().add(const ToggleShuffleEvent()),
          ),
          IconButton(
            tooltip: 'Previous',
            iconSize: 32,
            icon: const Icon(Icons.skip_previous_rounded),
            onPressed: state.canSkipPrevious
                ? () => context.read<PlayerBloc>().add(const PreviousEvent())
                : null,
          ),
          _PlayPauseButton(state: state),
          IconButton(
            tooltip: 'Next',
            iconSize: 32,
            icon: const Icon(Icons.skip_next_rounded),
            onPressed: state.canSkipNext
                ? () => context.read<PlayerBloc>().add(const NextEvent())
                : null,
          ),
          IconButton(
            tooltip: switch (state.repeatMode) {
              RepeatMode.off => 'Repeat: Off',
              RepeatMode.all => 'Repeat: All',
              RepeatMode.one => 'Repeat: One',
            },
            iconSize: 22,
            icon: Icon(
              switch (state.repeatMode) {
                RepeatMode.one => Icons.repeat_one_rounded,
                RepeatMode.all => Icons.repeat_rounded,
                RepeatMode.off => Icons.repeat_rounded,
              },
              color: state.repeatMode != RepeatMode.off ? scheme.primary : scheme.onSurfaceVariant,
            ),
            onPressed: () => context.read<PlayerBloc>().add(const CycleRepeatModeEvent()),
          ),
        ],
      ),
    );
  }
}

class _ClassicUtilityRow extends StatelessWidget {
  final Song song;
  final PlayerState state;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;
  final VoidCallback onProvenanceTap;

  const _ClassicUtilityRow({
    required this.song,
    required this.state,
    required this.showLyrics,
    required this.onToggleLyrics,
    required this.onProvenanceTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Audio Source & Diagnostics',
            icon: const Icon(Icons.info_outline_rounded, size: 20),
            onPressed: onProvenanceTap,
          ),
          IconButton(
            tooltip: 'Lyrics',
            icon: Icon(
              Icons.lyrics_outlined,
              size: 20,
              color: showLyrics ? scheme.primary : scheme.onSurfaceVariant,
            ),
            onPressed: onToggleLyrics,
          ),
          IconButton(
            tooltip: 'Queue',
            icon: const Icon(Icons.queue_music_rounded, size: 20),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => const PlayerQueueSheet(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Audiophile Vinyl turntable player layout with rotating grooved disc,
/// tonearm styling, complete transport controls, and full lyrics parity.
class _VinylPlayerLayout extends StatefulWidget {
  final Song song;
  final PlayerState state;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;
  final void Function(String artistName) onArtistTap;
  final VoidCallback onProvenanceTap;

  const _VinylPlayerLayout({
    required this.song,
    required this.state,
    required this.showLyrics,
    required this.onToggleLyrics,
    required this.onArtistTap,
    required this.onProvenanceTap,
  });

  @override
  State<_VinylPlayerLayout> createState() => _VinylPlayerLayoutState();
}

class _VinylPlayerLayoutState extends State<_VinylPlayerLayout>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    if (widget.state.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _VinylPlayerLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.isPlaying && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!widget.state.isPlaying && _rotationController.isAnimating) {
      _rotationController.stop();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.sizeOf(context).width > 600;

    return Column(
      children: [
        Expanded(
          child: widget.showLyrics
              ? PlayerLyricsView(
                  key: ValueKey('lyrics_${widget.song.id}'),
                  song: widget.song,
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? 500 : double.infinity,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 12),
                          // Turntable and rotating vinyl disk
                          _buildTurntable(context),
                          const SizedBox(height: 24),
                          // Track info with inline like button
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    GestureDetector(
                                      onTap: () => widget.onArtistTap(widget.song.artist),
                                      child: Text(
                                        widget.song.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    if (widget.song.album != null &&
                                        widget.song.album!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.song.album!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              BlocBuilder<LibraryBloc, LibraryState>(
                                builder: (context, lib) {
                                  final isLiked = lib.isSongLiked(widget.song.id);
                                  return IconButton(
                                    icon: Icon(
                                      isLiked
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_outline_rounded,
                                      color: isLiked
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    onPressed: () => context
                                        .read<LibraryBloc>()
                                        .add(ToggleLikeSongEvent(widget.song)),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        // Vinyl Scrubber
        _ProgressBar(state: widget.state),
        const SizedBox(height: 12),
        // Transport Controls
        _ClassicTransportControls(state: widget.state),
        const SizedBox(height: 12),
        // Bottom utilities
        _ClassicUtilityRow(
          song: widget.song,
          state: widget.state,
          showLyrics: widget.showLyrics,
          onToggleLyrics: widget.onToggleLyrics,
          onProvenanceTap: widget.onProvenanceTap,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTurntable(BuildContext context) {
    final diskSize = (MediaQuery.sizeOf(context).width - 64).clamp(240.0, 310.0);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer turntable platter rim
          Container(
            width: diskSize + 12,
            height: diskSize + 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF161619),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 26,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          ),
          // Rotating Vinyl Disc
          RotationTransition(
            turns: _rotationController,
            child: Container(
              width: diskSize,
              height: diskSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFF26262C),
                    Color(0xFF141416),
                    Color(0xFF1D1D21),
                    Color(0xFF0F0F10),
                  ],
                  stops: [0.0, 0.45, 0.85, 1.0],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer groove ring
                  Container(
                    width: diskSize * 0.86,
                    height: diskSize * 0.86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                        width: 1,
                      ),
                    ),
                  ),
                  // Mid groove ring
                  Container(
                    width: diskSize * 0.72,
                    height: diskSize * 0.72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.04),
                        width: 1,
                      ),
                    ),
                  ),
                  // Inner groove ring
                  Container(
                    width: diskSize * 0.58,
                    height: diskSize * 0.58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                        width: 1,
                      ),
                    ),
                  ),
                  // Center artwork label
                  Container(
                    width: diskSize * 0.44,
                    height: diskSize * 0.44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: PrismArtwork(
                        url: widget.song.thumbnailUrl,
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: 0,
                      ),
                    ),
                  ),
                  // Spindle hole
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF121214),
                      border: Border.all(
                        color: const Color(0xFFD4AF37),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.7),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Tonearm accent (placed at top-right corner pointing towards vinyl)
          Positioned(
            top: 2,
            right: 8,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: -0.35,
                child: Container(
                  width: 6,
                  height: diskSize * 0.42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB0B0B4), Color(0xFF505054)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(2, 2),
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
}

