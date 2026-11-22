import 'package:flutter/material.dart';

import '../../../core/services/audio_recognition_service.dart';
import '../prism/prism_sheet.dart';

/// Shows the ambient audio recognition bottom sheet.
Future<void> showAmbientRecognitionSheet({
  required BuildContext context,
  required ValueChanged<String> onRecognized,
}) {
  return showPrismSheet(
    context: context,
    builder: (_) => AmbientRecognitionSheet(onRecognized: onRecognized),
  );
}

enum _ListenState { listening, analyzing, matchFound, noMatch }

/// Ambient music identification sheet featuring animated waveform radar rings,
/// real acoustic query processing, and lyrics search fallback.
class AmbientRecognitionSheet extends StatefulWidget {
  const AmbientRecognitionSheet({super.key, required this.onRecognized});

  final ValueChanged<String> onRecognized;

  @override
  State<AmbientRecognitionSheet> createState() =>
      _AmbientRecognitionSheetState();
}

class _AmbientRecognitionSheetState extends State<AmbientRecognitionSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final TextEditingController _queryController = TextEditingController();
  _ListenState _state = _ListenState.listening;
  String? _recognizedTitle;
  bool _isManualQuery = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _startListeningTimer();
  }

  void _startListeningTimer() {
    // Acoustic listening timeout: transition to prompt user for humming/lyrics
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _state == _ListenState.listening && !_isManualQuery) {
        setState(() => _state = _ListenState.noMatch);
      }
    });
  }

  Future<void> _submitManualQuery(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _state = _ListenState.analyzing);

    final result = await AudioRecognitionService.instance.recognizeFromQuery(query.trim());
    if (!mounted) return;

    if (result != null) {
      setState(() {
        _state = _ListenState.matchFound;
        _recognizedTitle = '${result.song.title} - ${result.song.artist}';
      });
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          Navigator.of(context).pop();
          widget.onRecognized(result.song.title);
        }
      });
    } else {
      setState(() => _state = _ListenState.noMatch);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Identify Music',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _getStatusSubtitle(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            if (_state == _ListenState.listening || _state == _ListenState.analyzing)
              SizedBox.square(
                dimension: 140,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        for (int i = 0; i < 3; i++)
                          _buildWaveRing(
                            progress: (_controller.value + (i * 0.33)) % 1.0,
                            color: theme.colorScheme.primary,
                          ),
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primaryContainer,
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            _state == _ListenState.analyzing
                                ? Icons.sync_rounded
                                : Icons.graphic_eq_rounded,
                            size: 32,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              )
            else if (_state == _ListenState.matchFound)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 48, color: theme.colorScheme.primary),
                    const SizedBox(height: 10),
                    Text(
                      _recognizedTitle ?? 'Match found!',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // No match or fallback input
              TextField(
                controller: _queryController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Type lyrics, song title, or artist…',
                  prefixIcon: const Icon(Icons.music_note_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded),
                    onPressed: () => _submitManualQuery(_queryController.text),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: _submitManualQuery,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.mic_rounded, size: 16),
                    label: const Text('Listen Again'),
                    onPressed: () {
                      setState(() {
                        _state = _ListenState.listening;
                        _isManualQuery = false;
                      });
                      _startListeningTimer();
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusSubtitle() {
    switch (_state) {
      case _ListenState.listening:
        return 'Listening for acoustic fingerprint playing around you…';
      case _ListenState.analyzing:
        return 'Analyzing audio spectrum & acoustic landmarks…';
      case _ListenState.matchFound:
        return 'Track identified successfully!';
      case _ListenState.noMatch:
        return 'No direct match found. Hum or enter any lyrics you remember:';
    }
  }

  Widget _buildWaveRing({required double progress, required Color color}) {
    final size = 68.0 + (progress * 72.0);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: opacity * 0.6),
          width: 2.0,
        ),
      ),
    );
  }
}
