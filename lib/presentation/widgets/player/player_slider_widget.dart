
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/player/player_bloc.dart';
import '../../blocs/player/player_event.dart';
import '../../blocs/player/player_state.dart';

/// Interactive progress scrubber with targeted BlocBuilder for isolated position updates.
class PlayerSliderWidget extends StatelessWidget {
  const PlayerSliderWidget({
    super.key,
    this.state,
  });

  final PlayerState? state;

  @override
  Widget build(BuildContext context) {
    if (state != null) {
      return _InternalSlider(state: state!);
    }

    return BlocBuilder<PlayerBloc, PlayerState>(
      buildWhen: (prev, curr) =>
          prev.position != curr.position || prev.duration != curr.duration,
      builder: (context, state) => _InternalSlider(state: state),
    );
  }
}

class _InternalSlider extends StatefulWidget {
  const _InternalSlider({required this.state});

  final PlayerState state;

  @override
  State<_InternalSlider> createState() => _InternalSliderState();
}

class _InternalSliderState extends State<_InternalSlider> {
  double? _dragValue;

  String _format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = widget.state.duration;
    final progress = duration.inMilliseconds > 0
        ? (widget.state.position.inMilliseconds / duration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    final displayProgress = _dragValue ?? progress;
    final displayPosition = _dragValue != null
        ? Duration(
            milliseconds: (_dragValue! * duration.inMilliseconds).round(),
          )
        : widget.state.position;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Semantics(
            slider: true,
            label: 'Track playback progress',
            value: '${_format(displayPosition)} of ${_format(duration)}',
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: displayProgress.clamp(0.0, 1.0),
                onChanged: (value) {
                  setState(() => _dragValue = value);
                },
                onChangeEnd: (value) {
                  final newPosition = Duration(
                    milliseconds: (value * duration.inMilliseconds).round(),
                  );
                  context.read<PlayerBloc>().add(SeekEvent(newPosition));
                  setState(() => _dragValue = null);
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _format(displayPosition),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  '-${_format(duration - displayPosition > Duration.zero ? duration - displayPosition : Duration.zero)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
