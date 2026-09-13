import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/services/chart_service.dart';
import '../../domain/entities/song.dart';
import '../blocs/player/player.dart';
import '../theme/prism_theme.dart';

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
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar.large(
              leading: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(LucideIcons.chevronLeft),
              ),
              title: Text(widget.chart.name),
              expandedHeight: 260,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF314CC5), Color(0xFF753BC2), Color(0xFFB83D91)],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 96, 20, 20),
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PrismSpectrumLine(width: 54),
                      const SizedBox(height: 12),
                      Text(
                        widget.chart.description,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(LucideIcons.refreshCw),
                    label: const Text('Retry chart'),
                  ),
                ),
              )
            else if (_songs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No chart songs are available right now.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Text(
                        '${_songs.length} SONGS',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      IconButton.filled(
                        tooltip: 'Play chart',
                        onPressed: () => _play(0),
                        icon: const Icon(LucideIcons.play),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverList.separated(
                  itemCount: _songs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 5),
                      onTap: () => _play(index),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${index + 1}'.padLeft(2, '0'),
                              style: TextStyle(
                                color: index < 3
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox.square(
                              dimension: 48,
                              child: song.thumbnailUrl.isEmpty
                                  ? Container(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHigh,
                                      child: const Icon(LucideIcons.music2),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: song.thumbnailUrl,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(song.durationFormatted),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
