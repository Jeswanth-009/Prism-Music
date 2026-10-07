import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/utils/link_validation.dart';
import '../../domain/entities/entities.dart';
import '../blocs/library/library.dart';
import '../theme/prism_theme.dart';
import '../widgets/prism/prism_artwork.dart';
import '../widgets/prism/prism_quick_tile.dart';
import '../widgets/prism/prism_section_header.dart';
import '../widgets/prism/prism_sheet.dart';
import '../widgets/prism/prism_states.dart';
import 'downloads_page.dart';
import 'liked_songs_page.dart';
import 'playlist_detail_page.dart';
import 'recently_played_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';

/// Playlist import sources.
enum _ImportSource { spotify, youtube }

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
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: BlocListener<LibraryBloc, LibraryState>(
                  listenWhen: (prev, next) =>
                      prev.status != next.status &&
                      (next.status == LibraryStatus.importing ||
                          prev.status == LibraryStatus.importing),
                  listener: (context, importState) {
                    if (importState.status == LibraryStatus.importing) {
                      showPrismToast(context, 'Importing playlist…');
                    }
                  },
                  child: _ImportTile(onTap: _importPlaylist),
                ),
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
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                sliver: SliverGrid.builder(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: state.playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = state.playlists[index];
                    return _PlaylistCard(
                      playlist: playlist,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PlaylistDetailPage(playlist: playlist),
                        ),
                      ),
                      onDelete: () => _deletePlaylist(
                        playlist.id,
                        playlist.name,
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
                child: Column(
                  children: [
                    _StatsCard(
                      totalPlays: state.stats?.totalPlays ?? 0,
                      uniqueSongs: state.stats?.uniqueSongs ?? 0,
                      topArtist: state.stats?.topArtist,
                      mostPlayed: state.stats?.mostPlayedSong?.title,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StatsPage(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StatsPage(),
                        ),
                      ),
                      icon: const Icon(Icons.bar_chart_rounded, size: 18),
                      label: const Text('Full listening stats'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Spotify / YouTube playlist import. Dispatches the import event and
  /// reports the outcome through the event's onDone callback (the state
  /// stream can't be used for this — its current state replays on listen).
  Future<void> _importPlaylist() async {
    final params = await showPrismSheet<({_ImportSource source, String url})>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => const _ImportSheet(),
    );
    if (params == null || params.url.isEmpty || !mounted) return;

    final bloc = context.read<LibraryBloc>();
    final done = Completer<String?>();
    bloc.add(
      params.source == _ImportSource.spotify
          ? ImportSpotifyPlaylistEvent(
              params.url,
              onDone: (error) {
                if (!done.isCompleted) done.complete(error);
              },
            )
          : ImportYouTubePlaylistEvent(
              params.url,
              onDone: (error) {
                if (!done.isCompleted) done.complete(error);
              },
            ),
    );

    try {
      final error = await done.future.timeout(const Duration(minutes: 5));
      if (!mounted) return;
      showPrismToast(context, error ?? 'Playlist imported');
    } on TimeoutException {
      if (!mounted) return;
      showPrismToast(context, 'Import is taking too long.');
    }
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
    this.onTap,
  });

  final int totalPlays;
  final int uniqueSongs;
  final String? topArtist;
  final String? mostPlayed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = Container(
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

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        child: card,
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

/// Cover-art grid card for a library playlist.
class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.playlist,
    required this.onTap,
    required this.onDelete,
  });

  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = context.prismSpec;
    return Material(
      color: theme.colorScheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        side: BorderSide(color: spec.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Falls back to a quiet placeholder when the playlist has
                  // no cover of its own (user-created playlists).
                  PrismArtwork(
                    url: playlist.thumbnailUrl ?? '',
                    fit: BoxFit.cover,
                  ),
                  if (_sourceLabel != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: _badge(
                        context,
                        icon: _sourceLabel!.$2,
                        label: _sourceLabel!.$1,
                      ),
                    ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _CardDeleteButton(onDelete: onDelete),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${playlist.trackCount} songs',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// (label, icon) for imported playlists, null for user-created ones.
  (String, IconData)? get _sourceLabel {
    if (playlist.spotifyPlaylistId != null) {
      return ('Spotify', Icons.graphic_eq_rounded);
    }
    if (playlist.youtubePlaylistId != null) {
      return ('YouTube', Icons.play_circle_outline_rounded);
    }
    return null;
  }

  Widget _badge(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardDeleteButton extends StatelessWidget {
  const _CardDeleteButton({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: onDelete,
      tooltip: 'Delete playlist',
      icon: const Icon(Icons.close_rounded, size: 15),
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.surface.withValues(alpha: .88),
        foregroundColor: theme.colorScheme.onSurface,
        minimumSize: const Size(28, 28),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// Full-width entry pointing at the Spotify/YouTube import flow.
class _ImportTile extends StatelessWidget {
  const _ImportTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        side: BorderSide(color: context.prismSpec.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.download_for_offline_outlined,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import playlist',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Bring a Spotify or YouTube playlist into Prism',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Source picker + URL entry for playlist import. Pops with the chosen
/// source and url, or null when cancelled.
class _ImportSheet extends StatefulWidget {
  const _ImportSheet();

  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
  _ImportSource _source = _ImportSource.spotify;
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  String get _hint => _source == _ImportSource.spotify
      ? 'https://open.spotify.com/playlist/…'
      : 'https://music.youtube.com/playlist?list=… or playlist ID (also mixes)';

  bool get _isValidUrl {
    final text = _urlController.text.trim();
    if (text.length < 10) return false;
    final uri = Uri.tryParse(text);
    if (uri == null) return false;

    return switch (_source) {
      _ImportSource.spotify => uri.scheme == 'spotify' ||
          (uri.isScheme('https') &&
              (isSpotifyPlaylistHost(uri.host) ||
                  isSpotifyShortLinkHost(uri.host))),
      _ImportSource.youtube =>
        uri.isScheme('https') && isYouTubePlaylistHost(uri.host),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import playlist',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<_ImportSource>(
              segments: const [
                ButtonSegment(
                  value: _ImportSource.spotify,
                  icon: Icon(Icons.graphic_eq_rounded),
                  label: Text('Spotify'),
                ),
                ButtonSegment(
                  value: _ImportSource.youtube,
                  icon: Icon(Icons.play_circle_outline_rounded),
                  label: Text('YouTube'),
                ),
              ],
              selected: {_source},
              onSelectionChanged: (selection) =>
                  setState(() => _source = selection.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              autofocus: true,
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
              onSubmitted: (value) {
                if (_isValidUrl) {
                  Navigator.of(context)
                      .pop((source: _source, url: value.trim()));
                }
              },
              decoration: InputDecoration(
                hintText: _hint,
                border: const OutlineInputBorder(),
                errorText:
                    _urlController.text.isNotEmpty && !_isValidUrl
                        ? 'That does not look like a $_source playlist link'
                        : null,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isValidUrl
                      ? () => Navigator.of(context)
                          .pop((source: _source, url: _urlController.text.trim()))
                      : null,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Import'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
