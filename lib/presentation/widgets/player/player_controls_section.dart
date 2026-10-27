import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/player/player_bloc.dart';
import '../../blocs/player/player_event.dart';
import '../../blocs/player/player_state.dart';
import '../../theme/prism_theme.dart';

/// Primary playback transport controls with targeted BlocBuilder.
class PlayerControlsSection extends StatelessWidget {
  const PlayerControlsSection({
    super.key,
    this.state,
  });

  final PlayerState? state;

  @override
  Widget build(BuildContext context) {
    if (state != null) {
      return _InternalControls(state: state!);
    }

    return BlocBuilder<PlayerBloc, PlayerState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.canSkipNext != curr.canSkipNext ||
          prev.canSkipPrevious != curr.canSkipPrevious ||
          prev.isBuffering != curr.isBuffering,
      builder: (context, state) => _InternalControls(state: state),
    );
  }
}

class _InternalControls extends StatelessWidget {
  const _InternalControls({required this.state});

  final PlayerState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            tooltip: 'Previous Track',
            onPressed: state.canSkipPrevious
                ? () => context.read<PlayerBloc>().add(const PreviousEvent())
                : null,
            iconSize: 30,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          PlayerPlayPauseButton(state: state),
          IconButton(
            tooltip: 'Next Track',
            onPressed: state.canSkipNext
                ? () => context.read<PlayerBloc>().add(const NextEvent())
                : null,
            iconSize: 30,
            icon: const Icon(Icons.skip_next_rounded),
          ),
        ],
      ),
    );
  }
}

/// Dynamic play, pause, buffering, and retry button.
class PlayerPlayPauseButton extends StatelessWidget {
  const PlayerPlayPauseButton({
    super.key,
    required this.state,
  });

  final PlayerState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPlaying = state.isPlaying;
    final isError = state.status == PlayerStatus.error;

    return Semantics(
      button: true,
      label: isError ? 'Retry' : (isPlaying ? 'Pause' : 'Play'),
      child: GestureDetector(
        onTap: state.isBuffering
            ? null
            : () => context.read<PlayerBloc>().add(
                  isPlaying ? const PauseEvent() : const ResumeEvent(),
                ),
        child: AnimatedContainer(
          duration: PrismMotion.fast,
          curve: PrismMotion.curve,
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary,
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: .30),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: state.isBuffering
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  isError
                      ? Icons.refresh_rounded
                      : (isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                  size: 38,
                  color: scheme.onPrimary,
                ),
        ),
      ),
    );
  }
}
