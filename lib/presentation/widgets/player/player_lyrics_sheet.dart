import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/injection.dart';
import '../../../domain/entities/song.dart';
import '../../../domain/entities/stream_info.dart';
import '../../../domain/repositories/music_repository.dart';
import '../../blocs/player/player.dart';
import '../../theme/prism_theme.dart';

/// Lyrics view for the player: synced lines auto-scroll with playback,
/// plain lyrics render as a simple column.
///
/// Requests are guarded against staleness — a slow lookup for song A can
/// never overwrite lyrics after the user has moved to song B. Results are
/// cached locally by the data source; the refresh control bypasses it.
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
  int _userOffsetMs = 0;
  bool _followCurrentLine = true;

  /// Bumped on every load; results from superseded requests are dropped.
  int _requestId = 0;
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
      _userOffsetMs = 0;
      _followCurrentLine = true;
      _load();
    }
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await getIt<MusicRepository>().getLyrics(
      widget.song.title,
      widget.song.artist,
      // Only trust the duration when it is plausible — placeholder or zero
      // durations would push LRCLIB towards wrong-version matches.
      duration: widget.song.duration.inSeconds >= 30
          ? widget.song.duration
          : null,
      forceRefresh: forceRefresh,
    );
    if (!mounted || requestId != _requestId) return;
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

  String _formatLineTime(int ms) {
    final totalSeconds = (ms / 1000).floor();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _toggleFollow() {
    final next = !_followCurrentLine;
    setState(() => _followCurrentLine = next);
    if (next && _activeLine >= 0 && _scrollController.isAttached) {
      _scrollController.scrollTo(
        index: _activeLine,
        duration: PrismMotion.base,
        curve: PrismMotion.curve,
        alignment: 0.3,
      );
    }
  }

  void _syncToPosition(Duration position) {
    final synced = _lyrics?.syncedLyrics;
    if (synced == null || synced.isEmpty) return;
    final ms = position.inMilliseconds - _userOffsetMs;
    var index = -1;
    for (var i = 0; i < synced.length; i++) {
      if (synced[i].startTimeMs <= ms) index = i;
      if (synced[i].startTimeMs > ms) break;
    }
    if (index != _activeLine) {
      setState(() => _activeLine = index);
      if (_followCurrentLine && index >= 0 && _scrollController.isAttached) {
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
      return _LyricsMessage(
        icon: Icons.lyrics_outlined,
        message: _error ?? 'Lyrics not found for this song',
        actionLabel: 'Retry',
        onAction: () => _load(),
      );
    }

    final lyrics = _lyrics!;
    if (lyrics.isSynced) {
      final lines = lyrics.syncedLyrics!;
      return Column(
        children: [
          Expanded(
            child: NotificationListener<UserScrollNotification>(
              onNotification: (notification) {
                if (notification.direction != ScrollDirection.idle) {
                  if (_followCurrentLine) {
                    setState(() => _followCurrentLine = false);
                  }
                }
                return false;
              },
              child: BlocListener<PlayerBloc, PlayerState>(
                // Only react when the playback position advances so UI events
                // (play/pause etc.) don't trigger redundant scrolls.
                listenWhen: (prev, next) =>
                    prev.position.inMilliseconds != next.position.inMilliseconds,
                listener: (context, state) => _syncToPosition(state.position),
                child: ScrollablePositionedList.builder(
                  itemScrollController: _scrollController,
                  itemCount: lines.length,
                  padding: const EdgeInsets.fromLTRB(28, 60, 28, 16),
                  itemBuilder: (context, index) {
                    final line = lines[index];
                    final isActive = index == _activeLine;
                    final isPast = _activeLine >= 0 && index < _activeLine;
                    final timeLabel = _formatLineTime(line.startTimeMs);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Material(
                        color: isActive
                            ? theme.colorScheme.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(PrismRadius.md),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(PrismRadius.md),
                          onTap: () {
                            final seekPositionMs = (line.startTimeMs +
                                    _userOffsetMs)
                                .clamp(
                              0,
                              widget.song.duration.inMilliseconds > 0
                                  ? widget.song.duration.inMilliseconds
                                  : 0x7fffffff,
                            );
                            context.read<PlayerBloc>().add(
                                  SeekEvent(
                                    Duration(milliseconds: seekPositionMs),
                                  ),
                                );
                            setState(() => _followCurrentLine = true);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: AnimatedDefaultTextStyle(
                                    duration: PrismMotion.base,
                                    style: (theme.textTheme.headlineSmall ??
                                            const TextStyle())
                                        .copyWith(
                                      fontWeight: isActive
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      letterSpacing: -0.4,
                                      height: 1.25,
                                      color: isActive
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface
                                              .withValues(
                                              alpha: isPast ? 0.35 : 0.70,
                                            ),
                                    ),
                                    child: Text(line.text.trim()),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AnimatedOpacity(
                                  duration: PrismMotion.base,
                                  opacity: isActive ? 1.0 : 0.0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(
                                        PrismRadius.xs,
                                      ),
                                    ),
                                    child: Text(
                                      timeLabel,
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (!_followCurrentLine && _activeLine >= 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                ),
                onPressed: () {
                  setState(() => _followCurrentLine = true);
                  if (_activeLine >= 0 && _scrollController.isAttached) {
                    _scrollController.scrollTo(
                      index: _activeLine,
                      duration: PrismMotion.base,
                      curve: PrismMotion.curve,
                      alignment: 0.3,
                    );
                  }
                },
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Follow current line'),
              ),
            ),
          _LyricsFooter(
            isSynced: true,
            syncOffsetMs: _userOffsetMs,
            followCurrentLine: _followCurrentLine,
            onToggleFollow: _toggleFollow,
            onAdjustSync: (delta) {
              setState(() => _userOffsetMs += delta);
              final state = context.read<PlayerBloc>().state;
              _syncToPosition(state.position);
            },
            onResetSync: () {
              setState(() => _userOffsetMs = 0);
              final state = context.read<PlayerBloc>().state;
              _syncToPosition(state.position);
            },
            onRefresh: () => _load(forceRefresh: true),
          ),
        ],
      );
    }

    // Plain lyrics
    final plainLines = (lyrics.plainLyrics ?? '')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 16),
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
          ),
        ),
        _LyricsFooter(
          onRefresh: () => _load(forceRefresh: true),
        ),
      ],
    );
  }
}

/// Error / not-found state with a retry action.
class _LyricsMessage extends StatelessWidget {
  const _LyricsMessage({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOutage = message.toLowerCase().contains('unavailable') ||
        message.toLowerCase().contains('network') ||
        message.toLowerCase().contains('timeout');

    final displayIcon = isOutage ? Icons.cloud_off_rounded : icon;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              displayIcon,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: .5),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Attribution + sync correction + manual refresh shown below lyrics views.
class _LyricsFooter extends StatelessWidget {
  const _LyricsFooter({
    required this.onRefresh,
    this.isSynced = false,
    this.syncOffsetMs = 0,
    this.followCurrentLine = true,
    this.onToggleFollow,
    this.onAdjustSync,
    this.onResetSync,
  });

  final VoidCallback onRefresh;
  final bool isSynced;
  final int syncOffsetMs;
  final bool followCurrentLine;
  final VoidCallback? onToggleFollow;
  final void Function(int deltaMs)? onAdjustSync;
  final VoidCallback? onResetSync;

  void _showSyncModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        var currentOffset = syncOffsetMs;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(sheetContext);
            final offsetSeconds = (currentOffset / 1000).toStringAsFixed(1);
            final offsetSign = currentOffset > 0 ? '+' : '';
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lyrics Sync Correction',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Current offset: $offsetSign${offsetSeconds}s ($offsetSign${currentOffset}ms)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.tonal(
                          onPressed: () {
                            onAdjustSync?.call(-500);
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('-0.5s'),
                        ),
                        FilledButton.tonal(
                          onPressed: () {
                            onAdjustSync?.call(-100);
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('-0.1s'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            onResetSync?.call();
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('Reset'),
                        ),
                        FilledButton.tonal(
                          onPressed: () {
                            onAdjustSync?.call(100);
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('+0.1s'),
                        ),
                        FilledButton.tonal(
                          onPressed: () {
                            onAdjustSync?.call(500);
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('+0.5s'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Negative values advance lyrics; positive values delay them.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () async {
                final url = Uri.parse('https://lrclib.net');
                try {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } catch (_) {
                  // Attribution link is best-effort.
                }
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
              ),
              child: Text(
                'Lyrics provided by LRCLIB',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          if (isSynced) ...[
            IconButton(
              tooltip: followCurrentLine
                  ? 'Auto-follow is ON (click to disable)'
                  : 'Auto-follow is OFF (click to enable)',
              onPressed: onToggleFollow,
              icon: Icon(
                followCurrentLine
                    ? Icons.vertical_align_center_rounded
                    : Icons.pan_tool_outlined,
                size: 20,
                color: followCurrentLine
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            IconButton(
              tooltip: syncOffsetMs == 0
                  ? 'Adjust sync timing'
                  : 'Sync offset: ${syncOffsetMs > 0 ? "+" : ""}${(syncOffsetMs / 1000).toStringAsFixed(1)}s',
              onPressed: () => _showSyncModal(context),
              icon: Badge(
                isLabelVisible: syncOffsetMs != 0,
                label: Text(
                  '${syncOffsetMs > 0 ? "+" : ""}${(syncOffsetMs / 1000).toStringAsFixed(1)}s',
                ),
                child: Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: syncOffsetMs != 0
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          IconButton(
            tooltip: 'Refresh lyrics',
            onPressed: onRefresh,
            icon: Icon(
              Icons.refresh_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
