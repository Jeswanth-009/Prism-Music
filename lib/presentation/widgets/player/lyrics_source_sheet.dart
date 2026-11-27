import 'package:flutter/material.dart';
import '../../../../domain/entities/entities.dart';
import '../../theme/prism_theme.dart';
import 'lyrics_custom_search_dialog.dart';

/// Modal bottom sheet for selecting and switching lyrics sources,
/// re-downloading, and querying custom titles.
/// Matches the reference UI with provider badges, status descriptions, and checkmark selection.
class LyricsSourceSheet extends StatelessWidget {
  final Song song;
  final Lyrics? currentLyrics;
  final List<LyricsSourceDescriptor> sources;
  final bool isLoading;
  final void Function(String providerId) onSelectSource;
  final VoidCallback onRedownload;
  final void Function(String customTitle, String customArtist) onCustomSearch;

  const LyricsSourceSheet({
    super.key,
    required this.song,
    required this.currentLyrics,
    required this.sources,
    required this.isLoading,
    required this.onSelectSource,
    required this.onRedownload,
    required this.onCustomSearch,
  });

  static Future<void> show(
    BuildContext context, {
    required Song song,
    required Lyrics? currentLyrics,
    required List<LyricsSourceDescriptor> sources,
    required bool isLoading,
    required void Function(String providerId) onSelectSource,
    required VoidCallback onRedownload,
    required void Function(String customTitle, String customArtist) onCustomSearch,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LyricsSourceSheet(
        song: song,
        currentLyrics: currentLyrics,
        sources: sources,
        isLoading: isLoading,
        onSelectSource: onSelectSource,
        onRedownload: onRedownload,
        onCustomSearch: onCustomSearch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeProviderId = currentLyrics?.providerId;
    final currentSourceName = currentLyrics?.source ?? 'current provider';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF13151A),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(PrismRadius.xl),
            ),
            border: Border.all(
              color: PrismColors.onScrim.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PrismColors.onScrim.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title and Re-download button row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lyrics Source',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: PrismColors.onScrim.withValues(alpha: 0.08),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        onRedownload();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Re-download', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),

              // Explanatory subtext
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Re-download fetches $currentSourceName\'s lyrics again and replaces the saved copy',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: PrismColors.onScrim.withValues(alpha: 0.55),
                      height: 1.3,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Provider list
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B1E26),
                              borderRadius: BorderRadius.circular(PrismRadius.lg),
                              border: Border.all(
                                color: PrismColors.onScrim.withValues(alpha: 0.06),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(PrismRadius.lg),
                              child: Column(
                                children: sources.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final desc = entry.value;
                                  final isSelected = activeProviderId == desc.id ||
                                      (activeProviderId == null &&
                                          currentLyrics?.source.toLowerCase() ==
                                              desc.displayName.toLowerCase());

                                  return Column(
                                    children: [
                                      if (index > 0)
                                        Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: PrismColors.onScrim.withValues(alpha: 0.05),
                                        ),
                                      ListTile(
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 4,
                                        ),
                                        enabled: desc.isAvailable,
                                        title: Text(
                                          desc.displayName,
                                          style: theme.textTheme.bodyLarge?.copyWith(
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? const Color(0xFF8AB4F8)
                                                : (desc.isAvailable
                                                    ? Colors.white
                                                    : PrismColors.onScrim.withValues(alpha: 0.4)),
                                          ),
                                        ),
                                        subtitle: Text(
                                          desc.statusDescription,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: isSelected
                                                ? const Color(0xFF8AB4F8).withValues(alpha: 0.8)
                                                : (desc.isAvailable
                                                    ? PrismColors.onScrim.withValues(alpha: 0.55)
                                                    : PrismColors.onScrim.withValues(alpha: 0.3)),
                                          ),
                                        ),
                                        trailing: isSelected
                                            ? const Icon(
                                                Icons.check_rounded,
                                                color: Color(0xFF8AB4F8),
                                                size: 22,
                                              )
                                            : null,
                                        onTap: desc.isAvailable
                                            ? () {
                                                Navigator.pop(context);
                                                onSelectSource(desc.id);
                                              }
                                            : null,
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
              ),

              // Bottom "Search with another title" button
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B1E26),
                        side: BorderSide(
                          color: PrismColors.onScrim.withValues(alpha: 0.1),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(PrismRadius.md),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        LyricsCustomSearchDialog.show(
                          context,
                          initialTitle: song.title,
                          initialArtist: song.artist,
                          onSearch: onCustomSearch,
                        );
                      },
                      child: Text(
                        'Search with another title',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
