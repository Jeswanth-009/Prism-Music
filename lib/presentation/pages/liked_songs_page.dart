import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/library/library_bloc.dart';
import '../blocs/library/library_state.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../blocs/player/player_state.dart';
import '../widgets/prism/prism_song_tile.dart';
import '../widgets/prism/prism_states.dart';

class LikedSongsPage extends StatelessWidget {
  const LikedSongsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Liked Songs'),
      ),
      body: BlocBuilder<LibraryBloc, LibraryState>(
        builder: (context, state) {
          final songs = state.likedSongs;
          if (songs.isEmpty) {
            return const PrismEmptyState(
              icon: Icons.favorite_outline_rounded,
              message: 'Songs you love live here',
              hint:
                  'Tap the heart while listening and Prism will keep it in your private library.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
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
