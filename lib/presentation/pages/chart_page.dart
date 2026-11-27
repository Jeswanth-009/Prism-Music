import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/chart_service.dart';
import '../../domain/entities/song.dart';
import '../blocs/player/player.dart';
import '../theme/prism_theme.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/prism/prism_chart_chip.dart';
import '../widgets/prism/prism_skeleton.dart';
import '../widgets/prism/prism_song_tile.dart';
import '../widgets/prism/prism_states.dart';

/// Full-fidelity Chart page featuring ranked leaderboards, platform styling,
/// rank delta movements, and high-fidelity playback.
class ChartPage extends StatefulWidget {
  const ChartPage({super.key, required this.chart});
  final ChartDefinition chart;

  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  List<Song> _songs = const [];
  bool _loading = true;
  String? _error;

  Color _getPlatformAccent(ChartSource source, ColorScheme scheme) {
    return switch (source) {
      ChartSource.appleMusic => PrismColors.brandApple,
      ChartSource.spotify => PrismColors.brandSpotify,
      ChartSource.youtube => PrismColors.brandYouTube,
      ChartSource.billboard => PrismColors.brandBillboard,
      ChartSource.kworb => PrismColors.dataTeal,
    };
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final songs = await ChartService.instance.getChartSongs(widget.chart);
      if (!mounted) return;
      setState(() {
        _songs = songs;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _play(int index) {
    context.read<PlayerBloc>().add(
          PlaySongEvent(song: _songs[index], queue: _songs, queueIndex: index),
        );
  }

  void _playShuffled() {
    final shuffled = [..._songs]..shuffle();
    context.read<PlayerBloc>().add(
          PlaySongEvent(song: shuffled.first, queue: shuffled, queueIndex: 0),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platformAccent =
        _getPlatformAccent(widget.chart.source, theme.colorScheme);

    return Scaffold(
      bottomNavigationBar: const PrismPersistentMiniPlayer(),
      appBar: AppBar(
        title: Text(
          widget.chart.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          if (_songs.isNotEmpty)
            IconButton(
              tooltip: 'Play chart',
              onPressed: () => _play(0),
              icon: const Icon(Icons.play_arrow_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: PrismListSkeleton(count: 8),
            )
          : _error != null
              ? PrismErrorState(message: _error, onRetry: _load)
              : _songs.isEmpty
                  ? const PrismEmptyState(
                      icon: Icons.bar_chart_rounded,
                      message: 'No chart songs are available right now.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: platformAccent,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainer,
                                  borderRadius:
                                      BorderRadius.circular(PrismRadius.lg),
                                  border: Border.all(
                                    color: platformAccent.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        PrismChartChip(
                                          type: widget.chart.iconType,
                                          size: 48,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: platformAccent
                                                          .withValues(
                                                              alpha: 0.15),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              PrismRadius.pill),
                                                    ),
                                                    child: Text(
                                                      chartSourceLabel(
                                                          widget.chart.source),
                                                      style: PrismText
                                                          .overline(context)
                                                          ?.copyWith(
                                                        color: platformAccent,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${_songs.length} songs',
                                                    style: theme
                                                        .textTheme.labelSmall
                                                        ?.copyWith(
                                                      color: theme.colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                widget.chart.name,
                                                style: theme
                                                    .textTheme.titleLarge,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      widget.chart.description,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: platformAccent
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(
                                            PrismRadius.sm),
                                        border: Border.all(
                                          color: platformAccent
                                            .withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.verified_rounded,
                                            size: 15,
                                            color: platformAccent,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Certified Official Rankings',
                                                  style: PrismText
                                                      .overline(context)
                                                      ?.copyWith(
                                                    color: platformAccent,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  widget.chart.provenance ??
                                                      'Verified official rankings from primary chart and streaming provider feeds.',
                                                  style: theme
                                                      .textTheme.labelSmall
                                                      ?.copyWith(
                                                    color: theme
                                                        .colorScheme.onSurface,
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: FilledButton.icon(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: platformAccent,
                                              foregroundColor:
                                                  PrismColors.onColor(
                                                platformAccent,
                                              ),
                                            ),
                                            onPressed: () => _play(0),
                                            icon: const Icon(
                                              Icons.play_arrow_rounded,
                                            ),
                                            label: const Text('Play all'),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        IconButton.filledTonal(
                                          tooltip: 'Shuffle Play',
                                          onPressed: _playShuffled,
                                          icon:
                                              const Icon(Icons.shuffle_rounded),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                            sliver: SliverList.builder(
                              itemCount: _songs.length,
                              itemBuilder: (context, index) {
                                final song = _songs[index];
                                final rank = index + 1;

                                return BlocBuilder<PlayerBloc, PlayerState>(
                                  buildWhen: (prev, curr) =>
                                      (prev.currentSong?.id == song.id) !=
                                          (curr.currentSong?.id == song.id) ||
                                      (prev.isPlaying != curr.isPlaying &&
                                          curr.currentSong?.id == song.id),
                                  builder: (context, playerState) {
                                    return Row(
                                      children: [
                                        _buildRankBadge(
                                            theme, rank, platformAccent, song),
                                        Expanded(
                                          child: PrismSongTile(
                                            song: song,
                                            numbered: false,
                                            showOverflowAction: true,
                                            isPlaying:
                                                playerState.currentSong?.id ==
                                                    song.id,
                                            isPlayingPaused:
                                                !playerState.isPlaying,
                                            onTap: () => _play(index),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildRankBadge(
      ThemeData theme, int rank, Color accent, Song song) {
    Color badgeColor;
    Color textColor;

    if (rank == 1) {
      badgeColor = PrismColors.medalGold;
      textColor = PrismColors.onColor(badgeColor);
    } else if (rank == 2) {
      badgeColor = PrismColors.medalSilver;
      textColor = PrismColors.onColor(badgeColor);
    } else if (rank == 3) {
      badgeColor = PrismColors.medalBronze;
      textColor = PrismColors.onColor(badgeColor);
    } else {
      badgeColor = Colors.transparent;
      textColor = theme.colorScheme.onSurfaceVariant;
    }

    // Parse movement delta from recommendationReason
    Widget? deltaWidget;
    final reason = song.recommendationReason ?? '';
    final spec = context.prismSpec;
    if (reason.contains('▲')) {
      final delta = RegExp(r'▲\s*(\d*)').firstMatch(reason)?.group(1);
      deltaWidget = Text(
        '▲${delta != null && delta.isNotEmpty ? ' $delta' : ''}',
        style: PrismText.tabular(
          PrismText.overline(context)?.copyWith(
            fontSize: 9,
            color: spec.success,
          ),
        ),
      );
    } else if (reason.contains('▼')) {
      final delta = RegExp(r'▼\s*(\d*)').firstMatch(reason)?.group(1);
      deltaWidget = Text(
        '▼${delta != null && delta.isNotEmpty ? ' $delta' : ''}',
        style: PrismText.tabular(
          PrismText.overline(context)?.copyWith(
            fontSize: 9,
            color: theme.colorScheme.error,
          ),
        ),
      );
    } else if (reason.contains('● NEW')) {
      deltaWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: PrismColors.dataViolet.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(PrismRadius.xs),
        ),
        child: Text(
          'NEW',
          style: PrismText.overline(context)?.copyWith(
            fontSize: 8,
            color: PrismColors.dataViolet,
          ),
        ),
      );
    } else if (reason.contains('→')) {
      deltaWidget = Text(
        '→',
        style: PrismText.overline(context)?.copyWith(
          fontSize: 10,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Container(
      width: 44,
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          rank <= 3
              ? Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: badgeColor.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: PrismText.tabular(
                        PrismText.overline(context)?.copyWith(
                          fontSize: 11,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                )
              : Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: PrismText.tabular(
                    theme.textTheme.labelMedium?.copyWith(
                      color: textColor,
                    ),
                  ),
                ),
          if (deltaWidget != null) ...[
            const SizedBox(height: 2),
            deltaWidget,
          ],
        ],
      ),
    );
  }
}
