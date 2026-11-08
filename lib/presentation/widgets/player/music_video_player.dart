import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../theme/prism_theme.dart';

/// Interactive video player widget for music video streaming.
class MusicVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final Duration initialPosition;
  final bool isPlaying;
  final VoidCallback? onTogglePlayPause;
  final VoidCallback? onExitVideo;
  final ValueChanged<Duration>? onPositionChanged;

  const MusicVideoPlayer({
    super.key,
    required this.videoUrl,
    this.initialPosition = Duration.zero,
    this.isPlaying = true,
    this.onTogglePlayPause,
    this.onExitVideo,
    this.onPositionChanged,
  });

  @override
  State<MusicVideoPlayer> createState() => _MusicVideoPlayerState();
}

class _MusicVideoPlayerState extends State<MusicVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant MusicVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _initPlayer();
    } else if (_controller != null && _isInitialized) {
      if (widget.isPlaying && !_controller!.value.isPlaying) {
        _controller!.play();
      } else if (!widget.isPlaying && _controller!.value.isPlaying) {
        _controller!.pause();
      }
    }
  }

  Future<void> _initPlayer() async {
    _disposeController();

    setState(() {
      _isInitialized = false;
      _hasError = false;
    });

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      _controller = controller;

      await controller.initialize();
      if (!mounted) return;

      if (widget.initialPosition > Duration.zero) {
        await controller.seekTo(widget.initialPosition);
      }

      if (widget.isPlaying) {
        await controller.play();
      }

      controller.addListener(_onPlayerUpdate);

      setState(() {
        _isInitialized = true;
      });

      _startControlsTimer();
    } catch (e) {
      debugPrint('MusicVideoPlayer: Initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _onPlayerUpdate() {
    if (!mounted || _controller == null) return;
    if (_controller!.value.isPlaying) {
      widget.onPositionChanged?.call(_controller!.value.position);
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startControlsTimer();
    }
  }

  void _disposeController() {
    _controller?.removeListener(_onPlayerUpdate);
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Video stream unavailable',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _initPlayer,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PrismColors.accentDark,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(PrismColors.accentDark),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio > 0
                  ? _controller!.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(_controller!),
            ),
            if (_showControls)
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: Colors.black45,
                  child: Stack(
                    children: [
                      // Exit Video Button (top right)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                          tooltip: 'Switch to Audio',
                          onPressed: widget.onExitVideo,
                        ),
                      ),
                      // Central Play/Pause button
                      Center(
                        child: IconButton(
                          iconSize: 56,
                          icon: Icon(
                            _controller!.value.isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            if (_controller!.value.isPlaying) {
                              _controller!.pause();
                            } else {
                              _controller!.play();
                            }
                            widget.onTogglePlayPause?.call();
                            setState(() {});
                            _startControlsTimer();
                          },
                        ),
                      ),
                      // Video Mode Badge (top left)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.smart_display_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'MUSIC VIDEO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
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
}
