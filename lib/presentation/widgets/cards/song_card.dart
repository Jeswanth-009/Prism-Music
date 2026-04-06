import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../domain/entities/song.dart';
import '../../blocs/player/player_bloc.dart';
import '../../blocs/player/player_state.dart';

/// A modern, reusable song card widget with animations and glassmorphism effects
class SongCard extends StatefulWidget {
  final Song song;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showDuration;
  final bool showPlayIndicator;
  final bool compact;

  const SongCard({
    super.key,
    required this.song,
    this.onTap,
    this.onLongPress,
    this.showDuration = true,
    this.showPlayIndicator = true,
    this.compact = false,
  });

  @override
  State<SongCard> createState() => _SongCardState();
}

class _SongCardState extends State<SongCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return BlocBuilder<PlayerBloc, PlayerState>(
      builder: (context, playerState) {
        final isCurrentlyPlaying = playerState.currentSong?.id == widget.song.id;
        final accentColor = theme.colorScheme.primary;
        
        return GestureDetector(
          onTapDown: (_) {
            setState(() => _isPressed = true);
            _controller.forward();
          },
          onTapUp: (_) {
            setState(() => _isPressed = false);
            _controller.reverse();
            widget.onTap?.call();
          },
          onTapCancel: () {
            setState(() => _isPressed = false);
            _controller.reverse();
          },
          onLongPress: widget.onLongPress,
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(widget.compact ? 8 : 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.compact ? 12 : 16),
                color: isCurrentlyPlaying
                    ? accentColor.withOpacity(isDark ? 0.15 : 0.1)
                    : (isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.white.withOpacity(0.8)),
                border: Border.all(
                  color: isCurrentlyPlaying
                      ? accentColor.withOpacity(0.3)
                      : (isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.05)),
                  width: isCurrentlyPlaying ? 1.5 : 1,
                ),
                boxShadow: [
                  if (isCurrentlyPlaying)
                    BoxShadow(
                      color: accentColor.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Album art with glow
                  _AlbumArtThumbnail(
                    thumbnailUrl: widget.song.thumbnailUrl,
                    isPlaying: isCurrentlyPlaying && playerState.isPlaying,
                    accentColor: accentColor,
                    size: widget.compact ? 48.0 : 56.0,
                  ),
                  SizedBox(width: widget.compact ? 10 : 14),
                  
                  // Song info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: isCurrentlyPlaying
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isCurrentlyPlaying
                                ? accentColor
                                : theme.colorScheme.onSurface,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isCurrentlyPlaying
                                ? accentColor.withOpacity(0.8)
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Right side: duration and play indicator
                  if (widget.showDuration || widget.showPlayIndicator)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (widget.showDuration)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.05),
                            ),
                            child: Text(
                              widget.song.durationFormatted,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (widget.showPlayIndicator) ...[
                          const SizedBox(height: 6),
                          if (isCurrentlyPlaying && playerState.isPlaying)
                            _PlayingIndicator(color: accentColor)
                          else
                            Icon(
                              LucideIcons.play,
                              size: 18,
                              color: isCurrentlyPlaying
                                  ? accentColor
                                  : theme.colorScheme.primary.withOpacity(0.7),
                            ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Album art thumbnail with glow effect and playing indicator
class _AlbumArtThumbnail extends StatelessWidget {
  final String thumbnailUrl;
  final bool isPlaying;
  final Color accentColor;
  final double size;

  const _AlbumArtThumbnail({
    required this.thumbnailUrl,
    required this.isPlaying,
    required this.accentColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Stack(
      children: [
        // Glow effect
        if (isPlaying)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          ),
        // Thumbnail
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPlaying
                  ? accentColor.withOpacity(0.3)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: thumbnailUrl.isNotEmpty
                ? Image.network(
                    thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(theme),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _placeholder(theme);
                    },
                  )
                : _placeholder(theme),
          ),
        ),
      ],
    );
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        LucideIcons.music,
        size: size * 0.4,
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
      ),
    );
  }
}

/// Animated playing indicator bars
class _PlayingIndicator extends StatefulWidget {
  final Color color;

  const _PlayingIndicator({required this.color});

  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        duration: Duration(milliseconds: 400 + (i * 100)),
        vsync: this,
      )..repeat(reverse: true),
    );
    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (context, child) {
            return Container(
              width: 3,
              height: 12 * _animations[i].value,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: widget.color,
              ),
            );
          },
        );
      }),
    );
  }
}

/// Horizontal scrolling song card for featured/recent sections
class SongCardHorizontal extends StatefulWidget {
  final Song song;
  final VoidCallback? onTap;
  final double width;

  const SongCardHorizontal({
    super.key,
    required this.song,
    this.onTap,
    this.width = 160,
  });

  @override
  State<SongCardHorizontal> createState() => _SongCardHorizontalState();
}

class _SongCardHorizontalState extends State<SongCardHorizontal>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
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
        child: SizedBox(
          width: widget.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Album art
              Container(
                width: widget.width,
                height: widget.width,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.song.thumbnailUrl.isNotEmpty
                          ? Image.network(
                              widget.song.thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholder(theme),
                            )
                          : _placeholder(theme),
                      // Play overlay
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            LucideIcons.play,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Title
              Text(
                widget.song.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              // Artist
              Text(
                widget.song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        LucideIcons.music,
        size: widget.width * 0.3,
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
      ),
    );
  }
}
