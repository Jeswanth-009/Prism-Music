import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/search/search_bloc.dart';
import '../../blocs/search/search_event.dart';
import '../../blocs/search/search_state.dart';
import '../../pages/genre_browse_page.dart';
import '../../theme/prism_theme.dart';
import '../prism/prism_dialog.dart';
import '../prism/prism_section_header.dart';

/// Discovery landing view rendered when search query is empty.
/// Contains recent search history chips with quick delete and categorized genre/mood tiles.
/// Uses pure vector iconography with zero emojis.
class SearchDiscoveryView extends StatelessWidget {
  const SearchDiscoveryView({
    super.key,
    required this.onApplyQuery,
  });

  final ValueChanged<String> onApplyQuery;

  static const _curatedGenres = [
    _CategoryTileData('Telugu Hits', [Color(0xFF4A148C), Color(0xFF7B1FA2)]),
    _CategoryTileData('Bollywood', [Color(0xFF880E4F), Color(0xFFAD1457)]),
    _CategoryTileData('Tamil Beats', [Color(0xFF0D47A1), Color(0xFF1976D2)]),
    _CategoryTileData('Global Pop', [Color(0xFF1A237E), Color(0xFF3949AB)]),
    _CategoryTileData('Lo-Fi & Chill', [Color(0xFF004D40), Color(0xFF00897B)]),
    _CategoryTileData('Hip-Hop', [Color(0xFF263238), Color(0xFF455A64)]),
    _CategoryTileData('Rock & Metal', [Color(0xFF212121), Color(0xFF424242)]),
    _CategoryTileData('Devotional', [Color(0xFFE65100), Color(0xFFF57C00)]),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        final entries = state.historyEntries.isNotEmpty
            ? state.historyEntries
            : state.history.map((q) => {'query': q, 'id': q}).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entries.isNotEmpty) ...[
              PrismSectionHeader(
                title: 'Recent searches',
                actionLabel: 'Clear all',
                onAction: () {
                  showPrismConfirmDialog(
                    context: context,
                    title: 'Clear search history?',
                    message: 'All your recent search terms will be permanently removed.',
                    confirmLabel: 'Clear all',
                    isDestructive: true,
                    onConfirm: () =>
                        context.read<SearchBloc>().add(const ClearHistoryEvent()),
                  );
                },
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: entries.take(8).map((entry) {
                    final query = entry['query'] ?? '';
                    final id = entry['id'] ?? query;

                    return InputChip(
                      avatar: Icon(
                        Icons.history_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      label: Text(query),
                      onPressed: () => onApplyQuery(query),
                      onDeleted: () => context
                          .read<SearchBloc>()
                          .add(RemoveFromHistoryEvent(id)),
                      deleteIconColor:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    );
                  }).toList(),
                ),
              ),
            ],
            PrismSectionHeader(
              title: 'Browse categories',
              actionLabel: 'See all',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const GenreBrowsePage(),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _curatedGenres.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final cat = _curatedGenres[index];
                  return _GenreCard(
                    title: cat.title,
                    colors: cat.gradient,
                    onTap: () => onApplyQuery(cat.title),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryTileData {
  final String title;
  final List<Color> gradient;
  const _CategoryTileData(this.title, this.gradient);
}

class _GenreCard extends StatelessWidget {
  const _GenreCard({
    required this.title,
    required this.colors,
    required this.onTap,
  });

  final String title;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PrismRadius.md),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(PrismRadius.md),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          alignment: Alignment.bottomLeft,
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}
