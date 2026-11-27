import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/playlist.dart';
import '../../blocs/library/library_bloc.dart';
import '../../blocs/library/library_state.dart';
import '../../blocs/player/player_bloc.dart';
import '../../blocs/player/player_event.dart';
import '../../pages/playlist_detail_page.dart';
import '../../theme/prism_theme.dart';
import '../prism/prism_artwork.dart';
import '../prism/prism_section_header.dart';

/// Horizontal rail for user-pinned playlists on the Home feed.
/// Features 1-tap playback and navigates directly to playlist details.
class HomePinnedPlaylistsRail extends StatelessWidget {
  const HomePinnedPlaylistsRail({
    super.key,
    required this.pinnedIds,
  });

  final List<String> pinnedIds;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBloc, LibraryState>(
      builder: (context, libraryState) {
        final pinned = libraryState.playlists.where((p) {
          return pinnedIds.contains(p.id);
        }).toList();

        if (pinned.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const PrismSectionHeader(
              title: 'Pinned playlists',
              padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
            ),
            SizedBox(
              height: 196,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: pinned.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final playlist = pinned[index];
                  return _PinnedCard(playlist: playlist);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PinnedCard extends StatelessWidget {
  const _PinnedCard({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = playlist.songs?.length ?? playlist.trackCount;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlaylistDetailPage(playlist: playlist),
        ),
      ),
      borderRadius: BorderRadius.circular(PrismRadius.lg),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(PrismRadius.lg),
                      child: PrismArtwork(
                        url: playlist.thumbnailUrl ?? '',
                        borderRadius: PrismRadius.lg,
                        type: ArtworkType.album,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: PrismColors.scrim.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.push_pin_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (playlist.songs != null && playlist.songs!.isNotEmpty)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Material(
                        color: theme.colorScheme.primary,
                        shape: const CircleBorder(),
                        elevation: 4,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            final songs = playlist.songs!;
                            context.read<PlayerBloc>().add(
                                  PlaySongEvent(
                                    song: songs.first,
                                    queue: songs,
                                    queueIndex: 0,
                                  ),
                                );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$count tracks',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
