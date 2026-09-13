import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/di/injection.dart';
import '../../core/services/audio_player_service.dart';
import '../blocs/library/library.dart' hide DownloadSongEvent;
import '../blocs/player/player.dart';
import '../theme/prism_theme.dart';
import '../widgets/equalizer/equalizer_bottom_sheet.dart';
import '../widgets/player/player_queue_sheet.dart';
import 'artist_page.dart';

class PrismPlayerPage extends StatelessWidget {
  const PrismPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerBloc, PlayerState>(
      builder: (context, state) {
        final song = state.currentSong;
        if (song == null) {
          return const Scaffold(
            body: Center(child: Text('Nothing is playing yet.')),
          );
        }

        return Scaffold(
          backgroundColor: PrismColors.ink,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (song.thumbnailUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: song.thumbnailUrl,
                  fit: BoxFit.cover,
                  color: Colors.black.withValues(alpha: 0.2),
                  colorBlendMode: BlendMode.darken,
                ),
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 62, sigmaY: 62),
                child: const SizedBox.expand(),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x9905090E),
                      Color(0xCC080B12),
                      PrismColors.ink,
                    ],
                    stops: [0, 0.55, 1],
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final artSize = (constraints.maxWidth - 48).clamp(
                      230.0,
                      430.0,
                    );
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 36,
                        ),
                        child: Column(
                          children: [
                            _PlayerHeader(songTitle: song.title),
                            SizedBox(
                              height: constraints.maxHeight < 700 ? 18 : 28,
                            ),
                            Hero(
                              tag: 'album_art_${song.youtubeId ?? song.id}',
                              child: Container(
                                width: artSize,
                                height: artSize,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.45,
                                      ),
                                      blurRadius: 42,
                                      offset: const Offset(0, 22),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: song.thumbnailUrl.isEmpty
                                    ? const _PlayerArtworkFallback()
                                    : CachedNetworkImage(
                                        imageUrl: song.thumbnailUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            const _PlayerArtworkFallback(),
                                      ),
                              ),
                            ),
                            SizedBox(
                              height: constraints.maxHeight < 700 ? 22 : 34,
                            ),
                            _SongIdentity(state: state),
                            const SizedBox(height: 22),
                            _Progress(state: state),
                            const SizedBox(height: 18),
                            _PrimaryControls(state: state),
                            const SizedBox(height: 24),
                            _UtilityBar(state: state),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({required this.songTitle});
  final String songTitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Close player',
          onPressed: () => Navigator.of(context).pop(),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white10,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(LucideIcons.chevronDown),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'NOW PLAYING',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: PrismColors.cyan,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                songTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Queue',
          onPressed: () => _showQueue(context),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white10,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(LucideIcons.listMusic, size: 20),
        ),
      ],
    );
  }
}

class _SongIdentity extends StatelessWidget {
  const _SongIdentity({required this.state});
  final PlayerState state;

