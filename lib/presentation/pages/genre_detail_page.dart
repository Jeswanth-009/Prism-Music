import 'package:flutter/material.dart';
import '../../core/services/genre_service.dart';
import '../theme/prism_theme.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/prism/prism_states.dart';
import 'curated_playlist_page.dart';

/// Page displaying curated playlists and tracks for a selected music genre or mood.
class GenreDetailPage extends StatelessWidget {
  final MusicGenre genre;

  const GenreDetailPage({super.key, required this.genre});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: isDark ? PrismColors.ink : PrismColors.paper,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    genre.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: PrismColors.onScrim,
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.alphaBlend(
                                genre.gradient.first.withValues(alpha: 0.30),
                                isDark
                                    ? PrismColors.ink
                                    : PrismColors.paper,
                              ),
                              isDark ? PrismColors.ink : PrismColors.paper,
                            ],
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              PrismColors.scrim,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 24,
                        bottom: 48,
                        child: Icon(
                          genre.icon,
                          size: 96,
                          color: genre.gradient.first.withValues(alpha: 0.20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        genre.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.queue_music_rounded,
                            size: PrismIconSize.md,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: PrismSpacing.sm),
                          Text(
                            'Curated Playlists',
                            style: theme.textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Text(
                            '${genre.playlistCount} available',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (genre.playlists.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: PrismErrorState(
                    title: 'No playlists available',
                    message: 'No curated playlists found for ${genre.name}.',
                    onRetry: () => Navigator.maybePop(context),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.88,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final playlist = genre.playlists[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => CuratedPlaylistPage(playlist: playlist),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color.alphaBlend(
                              playlist.gradient.first.withValues(alpha: 0.14),
                              theme.colorScheme.surfaceContainer,
                            ),
                            borderRadius:
                                BorderRadius.circular(PrismRadius.lg),
                            border: Border.all(color: context.prismSpec.hairline),
                          ),
                          padding: const EdgeInsets.all(PrismSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(PrismSpacing.sm),
                                decoration: BoxDecoration(
                                  color: playlist.gradient.first
                                      .withValues(alpha: 0.16),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  playlist.icon,
                                  color: playlist.gradient.first,
                                  size: PrismIconSize.lg,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                playlist.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: PrismSpacing.xs),
                              Text(
                                playlist.category,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: genre.playlists.length,
                  ),
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
