import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/entities.dart';
import '../../../../domain/repositories/repositories.dart';
import '../../../blocs/library/library_bloc.dart';
import '../../../blocs/library/library_event.dart';
import '../../prism/prism_artwork.dart';
import '../../prism/prism_sheet.dart';

/// Modal bottom sheet for comparing an imported Spotify or YouTube playlist
/// with upstream changes, visualizing diffs, and applying updates atomically.
class PlaylistSyncSheet extends StatefulWidget {
  final Playlist playlist;
  final MusicRepository? musicRepository;

  const PlaylistSyncSheet({
    super.key,
    required this.playlist,
    this.musicRepository,
  });

  static Future<void> show(BuildContext context, Playlist playlist) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlaylistSyncSheet(playlist: playlist),
    );
  }

  @override
  State<PlaylistSyncSheet> createState() => _PlaylistSyncSheetState();
}

class _PlaylistSyncSheetState extends State<PlaylistSyncSheet> {
  late final MusicRepository _musicRepo;

  bool _isLoading = true;
  bool _isApplying = false;
  String? _errorMessage;

  List<Song> _upstreamSongs = [];
  List<Song> _addedSongs = [];
  List<Song> _removedSongs = [];

  int _selectedFilter = 0; // 0: All, 1: Added, 2: Removed

  @override
  void initState() {
    super.initState();
    _musicRepo = widget.musicRepository ?? getIt<MusicRepository>();
    _fetchUpstreamDiff();
  }

  Future<void> _fetchUpstreamDiff() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final p = widget.playlist;
      List<Song> upstream = [];

      if (p.spotifyPlaylistId != null) {
        final url =
            'https://open.spotify.com/playlist/${p.spotifyPlaylistId}';
        final res = await _musicRepo.importSpotifyPlaylist(url);
        res.fold(
          (failure) => _errorMessage = failure.message,
          (result) => upstream = result.matchedTracks,
        );
      } else if (p.youtubePlaylistId != null) {
        final url =
            'https://www.youtube.com/playlist?list=${p.youtubePlaylistId}';
        final res = await _musicRepo.importYouTubePlaylist(url);
        res.fold(
          (failure) => _errorMessage = failure.message,
          (result) => upstream = result.songs ?? [],
        );
      } else if (p.appleMusicPlaylistId != null) {
        final url =
            'https://music.apple.com/playlist/${p.appleMusicPlaylistId}';
        final res = await _musicRepo.importAppleMusicPlaylist(url);
        res.fold(
          (failure) => _errorMessage = failure.message,
          (result) => upstream = result.matchedTracks,
        );
      } else {
        _errorMessage = 'Playlist is not linked to Spotify, YouTube Music, or Apple Music';
      }

      if (_errorMessage != null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final localSongs = widget.playlist.songs ?? [];
      final localIds = localSongs.map((s) => s.playableId).toSet();
      final upstreamIds = upstream.map((s) => s.playableId).toSet();

      final added =
          upstream.where((s) => !localIds.contains(s.playableId)).toList();
      final removed =
          localSongs.where((s) => !upstreamIds.contains(s.playableId)).toList();

      if (mounted) {
        setState(() {
          _upstreamSongs = upstream;
          _addedSongs = added;
          _removedSongs = removed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _applySync() {
    if (_isApplying) return;
    setState(() => _isApplying = true);

    context.read<LibraryBloc>().add(
          SyncPlaylistSongsEvent(
            playlistId: widget.playlist.id,
            songs: _upstreamSongs,
            onDone: (error) {
              if (!mounted) return;
              setState(() => _isApplying = false);
              if (error != null) {
                showPrismToast(context, 'Sync failed: $error');
              } else {
                showPrismToast(
                  context,
                  'Synced "${widget.playlist.name}": +${_addedSongs.length}, -${_removedSongs.length}',
                );
                Navigator.of(context).pop();
              }
            },
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSpotify = widget.playlist.spotifyPlaylistId != null;
    final isApple = widget.playlist.appleMusicPlaylistId != null;

    final displayedSongs = _selectedFilter == 1
        ? _addedSongs
        : (_selectedFilter == 2 ? _removedSongs : _upstreamSongs);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  isSpotify
                      ? Icons.graphic_eq_rounded
                      : (isApple ? Icons.music_note_rounded : Icons.play_circle_fill),
                  color: isSpotify
                      ? const Color(0xFF1DB954)
                      : (isApple ? const Color(0xFFFC3C44) : const Color(0xFFFF0000)),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sync ${widget.playlist.name}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isSpotify
                            ? 'Spotify Playlist'
                            : (isApple ? 'Apple Music Playlist' : 'YouTube Music Playlist'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(),
          if (_isLoading) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Fetching latest playlist changes from source...'),
                ],
              ),
            ),
          ] else if (_errorMessage != null) ...[
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: colorScheme.error, size: 40),
                  const SizedBox(height: 12),
                  Text(_errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _fetchUpstreamDiff,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildStatBadge(
                    context,
                    label: '+${_addedSongs.length} New',
                    color: Colors.green,
                    isSelected: _selectedFilter == 1,
                    onTap: () => setState(() => _selectedFilter = 1),
                  ),
                  const SizedBox(width: 8),
                  _buildStatBadge(
                    context,
                    label: '-${_removedSongs.length} Removed',
                    color: Colors.orange,
                    isSelected: _selectedFilter == 2,
                    onTap: () => setState(() => _selectedFilter = 2),
                  ),
                  const SizedBox(width: 8),
                  _buildStatBadge(
                    context,
                    label: '${_upstreamSongs.length} Total',
                    color: colorScheme.primary,
                    isSelected: _selectedFilter == 0,
                    onTap: () => setState(() => _selectedFilter = 0),
                  ),
                ],
              ),
            ),
            if (_addedSongs.isEmpty && _removedSongs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                child: Text(
                  'Playlist is completely in sync with upstream. No changes detected.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: displayedSongs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final song = displayedSongs[index];
                    final isNew = _addedSongs.any((s) => s.id == song.id);
                    final isRemoved = _removedSongs.any((s) => s.id == song.id);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: PrismArtwork(
                        url: song.thumbnailUrl,
                        width: 44,
                        height: 44,
                        borderRadius: 8,
                      ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          decoration: isRemoved ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isNew)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else if (isRemoved)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'REMOVED',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            Formatters.formatDuration(song.duration),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isApplying ? null : _applySync,
                        icon: _isApplying
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.sync_rounded),
                        label: Text(_isApplying ? 'Syncing...' : 'Apply Sync'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatBadge(
    BuildContext context, {
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.2)
                : Theme.of(context).colorScheme.surfaceContainerHigh,
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? color : Theme.of(context).colorScheme.onSurface,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
