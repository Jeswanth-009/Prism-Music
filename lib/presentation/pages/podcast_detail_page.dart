import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/podcast_service.dart';
import '../../domain/entities/podcast.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../theme/prism_theme.dart';
import '../widgets/player/mini_player.dart';

/// Page displaying a podcast series and its streamable episodes.
class PodcastDetailPage extends StatefulWidget {
  final Podcast podcast;

  const PodcastDetailPage({super.key, required this.podcast});

  @override
  State<PodcastDetailPage> createState() => _PodcastDetailPageState();
}

class _PodcastDetailPageState extends State<PodcastDetailPage> {
  List<PodcastEpisode> _episodes = [];
  bool _isLoading = true;
  late bool _isSubscribed;

  @override
  void initState() {
    super.initState();
    _isSubscribed = PodcastService.instance.isSubscribed(widget.podcast.id);
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    setState(() => _isLoading = true);
    final eps = await PodcastService.instance.fetchEpisodes(widget.podcast);
    if (mounted) {
      setState(() {
        _episodes = eps;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSubscription() async {
    if (_isSubscribed) {
      await PodcastService.instance.unsubscribe(widget.podcast.id);
    } else {
      await PodcastService.instance.subscribe(widget.podcast);
    }
    if (mounted) {
      setState(() {
        _isSubscribed = !_isSubscribed;
      });
    }
  }

  void _playEpisode(PodcastEpisode episode) {
    final song = PodcastService.instance.episodeToSong(episode);
    context.read<PlayerBloc>().add(
      PlaySongEvent(song: song, userInitiated: true),
    );
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return '';
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.podcast.title),
        elevation: 0,
      ),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: widget.podcast.artworkUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.podcast.artworkUrl,
                                width: 110,
                                height: 110,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: Colors.white10),
                                errorWidget: (_, __, ___) => Container(
                                  color: Colors.white10,
                                  child: const Icon(Icons.podcasts_rounded, size: 36),
                                ),
                              )
                            : Container(
                                width: 110,
                                height: 110,
                                color: Colors.white10,
                                child: const Icon(Icons.podcasts_rounded, size: 36),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.podcast.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.podcast.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _toggleSubscription,
                              icon: Icon(
                                _isSubscribed ? Icons.check_rounded : Icons.bookmark_add_outlined,
                                size: 16,
                              ),
                              label: Text(_isSubscribed ? 'Subscribed' : 'Subscribe'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isSubscribed
                                    ? Colors.white12
                                    : PrismColors.accentDark,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.podcast.description.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      widget.podcast.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    children: [
                      Text(
                        'Episodes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_episodes.isNotEmpty)
                        Text(
                          '${_episodes.length} episodes',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_episodes.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.podcasts_rounded, size: 48, color: Colors.white24),
                        const SizedBox(height: 12),
                        Text(
                          'No episodes available in this feed',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList.separated(
                    itemCount: _episodes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final ep = _episodes[index];
                      final durationText = _formatDuration(ep.duration);

                      return Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          title: Text(
                            ep.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (durationText.isNotEmpty) ...[
                                    Icon(Icons.schedule_rounded, size: 12, color: theme.colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Text(durationText, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                                    const SizedBox(width: 12),
                                  ],
                                  if (ep.playbackPosition > Duration.zero) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: PrismColors.accentDark.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('In Progress', style: TextStyle(fontSize: 10, color: PrismColors.accentDark, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.play_circle_fill_rounded, size: 36, color: PrismColors.accentDark),
                            onPressed: () => _playEpisode(ep),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
    );
  }
}
