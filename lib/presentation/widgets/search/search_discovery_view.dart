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
/// Recent search history chips, then genre tiles: quiet cards tinted by
/// one data hue each — the hue identifies the genre, the chrome stays
/// neutral so nearby artwork carries the colour.
class SearchDiscoveryView extends StatelessWidget {
  const SearchDiscoveryView({
    super.key,
    required this.onApplyQuery,
  });

  final ValueChanged<String> onApplyQuery;

  static const _genreTitles = [
    'Telugu Hits',
    'Bollywood',
    'Tamil Beats',
    'Global Pop',
    'Lo-Fi & Chill',
    'Hip-Hop',
    'Rock & Metal',
    'Devotional',
  ];

  static const _genreHues = <String, Color>{
    'Telugu Hits': PrismColors.dataViolet,
    'Bollywood': PrismColors.dataPink,
    'Tamil Beats': PrismColors.dataBlue,
    'Global Pop': PrismColors.dataTeal,
    'Lo-Fi & Chill': PrismColors.dataAmber,
    'Hip-Hop': PrismColors.dataCoral,
    'Rock & Metal': PrismColors.dataSlate,
    'Devotional': PrismColors.dataOrange,
  };

  Color _hueFor(String title) =>
      _genreHues[title] ??
      // A genre outside the curated eight still gets a stable hue.
      PrismColors
          .dataHues[title.hashCode.abs() % PrismColors.dataHues.length];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        final entries = state.historyEntries.isNotEmpty
            ? state.historyEntries
            : state.history.map((q) => {'query': q, 'id': q}).toList();

        final genres = _genreTitles;

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
                padding: const EdgeInsets.fromLTRB(
                  PrismSpacing.gutter,
                  PrismSpacing.lg,
                  PrismSpacing.gutter,
                  PrismSpacing.sm,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PrismSpacing.gutter,
                ),
                child: Wrap(
                  spacing: PrismSpacing.sm,
                  runSpacing: PrismSpacing.sm,
                  children: entries.take(8).map((entry) {
                    final query = entry['query'] ?? '';
                    final id = entry['id'] ?? query;

                    return InputChip(
                      avatar: Icon(
                        Icons.history_rounded,
                        size: PrismIconSize.sm,
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
              padding: const EdgeInsets.fromLTRB(
                PrismSpacing.gutter,
                PrismSpacing.xl + 2,
                PrismSpacing.gutter,
                PrismSpacing.md + 2,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PrismSpacing.gutter,
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: genres.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.3,
                  crossAxisSpacing: PrismSpacing.railGap,
                  mainAxisSpacing: PrismSpacing.railGap,
                ),
                itemBuilder: (context, index) {
                  final genre = genres[index];
                  return _GenreCard(
                    title: genre,
                    hue: _hueFor(genre),
                    onTap: () => onApplyQuery(genre),
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

class _GenreCard extends StatelessWidget {
  const _GenreCard({
    required this.title,
    required this.hue,
    required this.onTap,
  });

  final String title;
  final Color hue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = context.prismSpec;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PrismRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              hue.withValues(alpha: 0.14),
              theme.colorScheme.surfaceContainer,
            ),
            borderRadius: BorderRadius.circular(PrismRadius.md),
            border: Border.all(color: spec.hairline),
          ),
          padding: const EdgeInsets.all(PrismSpacing.md),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: hue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: PrismSpacing.sm),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
