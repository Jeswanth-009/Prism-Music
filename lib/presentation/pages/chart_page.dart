import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/chart_service.dart';
import '../../domain/entities/song.dart';
import '../blocs/player/player.dart';
import '../widgets/prism/prism_skeleton.dart';
import '../widgets/prism/prism_song_tile.dart';
import '../widgets/prism/prism_states.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
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
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                            child: Text(
                              widget.chart.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
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
                                  numbered: true,
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
