import 'package:flutter/material.dart';

import '../../blocs/library/library_state.dart';
import '../../pages/downloads_page.dart';
import '../../pages/liked_songs_page.dart';
import '../../pages/recently_played_page.dart';
import '../prism/prism_quick_tile.dart';

/// Quick access grid displaying Liked songs, Downloads, Recently played, and New playlist.
class LibraryQuickAccessGrid extends StatelessWidget {
  const LibraryQuickAccessGrid({
    super.key,
    required this.state,
    required this.onCreatePlaylist,
  });

  final LibraryState state;
  final VoidCallback onCreatePlaylist;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisExtent: 96,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildListDelegate([
          PrismQuickTile(
            icon: Icons.favorite_rounded,
            label: 'Liked songs',
            meta: '${state.likedSongs.length} songs',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const LikedSongsPage(),
              ),
            ),
          ),
          PrismQuickTile(
            icon: Icons.download_rounded,
            label: 'Downloads',
            meta: '${state.downloads.length} songs',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const DownloadsPage(),
              ),
            ),
          ),
          PrismQuickTile(
            icon: Icons.history_rounded,
            label: 'Recently played',
            meta: '${state.recentlyPlayed.length} songs',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const RecentlyPlayedPage(),
              ),
            ),
          ),
          PrismQuickTile(
            icon: Icons.playlist_add_rounded,
            label: 'New playlist',
            meta: 'Create from scratch',
            onTap: onCreatePlaylist,
          ),
        ]),
      ),
    );
  }
}
