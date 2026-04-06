import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/player/player.dart';
import '../../pages/player_page.dart';

/// Modern glassmorphism mini player widget
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _openFullPlayer(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const PlayerPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          final fadeTween = Tween<double>(begin: 0.0, end: 1.0);
          return SlideTransition(
            position: animation.drive(tween),
            child: FadeTransition(
              opacity: animation.drive(fadeTween),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocBuilder<PlayerBloc, PlayerState>(
      builder: (context, state) {
        final song = state.currentSong;
        if (song == null) {
          return const SizedBox.shrink();
        }

        final progress = state.duration.inMilliseconds > 0
            ? state.position.inMilliseconds / state.duration.inMilliseconds
            : 0.0;

        // Extract dominant color from album art for accent
        final accentColor = theme.colorScheme.primary;

        return AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity! < -300) {
                _openFullPlayer(context);
              }
            },
            onTapDown: (_) {
              setState(() => _isPressed = true);
              _animController.forward();
            },
            onTapUp: (_) {
              setState(() => _isPressed = false);
              _animController.reverse();
              _openFullPlayer(context);
            },
            onTapCancel: () {
              setState(() => _isPressed = false);
              _animController.reverse();
            },
            child: Container(
              height: 76,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                Colors.white.withOpacity(0.12),
                                Colors.white.withOpacity(0.05),
                              ]
                            : [
                                Colors.white.withOpacity(0.85),
                                Colors.white.withOpacity(0.65),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.15)
                            : Colors.white.withOpacity(0.5),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: -2,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Accent glow behind album art
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.4),
                                  blurRadius: 16,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Main content
                        Column(
                          children: [
                            // Progress bar at top
                            Container(
                              height: 3,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: Stack(
                                  children: [
                                    // Background track
                                    Container(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.1)
                                          : Colors.black.withOpacity(0.08),
                                    ),
                                    // Progress
                                    FractionallySizedBox(
                                      widthFactor: progress.clamp(0.0, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              accentColor,
                                              accentColor.withOpacity(0.7),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  accentColor.withOpacity(0.5),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Content
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                                child: Row(
                                  children: [
                                    // Album art with animation
                                    Hero(
                                      tag: 'album_art_${song.id}',
                                      child: _AlbumArtWidget(
                                        thumbnailUrl: song.thumbnailUrl,
                                        isPlaying: state.isPlaying,
                                        accentColor: accentColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Song info
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            song.title,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: -0.3,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            song.artist,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: isDark
                                                  ? Colors.white60
                                                  : Colors.black54,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Controls
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Play / Pause button
                                        _PlayPauseButton(
                                          isPlaying: state.isPlaying,
                                          isBuffering: state.isBuffering,
                                          accentColor: accentColor,
                                          isDark: isDark,
                                          onPressed: () {
                                            if (state.isPlaying) {
                                              context
                                                  .read<PlayerBloc>()
                                                  .add(const PauseEvent());
                                            } else {
                                              context
                                                  .read<PlayerBloc>()
                                                  .add(const ResumeEvent());
                                            }
                                          },
                                        ),
                                        const SizedBox(width: 2),

                                        // Next button
                                        _ControlButton(
                                          icon: LucideIcons.skipForward,
                                          enabled: state.hasNext,
                                          isDark: isDark,
                                          onPressed: state.hasNext
                                              ? () => context
                                                  .read<PlayerBloc>()
                                                  .add(const NextEvent())
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Animated album art widget with subtle rotation when playing
class _AlbumArtWidget extends StatefulWidget {
  final String thumbnailUrl;
  final bool isPlaying;
  final Color accentColor;

  const _AlbumArtWidget({
    required this.thumbnailUrl,
    required this.isPlaying,
    required this.accentColor,
  });

  @override
  State<_AlbumArtWidget> createState() => _AlbumArtWidgetState();
}

class _AlbumArtWidgetState extends State<_AlbumArtWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    if (widget.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(_AlbumArtWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!widget.isPlaying && _rotationController.isAnimating) {
      _rotationController.stop();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: widget.thumbnailUrl.isNotEmpty
            ? Image.network(
                widget.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _placeholder();
                },
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: widget.accentColor.withOpacity(0.2),
      child: Icon(
        LucideIcons.music,
        color: widget.accentColor,
        size: 28,
      ),
    );
  }
}

/// Animated play/pause button with scale effect
class _PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final bool isBuffering;
  final Color accentColor;
  final bool isDark;
  final VoidCallback onPressed;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.isBuffering,
    required this.accentColor,
    required this.isDark,
    required this.onPressed,
  });

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.accentColor,
                widget.accentColor.withOpacity(0.8),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: widget.isBuffering
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(
                  widget.isPlaying ? LucideIcons.pause : LucideIcons.play,
                  color: Colors.white,
                  size: 22,
                ),
        ),
      ),
    );
  }
}

/// Simple control button (skip, etc)
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final bool isDark;
  final VoidCallback? onPressed;

  const _ControlButton({
    required this.icon,
    required this.enabled,
    required this.isDark,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 22,
            color: enabled
                ? (isDark ? Colors.white70 : Colors.black54)
                : (isDark ? Colors.white24 : Colors.black26),
          ),
        ),
      ),
    );
  }
}
