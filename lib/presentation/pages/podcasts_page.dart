import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/services/podcast_service.dart';
import '../../domain/entities/podcast.dart';
import '../theme/prism_theme.dart';
import '../widgets/player/mini_player.dart';
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
    setState(() => _isLoading = true);
    final subs = PodcastService.instance.getSubscribedPodcasts();
    final results = await PodcastService.instance.getFeaturedPodcasts(query: _activeCategory);
    if (mounted) {
      setState(() {
        _subscribedPodcasts = subs;
        _podcasts = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      _loadCategory(_activeCategory);
      return;
    }
    setState(() => _isLoading = true);
    final results = await PodcastService.instance.searchPodcasts(query);
    if (mounted) {
      setState(() {
        _podcasts = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCategory(String category) async {
    setState(() {
      _activeCategory = category.toLowerCase();
      _isLoading = true;
    });
    final results = await PodcastService.instance.getFeaturedPodcasts(query: _activeCategory);
    if (mounted) {
      setState(() {
        _podcasts = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.sizeOf(context).width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Podcasts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search field
                      TextField(
                        controller: _searchController,
                        onSubmitted: _search,
                        decoration: InputDecoration(
                          hintText: 'Search podcasts, hosts, shows...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadCategory(_activeCategory);
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Category chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: _categories.map((cat) {
                            final isSelected = _activeCategory == cat.toLowerCase();
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(cat),
                                selected: isSelected,
                                selectedColor: PrismColors.accentDark,
                                onSelected: (_) => _loadCategory(cat),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : null,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      'Your Subscriptions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 140,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _subscribedPodcasts.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: sub.artworkUrl,
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(color: Colors.white10),
                                  errorWidget: (_, __, ___) => Container(
                                    color: Colors.white10,
                                    child: const Icon(Icons.podcasts_rounded),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 90,
                                child: Text(
                                  sub.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Explore Shows',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
              else if (_podcasts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 48, color: Colors.white24),
                        const SizedBox(height: 12),
                        Text(
                          'No podcasts found',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isTablet ? 3 : 2,
                      childAspectRatio: 0.78,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
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
                              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AspectRatio(
                                  aspectRatio: 1,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: podcast.artworkUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: Colors.white10),
                                      errorWidget: (_, __, ___) => Container(
                                        color: Colors.white10,
                                        child: const Icon(Icons.podcasts_rounded, size: 36),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  podcast.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  podcast.author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
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
