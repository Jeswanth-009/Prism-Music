import 'package:flutter/material.dart';

import '../../../domain/entities/playlist.dart';
import '../../pages/playlist_detail_page.dart';
import '../../theme/prism_theme.dart';
import '../prism/prism_section_header.dart';
import '../prism/prism_states.dart';
import 'library_playlist_card.dart';

/// Playlists section in the library, including search filter and grid display.
class LibraryPlaylistsSection extends StatelessWidget {
  const LibraryPlaylistsSection({
    super.key,
    required this.playlists,
    required this.showSearch,
    required this.searchController,
    required this.onToggleSearch,
    required this.onSearchChanged,
    required this.onCreatePlaylist,
    required this.onPlayPlaylist,
    required this.onRenamePlaylist,
    required this.onExportPlaylist,
    required this.onDeletePlaylist,
  });

  final List<Playlist> playlists;
  final bool showSearch;
  final TextEditingController searchController;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCreatePlaylist;
  final void Function(Playlist) onPlayPlaylist;
  final void Function(Playlist) onRenamePlaylist;
  final void Function(Playlist) onExportPlaylist;
  final void Function(String id, String name) onDeletePlaylist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? playlists
        : playlists.where((p) {
            return p.name.toLowerCase().contains(query) ||
                (p.description?.toLowerCase().contains(query) ?? false);
          }).toList();

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: PrismSectionHeader(
            title: 'Playlists',
            actionLabel: playlists.length > 1
                ? (showSearch ? 'Close' : 'Search')
                : null,
            onAction: playlists.length > 1 ? onToggleSearch : null,
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 6),
          ),
        ),
        if (showSearch && playlists.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: TextField(
                controller: searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search playlists…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHigh
                      .withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PrismRadius.lg),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: onSearchChanged,
              ),
            ),
          ),
        if (playlists.isEmpty)
          SliverToBoxAdapter(
            child: PrismEmptyState(
              icon: Icons.queue_music_rounded,
              message: 'No playlists yet',
              hint: 'Organize your favorite tracks into custom playlists.',
              actionLabel: 'Create playlist',
              onAction: onCreatePlaylist,
              compact: true,
            ),
          )
        else if (filtered.isEmpty)
          SliverToBoxAdapter(
            child: PrismEmptyState(
              icon: Icons.search_off_rounded,
              message: 'No matching playlists',
              hint: 'Try a different search term.',
              actionLabel: 'Clear filter',
              onAction: () {
                searchController.clear();
                onSearchChanged('');
              },
              compact: true,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final playlist = filtered[index];
                return LibraryPlaylistCard(
                  playlist: playlist,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlaylistDetailPage(playlist: playlist),
                    ),
                  ),
                  onPlay: () => onPlayPlaylist(playlist),
                  onRename: () => onRenamePlaylist(playlist),
                  onExport: () => onExportPlaylist(playlist),
                  onDelete: () => onDeletePlaylist(
                    playlist.id,
                    playlist.name,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
