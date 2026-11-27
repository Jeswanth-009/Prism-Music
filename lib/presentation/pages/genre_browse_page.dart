import 'package:flutter/material.dart';
import '../../core/services/genre_service.dart';
import '../theme/prism_theme.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/prism/prism_states.dart';
import 'genre_detail_page.dart';

/// Full-page browser for musical genres and mood playlists.
class GenreBrowsePage extends StatefulWidget {
  const GenreBrowsePage({super.key});

  @override
  State<GenreBrowsePage> createState() => _GenreBrowsePageState();
}

class _GenreBrowsePageState extends State<GenreBrowsePage> {
  final _searchController = TextEditingController();
  int _selectedFilterIndex = 0; // 0: All, 1: Genres, 2: Moods
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MusicGenre> _getFilteredGenres() {
    List<MusicGenre> baseList;
    switch (_selectedFilterIndex) {
      case 1:
        baseList = GenreService.instance.getGenresOnly();
        break;
      case 2:
        baseList = GenreService.instance.getMoodsOnly();
        break;
      default:
        baseList = GenreService.instance.getAllGenres();
    }

    if (_searchQuery.trim().isEmpty) return baseList;
    final query = _searchQuery.trim().toLowerCase();
    return baseList
        .where((g) =>
            g.name.toLowerCase().contains(query) ||
            g.description.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.sizeOf(context).width > 600;
    final filtered = _getFilteredGenres();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Genres & Moods',
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
                      // Search box
                      TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search genres, moods, vibes...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
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
                      // Filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildFilterChip(0, 'All Categories'),
                            const SizedBox(width: 8),
                            _buildFilterChip(1, 'Music Genres'),
                            const SizedBox(width: 8),
                            _buildFilterChip(2, 'Moods & Activities'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: PrismErrorState(
                    title: _searchQuery.isNotEmpty ? 'No genres found' : 'Could not load genres',
                    message: _searchQuery.isNotEmpty
                        ? 'No genres match "$_searchQuery".'
                        : 'No genres or moods available.',
                    onRetry: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _selectedFilterIndex = 0;
                      });
                    },
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isTablet ? 3 : 2,
                      childAspectRatio: 1.15,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final genre = filtered[index];
                        return _GenreCard(
                          genre: genre,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => GenreDetailPage(genre: genre),
                              ),
                            );
                          },
                        );
                      },
                      childCount: filtered.length,
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

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    final theme = Theme.of(context);
    final spec = context.prismSpec;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedFilterIndex = index;
        });
      },
      selectedColor: spec.accentSoft,
      labelStyle: PrismText.overline(context)?.copyWith(
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _GenreCard extends StatelessWidget {
  final MusicGenre genre;
  final VoidCallback onTap;

  const _GenreCard({required this.genre, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = context.prismSpec;
    final hue = genre.gradient.first;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            hue.withValues(alpha: 0.14),
            theme.colorScheme.surfaceContainer,
          ),
          borderRadius: BorderRadius.circular(PrismRadius.lg),
          border: Border.all(color: spec.hairline),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(PrismRadius.lg),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                bottom: -10,
                child: Icon(
                  genre.icon,
                  size: 78,
                  color: hue.withValues(alpha: 0.14),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(PrismSpacing.md + 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      genre.name,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: PrismSpacing.xs),
                    Text(
                      '${genre.playlistCount} playlists',
                      style: PrismText.tabular(
                        theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: PrismSpacing.sm,
                        vertical: PrismSpacing.xxs + 1,
                      ),
                      decoration: BoxDecoration(
                        color: hue.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(PrismRadius.xs),
                      ),
                      child: Text(
                        genre.isMood ? 'MOOD' : 'GENRE',
                        style: PrismText.overline(context)?.copyWith(
                          color: hue,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
