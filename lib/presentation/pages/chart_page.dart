import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/chart_service.dart';
import '../../domain/entities/song.dart';
import '../blocs/player/player.dart';
import '../theme/prism_theme.dart';
import '../widgets/prism/prism_chart_chip.dart';
import '../widgets/prism/prism_skeleton.dart';
import '../widgets/prism/prism_song_tile.dart';
import '../widgets/prism/prism_states.dart';
import '../widgets/player/mini_player.dart';

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
    final spec = context.prismSpec;
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
                  : CustomScrollView(
                      physics: const BouncingScrollPhysics(),
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
                                border: Border.all(color: spec.hairline),
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
                                        size: 46,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.chart.name,
                                              style: theme
                                                  .textTheme.titleLarge
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -0.4,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${chartSourceLabel(widget.chart.source)}'
                                              '${widget.chart.isDiscoveryMix ? ' · Discovery Mix' : ''}'
                                              '${widget.chart.region == null ? '' : ' · ${widget.chart.region}'}'
                                              ' · ${_songs.length} songs',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    widget.chart.description,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (widget.chart.isDiscoveryMix) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: spec.accentSoft,
                                        borderRadius: BorderRadius.circular(
                                          PrismRadius.sm,
                                        ),
                                        border: Border.all(color: spec.hairline),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline_rounded,
                                            size: 14,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Curated Discovery Mix — Based on trending search popularity, not certified official ranks.',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                color:
                                                    theme.colorScheme.onSurface,
                                                height: 1.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: () => _play(0),
                                          icon: const Icon(
                                            Icons.play_arrow_rounded,
                                          ),
                                          label: const Text('Play all'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        tooltip: 'Shuffle play',
                                        onPressed: _playShuffled,
                                        icon:
                                            const Icon(Icons.shuffle_rounded),
                                        style: IconButton.styleFrom(
                                          backgroundColor: theme.colorScheme
                                              .surfaceContainerHigh,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 40),
                          sliver: SliverList.builder(
                            itemCount: _songs.length,
                            itemBuilder: (context, index) {
                              final song = _songs[index];
                              return BlocBuilder<PlayerBloc, PlayerState>(
                                builder: (context, playerState) =>
                                    PrismSongTile(
                                  song: song,
                                  index: index,
                                  numbered: !widget.chart.isDiscoveryMix,
                                  isPlaying:
                                      playerState.currentSong?.id == song.id,
                                  isPlayingPaused: !playerState.isPlaying,
                                  onTap: () => _play(index),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}
