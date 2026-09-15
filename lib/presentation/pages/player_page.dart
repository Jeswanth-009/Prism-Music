import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/di/injection.dart';
import '../../core/services/audio_player_service.dart';
import '../../domain/entities/song.dart';
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
import '../widgets/prism/prism_sheet.dart';
import '../widgets/prism/prism_song_actions.dart';
import '../widgets/prism/prism_states.dart';
import 'artist_page.dart';

/// Full-screen immersive player. Artwork colour drives the ambient
/// background; controls stay quiet and centred.
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  Color? _dominantColor;
  bool _showLyrics = false;
  String? _lastImageUrl;

  void _openArtistPage(String artistName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArtistPage(artistName: artistName),
      ),
    );
  }

  Future<void> _extractDominantColor(String imageUrl) async {
    if (imageUrl == _lastImageUrl) return;
    _lastImageUrl = imageUrl;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(imageUrl),
      );
      if (!mounted) return;
      setState(() {
        _dominantColor =
            palette.dominantColor?.color ??
            palette.vibrantColor?.color ??
            palette.mutedColor?.color;
      });
    } catch (_) {
      if (mounted) setState(() => _dominantColor = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerBloc, PlayerState>(
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

        if (song.thumbnailUrl.isNotEmpty) {
          _extractDominantColor(song.thumbnailUrl);
        }

        final theme = Theme.of(context);
        final isTablet = MediaQuery.sizeOf(context).width > 600;

        return Scaffold(
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              _AmbientBackground(dominantColor: _dominantColor),
              SafeArea(
                child: Column(
                    children: [
                      _buildHeader(context, theme, song),
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
                                          onArtistTap: _openArtistPage,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      if (!_showLyrics) ...[
                        _ProgressBar(state: state),
                        const SizedBox(height: 14),
                        _MainControls(state: state),
                        const SizedBox(height: 10),
                        _SecondaryControls(
                          song: song,
                          state: state,
                          showLyrics: _showLyrics,
                          onToggleLyrics: () =>
                              setState(() => _showLyrics = !_showLyrics),
                        ),
                      ] else ...[
                        const SizedBox(height: 10),
                        _SecondaryControls(
                          song: song,
                          state: state,
                          showLyrics: _showLyrics,
                          onToggleLyrics: () =>
                              setState(() => _showLyrics = !_showLyrics),
                        ),
                      ],
                      const SizedBox(height: 22),
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
      builder: (_) => EqualizerBottomSheet(
        equalizerService: audioPlayerService.equalizer,
      ),
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
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
                final videoId = song.youtubeId ?? song.id;
                Share.share(
                  '${song.title} - ${song.artist}\n'
                  'https://music.youtube.com/watch?v=$videoId',
                );
              },
            ),
            BlocBuilder<PlayerBloc, PlayerState>(
              builder: (context, playerState) {
                final end = playerState.sleepTimerEnd;
                final remaining =
                    end?.difference(DateTime.now());
                return PrismSheetAction(
                  icon: Icons.bedtime_rounded,
                  label: 'Sleep timer',
                  trailing: remaining == null || remaining.isNegative
                      ? null
                      : Text(
                          '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: Theme.of(sheetContext)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(sheetContext)
                                    .colorScheme
                                    .primary,
                              ),
                        ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showSleepTimerSheet(context, playerState);
                  },
                );
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
    final endOfTrack =
        state.duration > Duration.zero ? state.duration - state.position : null;
    final options = <({String label, Duration? duration})>[
      const (label: 'Off', duration: null),
      if (endOfTrack != null && !endOfTrack.isNegative)
        (label: 'End of track', duration: endOfTrack),
      ...const [5, 10, 15, 30, 45, 60, 90].map(
        (minutes) => (
          label: '$minutes minutes',
          duration: Duration(minutes: minutes),
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
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            for (final option in options)
              ListTile(
                leading: const Icon(Icons.bedtime_rounded),
                title: Text(option.label),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context
                      .read<PlayerBloc>()
                      .add(SetSleepTimerEvent(option.duration));
                  if (option.duration != null) {
                    showPrismToast(
                      context,
                      'Sleep timer set: ${option.label}',
                    );
                  }
                },
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
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
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: const SizedBox.expand(),
      ),
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
    final accent =
        dominantColor ?? Theme.of(context).colorScheme.primary;

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
  const _SongInfo({required this.song, required this.onArtistTap});

  final Song song;
  final void Function(String) onArtistTap;

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
        ],
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
    final artistCount =
        widget.artistString.split(RegExp(r',\s*')).length;
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
        spans.add(
          TextSpan(
            text: ', ',
            style: widget.style,
          ),
        );
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

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.state});

  final PlayerState state;

  String _format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = state.duration;
    final progress = duration.inMilliseconds > 0
        ? (state.position.inMilliseconds / duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: progress,
              onChanged: (value) {
                final newPosition = Duration(
                  milliseconds:
                      (value * duration.inMilliseconds).round(),
                );
                context.read<PlayerBloc>().add(SeekEvent(newPosition));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _format(state.position),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  '-${_format(duration - state.position)}',
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
            onPressed:
                state.hasPrevious || state.position.inSeconds > 3
                    ? () =>
                        context.read<PlayerBloc>().add(const PreviousEvent())
                    : null,
            iconSize: 30,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          _PlayPauseButton(state: state),
          IconButton(
            onPressed: state.hasNext
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

    return Semantics(
      button: true,
      label: isPlaying ? 'Pause' : 'Play',
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
            color: isPlaying ? scheme.primary : scheme.primary,
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
              : AnimatedSwitcher(
                  duration: PrismMotion.fast,
                  child: Icon(
                    isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    key: ValueKey(isPlaying),
                    size: 38,
                    color: scheme.onPrimary,
                  ),
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
                onPressed: () => context
                    .read<PlayerBloc>()
                    .add(const ToggleShuffleEvent()),
                icon: Icon(
                  Icons.shuffle_rounded,
                  color: state.isShuffleEnabled
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
              IconButton(
                tooltip: 'Repeat',
                onPressed: () => context
                    .read<PlayerBloc>()
                    .add(const CycleRepeatModeEvent()),
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
                onPressed: () => context
                    .read<LibraryBloc>()
                    .add(ToggleLikeSongEvent(song)),
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
                  color: showLyrics
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
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
