import 'package:flutter/material.dart';

import '../../../domain/entities/artist.dart';
import '../../pages/artist_page.dart';
import '../prism/prism_artwork.dart';
import '../prism/prism_section_header.dart';

/// Horizontal scrolling list of favorite artists in the library.
class LibraryArtistsSection extends StatelessWidget {
  const LibraryArtistsSection({
    super.key,
    required this.artists,
  });

  final List<Artist> artists;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final theme = Theme.of(context);

    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(
          child: PrismSectionHeader(
            title: 'Favorite Artists',
            padding: EdgeInsets.fromLTRB(20, 24, 20, 10),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 104,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: artists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final artist = artists[index];
                return InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ArtistPage(
                        artistName: artist.name,
                        artistId: artist.id,
                        thumbnailUrl: artist.thumbnailUrl,
                      ),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PrismArtwork(
                        url: artist.thumbnailUrl ?? '',
                        width: 64,
                        height: 64,
                        isCircular: true,
                        type: ArtworkType.artist,
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 72,
                        child: Text(
                          artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