  @override
  Widget build(BuildContext context) {
    final song = state.currentSong!;
    return BlocBuilder<LibraryBloc, LibraryState>(
      builder: (context, library) {
        final liked = library.isSongLiked(song.id);
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 7),
                  InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ArtistPage(artistName: song.artist),
                      ),
                    ),
                    child: Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white60,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: liked ? 'Remove from Liked Songs' : 'Add to Liked Songs',
              onPressed: () =>
                  context.read<LibraryBloc>().add(ToggleLikeSongEvent(song)),
              style: IconButton.styleFrom(
                fixedSize: const Size(50, 50),
                backgroundColor: liked
                    ? PrismColors.coral.withValues(alpha: 0.18)
                    : Colors.white10,
                foregroundColor: liked ? PrismColors.coral : Colors.white,
              ),
              icon: Icon(
                liked ? LucideIcons.heart : LucideIcons.heart,
                fill: liked ? 1 : 0,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state});
  final PlayerState state;

  @override
  Widget build(BuildContext context) {
    final maxMs = mathMax(1, state.duration.inMilliseconds);
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: PrismColors.cyan,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: PrismColors.cyan.withValues(alpha: 0.14),
            trackHeight: 3,
          ),
          child: Slider(
            value: state.position.inMilliseconds.clamp(0, maxMs).toDouble(),
            max: maxMs.toDouble(),
            onChanged: (value) => context.read<PlayerBloc>().add(
              SeekEvent(Duration(milliseconds: value.round())),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.positionFormatted,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                '-${state.remainingFormatted}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrimaryControls extends StatelessWidget {
  const _PrimaryControls({required this.state});
  final PlayerState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _RoundControl(
          icon: LucideIcons.shuffle,
          active: state.isShuffleEnabled,
          onPressed: () =>
              context.read<PlayerBloc>().add(const ToggleShuffleEvent()),
        ),
        _RoundControl(
          icon: LucideIcons.skipBack,
          large: true,
          onPressed: () =>
              context.read<PlayerBloc>().add(const PreviousEvent()),
        ),
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            gradient: PrismColors.spectrum,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: PrismColors.cyan.withValues(alpha: 0.26),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: IconButton(
            tooltip: state.isPlaying ? 'Pause' : 'Play',
            onPressed: state.isBuffering
                ? null
                : () => context.read<PlayerBloc>().add(
                    state.isPlaying ? const PauseEvent() : const ResumeEvent(),
                  ),
            icon: state.isBuffering
                ? const CircularProgressIndicator(
                    color: PrismColors.ink,
                    strokeWidth: 2,
                  )
                : Icon(
                    state.isPlaying ? LucideIcons.pause : LucideIcons.play,
                    color: PrismColors.ink,
                    size: 34,
                  ),
          ),
        ),
        _RoundControl(
          icon: LucideIcons.skipForward,
          large: true,
          enabled: state.hasNext,
          onPressed: () => context.read<PlayerBloc>().add(const NextEvent()),
        ),
        _RoundControl(
          icon: state.repeatMode == RepeatMode.one
              ? LucideIcons.repeat1
              : LucideIcons.repeat,
          active: state.repeatMode != RepeatMode.off,
          onPressed: () =>
              context.read<PlayerBloc>().add(const CycleRepeatModeEvent()),
        ),
      ],
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.large = false,
    this.enabled = true,
  });
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;
  final bool large;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onPressed : null,
      style: IconButton.styleFrom(
        fixedSize: Size.square(large ? 52 : 44),
        backgroundColor: active
            ? PrismColors.cyan.withValues(alpha: 0.15)
            : Colors.white10,
        foregroundColor: active ? PrismColors.cyan : Colors.white,
        disabledForegroundColor: Colors.white24,
      ),
      icon: Icon(icon, size: large ? 25 : 20),
    );
  }
}

class _UtilityBar extends StatelessWidget {
  const _UtilityBar({required this.state});
  final PlayerState state;

  @override
  Widget build(BuildContext context) {
    final song = state.currentSong!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Utility(
            icon: LucideIcons.audioLines,
            label: 'Equalizer',
            onTap: () => _showEqualizer(context),
          ),
          _Utility(
            icon: LucideIcons.listMusic,
            label: 'Queue',
            onTap: () => _showQueue(context),
          ),
          _Utility(
            icon: LucideIcons.download,
            label: 'Download',
            onTap: () =>
                context.read<PlayerBloc>().add(DownloadSongEvent(song)),
          ),
          _Utility(
            icon: LucideIcons.share2,
            label: 'Share',
            onTap: () {
              final id = song.youtubeId ?? song.id;
              Share.share(
                '${song.title} — ${song.artist}\nhttps://music.youtube.com/watch?v=$id',
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Utility extends StatelessWidget {
  const _Utility({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerArtworkFallback extends StatelessWidget {
  const _PlayerArtworkFallback();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(gradient: PrismColors.spectrum),
    child: Icon(LucideIcons.music2, color: PrismColors.ink, size: 72),
  );
}

void _showEqualizer(BuildContext context) {
  final audio = getIt<AudioPlayerService>();
  showShadSheet(
    context: context,
    side: ShadSheetSide.bottom,
    builder: (_) => EqualizerBottomSheet(equalizerService: audio.equalizer),
  );
}

void _showQueue(BuildContext context) {
  showShadSheet(
    context: context,
    side: ShadSheetSide.bottom,
    builder: (_) => const PlayerQueueSheet(),
  );
}

int mathMax(int a, int b) => a > b ? a : b;
