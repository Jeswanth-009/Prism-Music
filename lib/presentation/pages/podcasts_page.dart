import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/services/podcast_service.dart';
import '../../domain/entities/podcast.dart';
import '../theme/prism_theme.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/prism/prism_skeleton.dart';
import '../widgets/prism/prism_states.dart';
import 'podcast_detail_page.dart';

/// Full-page browser and discovery hub for podcasts.
class PodcastsPage extends StatefulWidget {
  const PodcastsPage({super.key});

  @override
  State<PodcastsPage> createState() => _PodcastsPageState();
}

class _PodcastsPageState extends State<PodcastsPage> {
  final _searchController = TextEditingController();
  List<Podcast> _podcasts = [];
  List<Podcast> _subscribedPodcasts = [];
  bool _isLoading = true;
  String? _error;
  String _activeCategory = 'technology';

  static const List<String> _categories = [
    'Technology',
    'News',
    'Comedy',
    'True Crime',
    'Science',
    'Business',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final subs = PodcastService.instance.getSubscribedPodcasts();
      final results = await PodcastService.instance.getFeaturedPodcasts(query: _activeCategory);
      if (mounted) {
        setState(() {
          _subscribedPodcasts = subs;
          _podcasts = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      _loadCategory(_activeCategory);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await PodcastService.instance.searchPodcasts(query);
      if (mounted) {
        setState(() {
          _podcasts = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCategory(String category) async {
    setState(() {
      _activeCategory = category.toLowerCase();
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await PodcastService.instance.getFeaturedPodcasts(query: _activeCategory);
      if (mounted) {
        setState(() {
          _podcasts = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.sizeOf(context).width > 600;

    final spec = context.prismSpec;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Podcasts'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PrismSpacing.gutter,
                    PrismSpacing.sm,
                    PrismSpacing.gutter,
                    PrismSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LISTEN ON',
                        style: PrismText.overline(context)?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: PrismSpacing.xs),
                      Text(
                        'Podcasts & Shows',
                        style: theme.textTheme.headlineLarge,
                      ),
                      const SizedBox(height: PrismSpacing.lg),
                      TextField(
                        controller: _searchController,
                        onSubmitted: _search,
                        decoration: InputDecoration(
                          hintText: 'Search podcasts, hosts, shows...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: PrismIconSize.lg,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadCategory(_activeCategory);
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor:
                              theme.colorScheme.surfaceContainerHigh,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(PrismRadius.pill),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: PrismSpacing.lg,
                            vertical: PrismSpacing.md + 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: PrismSpacing.md + 2),
                      // Category chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: _categories.map((cat) {
                            final isSelected =
                                _activeCategory == cat.toLowerCase();
                            return Padding(
                              padding: const EdgeInsets.only(
                                right: PrismSpacing.sm,
                              ),
                              child: ChoiceChip(
                                label: Text(cat),
                                selected: isSelected,
                                selectedColor: spec.accentSoft,
                                onSelected: (_) => _loadCategory(cat),
                                labelStyle: PrismText.overline(context)
                                    ?.copyWith(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                          .withValues(alpha: 0.6)
                                      : spec.hairline,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    PrismRadius.pill,
                                  ),
                                ),
                                showCheckmark: false,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Subscriptions Shelf
              if (_subscribedPodcasts.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PrismSpacing.gutter,
                      PrismSpacing.lg,
                      PrismSpacing.gutter,
                      PrismSpacing.sm,
                    ),
                    child: Text(
                      'YOUR SUBSCRIPTIONS',
                      style: PrismText.overline(context)?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 148,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: PrismSpacing.gutter,
                      ),
                      scrollDirection: Axis.horizontal,
                      itemCount: _subscribedPodcasts.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: PrismSpacing.railGap),
                      itemBuilder: (context, index) {
                        final sub = _subscribedPodcasts[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => PodcastDetailPage(podcast: sub),
                              ),
                            ).then((_) {
                              setState(() {
                                _subscribedPodcasts = PodcastService.instance.getSubscribedPodcasts();
                              });
                            });
                          },
                          child: SizedBox(
                            width: 92,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipOval(
                                  child: SizedBox(
                                    width: 92,
                                    height: 92,
                                    child: CachedNetworkImage(
                                      imageUrl: sub.artworkUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        color: theme
                                            .colorScheme.surfaceContainerHigh,
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        color: theme
                                            .colorScheme.surfaceContainerHigh,
                                        child: Icon(
                                          Icons.podcasts_rounded,
                                          size: PrismIconSize.lg,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: PrismSpacing.sm),
                                Text(
                                  sub.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PrismSpacing.gutter,
                    PrismSpacing.xl,
                    PrismSpacing.gutter,
                    PrismSpacing.sm,
                  ),
                  child: Text(
                    'Explore Shows',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),

              if (_isLoading)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PrismSpacing.gutter,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 4,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isTablet ? 3 : 2,
                        childAspectRatio: 0.78,
                        crossAxisSpacing: PrismSpacing.railGap,
                        mainAxisSpacing: PrismSpacing.railGap,
                      ),
                      itemBuilder: (_, __) => const PrismSkeletonGroup(
                        child: PrismSkeleton(height: 180),
                      ),
                    ),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: PrismErrorState(
                    title: 'Could not load podcasts',
                    message: _error,
                    onRetry: _loadInitial,
                  ),
                )
              else if (_podcasts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: PrismEmptyState(
                    icon: Icons.search_off_rounded,
                    message: 'No podcasts found',
                    hint: 'Try another category or search term.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    PrismSpacing.gutter,
                    0,
                    PrismSpacing.gutter,
                    100,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isTablet ? 3 : 2,
                      childAspectRatio: 0.78,
                      crossAxisSpacing: PrismSpacing.railGap,
                      mainAxisSpacing: PrismSpacing.railGap,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final podcast = _podcasts[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => PodcastDetailPage(podcast: podcast),
                              ),
                            ).then((_) {
                              setState(() {
                                _subscribedPodcasts = PodcastService.instance.getSubscribedPodcasts();
                              });
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainer,
                              borderRadius:
                                  BorderRadius.circular(PrismRadius.lg),
                              border: Border.all(color: spec.hairline),
                            ),
                            padding: const EdgeInsets.all(PrismSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AspectRatio(
                                  aspectRatio: 1,
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(PrismRadius.md),
                                    child: CachedNetworkImage(
                                      imageUrl: podcast.artworkUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        color: theme
                                            .colorScheme.surfaceContainerHigh,
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        color: theme
                                            .colorScheme.surfaceContainerHigh,
                                        child: Icon(
                                          Icons.podcasts_rounded,
                                          size: PrismIconSize.xl,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: PrismSpacing.sm + 2),
                                Text(
                                  podcast.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall,
                                ),
                                const SizedBox(height: PrismSpacing.xxs + 1),
                                Text(
                                  podcast.author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: _podcasts.length,
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
