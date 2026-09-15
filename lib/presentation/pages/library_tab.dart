import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/library/library.dart';
import '../theme/prism_theme.dart';
import '../widgets/prism/prism_quick_tile.dart';
import '../widgets/prism/prism_section_header.dart';
import '../widgets/prism/prism_sheet.dart';
import '../widgets/prism/prism_states.dart';
import 'downloads_page.dart';
import 'liked_songs_page.dart';
import 'playlist_detail_page.dart';
import 'recently_played_page.dart';
import 'settings_page.dart';

/// Library: quick-access tiles, playlists, listening overview.
class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: BlocBuilder<LibraryBloc, LibraryState>(
        builder: (context, state) => CustomScrollView(
          key: const PageStorageKey('prism_library'),
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Library',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.9,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Your music, all in one place.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsPage(),
                        ),
                      ),
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: 'Settings',
                    ),
                  ],
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(top: 20)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                childAspectRatio: 1.45,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
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
                    onTap: _createPlaylist,
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(
              child: PrismSectionHeader(
                title: 'Playlists',
                padding: EdgeInsets.fromLTRB(20, 28, 20, 6),
              ),
            ),
            if (state.playlists.isEmpty)
              const SliverToBoxAdapter(
                child: PrismEmptyState(
                  icon: Icons.queue_music_rounded,
                  message: 'No playlists yet',
                  hint: 'Create one from the tile above.',
                  compact: true,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverList.separated(
                  itemCount: state.playlists.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final playlist = state.playlists[index];
                    return ListTile(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PlaylistDetailPage(playlist: playlist),
                        ),
                      ),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: context.prismSpec.accentSoft,
                          borderRadius: BorderRadius.circular(PrismRadius.sm),
                        ),
                        child: Icon(
                          Icons.queue_music_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${playlist.trackCount} songs',
                        maxLines: 1,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 20),
                        tooltip: 'Delete playlist',
                        onPressed: () => _deletePlaylist(playlist.id,
                            playlist.name),
                      ),
                    );
                  },
                ),
              ),
            const SliverToBoxAdapter(
              child: PrismSectionHeader(
                title: 'Listening overview',
                padding: EdgeInsets.fromLTRB(20, 28, 20, 6),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 150),
              sliver: SliverToBoxAdapter(
                child: _StatsCard(
                  totalPlays: state.stats?.totalPlays ?? 0,
                  uniqueSongs: state.stats?.uniqueSongs ?? 0,
                  topArtist: state.stats?.topArtist,
                  mostPlayed: state.stats?.mostPlayedSong?.title,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    final name = await showPrismSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New playlist',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Playlist name',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) =>
                    Navigator.of(sheetContext).pop(value.trim()),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(sheetContext).pop(controller.text.trim()),
                    child: const Text('Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (name == null || name.isEmpty || !mounted) return;
    context.read<LibraryBloc>().add(CreatePlaylistEvent(name: name));
    if (mounted) showPrismToast(context, 'Playlist "$name" created');
  }

  Future<void> _deletePlaylist(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: Text('"$name" will be removed. Songs are kept in your library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    context.read<LibraryBloc>().add(DeletePlaylistEvent(id));
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.totalPlays,
    required this.uniqueSongs,
    this.topArtist,
    this.mostPlayed,
  });

  final int totalPlays;
  final int uniqueSongs;
  final String? topArtist;
  final String? mostPlayed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        border: Border.all(color: context.prismSpec.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _stat(theme, 'Plays', '$totalPlays'),
              const SizedBox(width: 12),
              _stat(theme, 'Songs', '$uniqueSongs'),
            ],
          ),
          if (topArtist != null || mostPlayed != null) ...[
            const SizedBox(height: 14),
            Divider(color: context.prismSpec.hairline),
            const SizedBox(height: 10),
            if (mostPlayed != null)
              _row(
                theme,
                Icons.play_circle_outline_rounded,
                'Most played',
                mostPlayed!,
              ),
            if (topArtist != null) ...[
              const SizedBox(height: 8),
              _row(theme, Icons.person_outline_rounded, 'Top artist', topArtist!),
            ],
          ],
        ],
      ),
    );
  }

  Widget _stat(ThemeData theme, String label, String value) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(PrismRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _row(ThemeData theme, IconData icon, String label, String value) =>
      Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
}
