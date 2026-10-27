import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/services/smart_playlist_service.dart';
import '../../core/utils/cancellation_token.dart';
import '../../domain/entities/entities.dart';
import '../blocs/library/library.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../theme/prism_theme.dart';
import '../widgets/common/prism_snackbar.dart';
import '../widgets/library/import/import_progress_dialog.dart';
import '../widgets/library/import/import_review_sheet.dart';
import '../widgets/library/import/import_sheet.dart';
import '../widgets/library/import/library_import_tile.dart';
import '../widgets/library/library_artists_section.dart';
import '../widgets/library/library_playlists_section.dart';
import '../widgets/library/library_quick_access_grid.dart';
import '../widgets/library/library_stats_card.dart';
import '../widgets/library/smart_playlist_card.dart';
import '../widgets/playlist/playlist_export_sheet.dart';
import '../widgets/prism/prism_section_header.dart';
import '../widgets/prism/prism_sheet.dart';
import 'settings_page.dart';
import 'stats_page.dart';

// Re-export for backward compatibility with existing tests
export '../widgets/library/import/import_progress_dialog.dart'
    show ImportProgressDialog;
export '../widgets/library/import/import_review_sheet.dart'
    show ImportReviewSheet, ImportReviewSheetState;
export '../widgets/library/import/import_sheet.dart'
    show LibraryImportSheet, PlaylistImportSource;
export '../widgets/library/import/library_import_tile.dart'
    show LibraryImportTile;
export '../widgets/library/library_artists_section.dart'
    show LibraryArtistsSection;
export '../widgets/library/library_playlist_card.dart'
    show LibraryPlaylistCard, LibraryCardMenuButton;
export '../widgets/library/library_playlists_section.dart'
    show LibraryPlaylistsSection;
export '../widgets/library/library_quick_access_grid.dart'
    show LibraryQuickAccessGrid;
export '../widgets/library/library_stats_card.dart' show LibraryStatsCard;

