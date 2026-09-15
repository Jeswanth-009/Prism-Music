import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/library/library.dart';
import '../blocs/player/player.dart';
import '../widgets/prism/prism_song_tile.dart';
import '../widgets/prism/prism_states.dart';

/// Full, scrollable view of the listening history. Tapping a song plays it.
class RecentlyPlayedPage extends StatelessWidget {
  const RecentlyPlayedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recently played'),
      ),
      body: BlocBuilder<LibraryBloc, LibraryState>(
        builder: (context, state) {
          final songs = state.recentlyPlayed;

          if (songs.isEmpty) {
            return const PrismEmptyState(
              icon: Icons.history_rounded,
              message: 'No recently played songs yet',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return BlocBuilder<PlayerBloc, PlayerState>(
                builder: (context, playerState) => PrismSongTile(
                  song: song,
                  isPlaying: playerState.currentSong?.id == song.id,
                  isPlayingPaused: !playerState.isPlaying,
                  onTap: () => context.read<PlayerBloc>().add(
                    PlaySongEvent(
                      song: song,
                      queue: songs,
                      queueIndex: index,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
