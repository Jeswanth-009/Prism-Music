import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/di/injection.dart';
import '../../../domain/entities/song.dart';
import '../../../domain/entities/stream_info.dart';
import '../../../domain/repositories/music_repository.dart';
import '../../blocs/player/player.dart';
import '../../theme/prism_theme.dart';

/// Lyrics view for the player: synced lines auto-scroll with playback,
/// plain lyrics render as a simple column.
class PlayerLyricsView extends StatefulWidget {
  const PlayerLyricsView({super.key, required this.song});

  final Song song;

  @override
  State<PlayerLyricsView> createState() => _PlayerLyricsViewState();
}

class _PlayerLyricsViewState extends State<PlayerLyricsView> {
  Lyrics? _lyrics;
  bool _loading = true;
  String? _error;
  int _activeLine = -1;
  final ItemScrollController _scrollController = ItemScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PlayerLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _activeLine = -1;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await getIt<MusicRepository>()
        .getLyrics(widget.song.title, widget.song.artist);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _error = failure.message;
        _loading = false;
      }),
      (lyrics) => setState(() {
        _lyrics = lyrics;
        _loading = false;
      }),
    );
  }

  void _syncToPosition(Duration position) {
    final synced = _lyrics?.syncedLyrics;
    if (synced == null || synced.isEmpty) return;
    final ms = position.inMilliseconds;
    var index = -1;
    for (var i = 0; i < synced.length; i++) {
      if (synced[i].startTimeMs <= ms) index = i;
      if (synced[i].startTimeMs > ms) break;
    }
    if (index != _activeLine) {
      setState(() => _activeLine = index);
      if (index >= 0 && _scrollController.isAttached) {
        _scrollController.scrollTo(
          index: index,
          duration: PrismMotion.base,
          curve: PrismMotion.curve,
          alignment: 0.3,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _lyrics == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lyrics_outlined,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: .5),
              ),
              const SizedBox(height: 10),
              Text(
                'Lyrics not found for this song',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final lyrics = _lyrics!;
    if (lyrics.isSynced) {
      final lines = lyrics.syncedLyrics!;
      return BlocListener<PlayerBloc, PlayerState>(
        // Only react when the playback position advances so UI events
        // (play/pause etc.) don't trigger redundant scrolls.
        listenWhen: (prev, next) =>
            prev.position.inMilliseconds != next.position.inMilliseconds,
        listener: (context, state) => _syncToPosition(state.position),
        child: ScrollablePositionedList.builder(
          itemScrollController: _scrollController,
          itemCount: lines.length,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
          itemBuilder: (context, index) {
            final line = lines[index];
            final isActive = index == _activeLine;
            final isPast = _activeLine >= 0 && index < _activeLine;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: AnimatedDefaultTextStyle(
                duration: PrismMotion.base,
                style: (theme.textTheme.headlineSmall ?? const TextStyle())
                    .copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  height: 1.25,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(
                          alpha: isPast ? 0.30 : 0.65,
                        ),
                ),
                child: Text(line.text.trim()),
              ),
            );
          },
        ),
      );
    }

    // Plain lyrics
    final plainLines = (lyrics.plainLyrics ?? '')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      itemCount: plainLines.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          plainLines[index],
          style: theme.textTheme.titleMedium?.copyWith(
            height: 1.4,
            color: theme.colorScheme.onSurface.withValues(alpha: .8),
          ),
        ),
      ),
    );
  }
}
