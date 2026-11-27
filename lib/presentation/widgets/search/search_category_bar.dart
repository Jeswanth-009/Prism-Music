import 'package:flutter/material.dart';

import '../../blocs/search/search_event.dart';
import '../../theme/prism_theme.dart';

/// Pinned horizontal filter bar built as a SliverPersistentHeader.
/// Eliminates touch hit-test overlay blocking and allows smooth 120Hz category toggling.
class SearchCategoryBar extends StatelessWidget {
  const SearchCategoryBar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final SearchFilter selected;
  final ValueChanged<SearchFilter> onSelect;

  static const _filters = [
    SearchFilter.all,
    SearchFilter.songs,
    SearchFilter.albums,
    SearchFilter.artists,
    SearchFilter.videos,
    SearchFilter.downloads,
  ];

  static String _labelFor(SearchFilter filter) => switch (filter) {
        SearchFilter.all => 'All',
        SearchFilter.songs => 'Songs',
        SearchFilter.albums => 'Albums',
        SearchFilter.artists => 'Artists',
        SearchFilter.videos => 'Videos',
        SearchFilter.playlists => 'Playlists',
        SearchFilter.downloads => 'Downloaded',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = filter == selected;

          final spec = context.prismSpec;
          return Center(
            child: ChoiceChip(
              label: Text(_labelFor(filter)),
              labelStyle: PrismText.overline(context)?.copyWith(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              selected: isSelected,
              selectedColor: spec.accentSoft,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
              showCheckmark: false,
              side: BorderSide(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.6)
                    : spec.hairline,
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PrismRadius.pill),
              ),
              onSelected: (_) => onSelect(filter),
            ),
          );
        },
      ),
    );
  }
}

/// Persistent sliver delegate holding [SearchCategoryBar] pinned during scroll.
class PinnedCategoryBarDelegate extends SliverPersistentHeaderDelegate {
  final SearchFilter selected;
  final ValueChanged<SearchFilter> onSelect;

  const PinnedCategoryBarDelegate({
    required this.selected,
    required this.onSelect,
  });

  @override
  double get minExtent => 48.0;

  @override
  double get maxExtent => 48.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
      alignment: Alignment.center,
      child: SearchCategoryBar(
        selected: selected,
        onSelect: onSelect,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant PinnedCategoryBarDelegate oldDelegate) {
    return oldDelegate.selected != selected;
  }
}
