import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/services/download_service.dart';
import '../../blocs/library/library_bloc.dart';
import '../../blocs/library/library_state.dart';
import '../../blocs/player/player_bloc.dart';
import '../../blocs/player/player_event.dart';
import '../prism/prism_media_card.dart';
import '../prism/prism_section_header.dart';

/// Rule-based smart rail: Liked this month (past 30 days).
class HomeLikedThisMonthRail extends StatelessWidget {
  const HomeLikedThisMonthRail({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBloc, LibraryState>(
      builder: (context, libraryState) {
        final liked = libraryState.likedSongs;
        if (liked.isEmpty) return const SizedBox.shrink();

        // Take up to 10 most recent liked songs
        final recentLikes = liked.take(10).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const PrismSectionHeader(
              title: 'Liked this month',
              padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
            ),
            SizedBox(
              height: 194,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: recentLikes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final song = recentLikes[index];
                  return PrismMediaCard(
                    url: song.thumbnailUrl,
                    title: song.title,
                    subtitle: song.artist,
                    onTap: () {
                      context.read<PlayerBloc>().add(
                            PlaySongEvent(
                              song: song,
                              queue: recentLikes,
                              queueIndex: index,
                            ),
                          );
                    },
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

/// Rule-based smart rail: Unplayed downloads on device.
class HomeUnplayedDownloadsRail extends StatelessWidget {
  const HomeUnplayedDownloadsRail({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBloc, LibraryState>(
      builder: (context, libraryState) {
        if (!getIt.isRegistered<DownloadService>()) return const SizedBox.shrink();

        final downloads = getIt<DownloadService>().getDownloadedSongsList();
        if (downloads.isEmpty) return const SizedBox.shrink();

        final playedIds = libraryState.recentlyPlayed.map((s) => s.id).toSet();
        final unplayed = downloads.where((s) => !playedIds.contains(s.id)).take(10).toList();

        if (unplayed.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const PrismSectionHeader(
              title: 'Unplayed downloads',
              padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
            ),
            SizedBox(
              height: 194,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: unplayed.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final song = unplayed[index];
                  return PrismMediaCard(
                    url: song.thumbnailUrl,
                    title: song.title,
                    subtitle: song.artist,
                    onTap: () {
                      context.read<PlayerBloc>().add(
                            PlaySongEvent(
                              song: song,
                              queue: unplayed,
                              queueIndex: index,
                            ),
                          );
                    },
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