/// Library tab: quick-access tiles, playlists, smart lists, and listening overview.
class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab>
    with AutomaticKeepAliveClientMixin {
  ImportCancellationToken? _activeCancelToken;
  final TextEditingController _playlistSearchCtrl = TextEditingController();
  bool _showPlaylistSearch = false;
  Future<List<SmartPlaylist>>? _smartPlaylistsFuture;

  @override
  void initState() {
    super.initState();
    _refreshSmartPlaylists();
  }

  void _refreshSmartPlaylists() {
    if (getIt.isRegistered<SmartPlaylistService>()) {
      _smartPlaylistsFuture =
          getIt<SmartPlaylistService>().generateSmartPlaylists();
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _playlistSearchCtrl.dispose();
    super.dispose();
  }

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
            LibraryQuickAccessGrid(
              state: state,
              onCreatePlaylist: _createPlaylist,
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
                      showPrismToast(
                          context, 'Importing playlist in background…');
                    }
                  },
                  child: LibraryImportTile(
                    onTap: _importPlaylist,
                    isImporting: state.status == LibraryStatus.importing,
                    importProgress: state.importProgress,
                    currentTrack: state.importCurrentTrack,
                    totalTracks: state.importTotalTracks,
                    onCancel: () {
                      _activeCancelToken?.cancel();
                      context
                          .read<LibraryBloc>()
                          .add(const CancelImportEvent());
                    },
                  ),
                ),
              ),
            ),
            LibraryArtistsSection(artists: state.favoriteArtists),
            const SliverToBoxAdapter(
              child: PrismSectionHeader(
                title: 'Smart Playlists',
                padding: EdgeInsets.fromLTRB(20, 24, 20, 10),
              ),
            ),
            SliverToBoxAdapter(
              child: FutureBuilder<List<SmartPlaylist>>(
                future: _smartPlaylistsFuture,
                builder: (context, snapshot) {
                  final smartLists = snapshot.data ?? const [];
                  if (smartLists.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return SizedBox(
                    height: 124,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: smartLists.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) =>
                          SmartPlaylistCard(smartPlaylist: smartLists[index]),
                    ),
                  );
                },
              ),
            ),
            LibraryPlaylistsSection(
              playlists: state.playlists,
              showSearch: _showPlaylistSearch,
              searchController: _playlistSearchCtrl,
              onToggleSearch: () {
                setState(() {
                  _showPlaylistSearch = !_showPlaylistSearch;
                  if (!_showPlaylistSearch) {
                    _playlistSearchCtrl.clear();
                  }
                });
              },
              onSearchChanged: (_) => setState(() {}),
              onCreatePlaylist: _createPlaylist,
              onPlayPlaylist: _playPlaylist,
              onRenamePlaylist: _renamePlaylist,
              onExportPlaylist: _exportPlaylist,
              onDeletePlaylist: _deletePlaylist,
            ),
            const SliverToBoxAdapter(
              child: PrismSectionHeader(
                title: 'Listening overview',
                padding: EdgeInsets.fromLTRB(20, 28, 20, 6),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    LibraryStatsCard(
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

  /// Spotify / YouTube playlist import flow.
  Future<void> _importPlaylist() async {
    final params =
        await showPrismSheet<({PlaylistImportSource source, String url})>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => const LibraryImportSheet(),
    );
    if (params == null || params.url.isEmpty || !mounted) return;

    final bloc = context.read<LibraryBloc>();
    final done = Completer<String?>();
    final cancelToken = ImportCancellationToken();
    _activeCancelToken = cancelToken;

    bloc.add(
      params.source == PlaylistImportSource.spotify
          ? ImportSpotifyPlaylistEvent(
              params.url,
              cancelToken: cancelToken,
              onDone: (error) {
                if (!done.isCompleted) done.complete(error);
              },
              onResult: (result) {
                if (mounted) {
                  _showImportSummarySheet(result);
                }
              },
            )
          : ImportYouTubePlaylistEvent(
              params.url,
              onDone: (error) {
                if (!done.isCompleted) done.complete(error);
              },
              onResult: (result) {
                if (mounted) {
                  _showImportSummarySheet(result);
                }
              },
            ),
    );

    var dialogClosed = false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => BlocProvider.value(
        value: bloc,
        child: ImportProgressDialog(
          cancelToken: cancelToken,
          onDismiss: () => dialogClosed = true,
        ),
      ),
    );

    try {
      final error = await done.future.timeout(const Duration(minutes: 5));
      if (!dialogClosed && mounted) {
        dialogClosed = true;
        Navigator.of(context, rootNavigator: true).maybePop();
      }
      if (!mounted) return;
      if (error != null) {
        showPrismErrorSnackBar(context, error: error);
      }
    } on TimeoutException {
      if (!dialogClosed && mounted) {
        dialogClosed = true;
        Navigator.of(context, rootNavigator: true).maybePop();
      }
      if (!mounted) return;
      showPrismErrorSnackBar(
        context,
        error: 'Import timed out. Please check your internet connection.',
        onRetry: _importPlaylist,
      );
    }
  }

  Future<void> _showImportSummarySheet(ImportPlaylistResult result) async {
    if (!mounted) return;
    final hasUncertain = result.effectivePreviewItems.any(
      (item) => item.confidenceLevel == ImportConfidenceLevel.uncertain,
    );
    if (result.isFullyMatched && !hasUncertain) {
      showPrismToast(
        context,
        'All ${result.totalSourceTracks} tracks matched and imported!',
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => ImportReviewSheet(result: result),
    );
  }

  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    final String? name;
    try {
      name = await showPrismSheet<String>(
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
    } finally {
      controller.dispose();
    }

    if (name == null || name.isEmpty || !mounted) return;
    context.read<LibraryBloc>().add(CreatePlaylistEvent(name: name));
    if (mounted) showPrismToast(context, 'Playlist "$name" created');
  }

  Future<void> _deletePlaylist(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete playlist?'),
        content:
            Text('"$name" will be removed. Songs are kept in your library.'),
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

  Future<void> _renamePlaylist(Playlist playlist) async {
    final nameController = TextEditingController(text: playlist.name);
    final descController =
        TextEditingController(text: playlist.description ?? '');
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Edit Playlist Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Playlist name',
                  hintText: 'e.g. Chill Beats',
                  filled: true,
                  fillColor:
                      Theme.of(dialogCtx).colorScheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PrismRadius.lg),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Add an optional description',
                  filled: true,
                  fillColor:
                      Theme.of(dialogCtx).colorScheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PrismRadius.lg),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (saved == true && mounted) {
        final newName = nameController.text.trim();
        final newDesc = descController.text.trim();
        if (newName.isNotEmpty) {
          context.read<LibraryBloc>().add(
                RenamePlaylistEvent(
                  playlistId: playlist.id,
                  name: newName,
                  description: newDesc.isEmpty ? null : newDesc,
                ),
              );
          showPrismToast(context, 'Playlist updated');
        }
      }
    } finally {
      nameController.dispose();
      descController.dispose();
    }
  }

  void _exportPlaylist(Playlist playlist) {
    PlaylistExportSheet.show(context, playlist);
  }

  void _playPlaylist(Playlist playlist) {
    final songs = playlist.songs ?? const [];
    if (songs.isEmpty) {
      showPrismToast(context, 'This playlist has no songs yet');
      return;
    }
    context.read<PlayerBloc>().add(
          PlaySongEvent(
            song: songs.first,
            queue: songs,
            queueIndex: 0,
          ),
        );
  }
}
