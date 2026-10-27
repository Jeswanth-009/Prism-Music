import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/entities/song.dart';
import '../../../blocs/library/library_bloc.dart';
import '../../../blocs/library/library_event.dart';
import '../../../blocs/library/library_state.dart';
import '../../../blocs/player/player_state.dart';
import '../../prism/prism_artwork.dart';
import '../player_lyrics_sheet.dart';
import '../player_slider_widget.dart';
import 'classic_player_layout.dart';

/// Audiophile Vinyl turntable player layout with rotating grooved disc,
/// tonearm styling, complete transport controls, and full lyrics parity.
class VinylPlayerLayout extends StatefulWidget {
  final Song song;
  final PlayerState state;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;
  final void Function(String artistName) onArtistTap;
  final VoidCallback onProvenanceTap;

  const VinylPlayerLayout({
    super.key,
    required this.song,
    required this.state,
    required this.showLyrics,
    required this.onToggleLyrics,
    required this.onArtistTap,
    required this.onProvenanceTap,
  });

  @override
  State<VinylPlayerLayout> createState() => _VinylPlayerLayoutState();
}

class _VinylPlayerLayoutState extends State<VinylPlayerLayout>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _tonearmController;
  late final Animation<double> _tonearmAngleAnimation;

  /// Tonearm rest angle when paused (pointing outward to side rest cradle)
  static const double _restAngle = -0.42;

  /// Tonearm active angle when playing (tracking inside the vinyl audio groove)
  static const double _grooveAngle = 0.22;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    _tonearmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      value: widget.state.isPlaying ? 1.0 : 0.0,
    );
    _tonearmAngleAnimation = Tween<double>(
      begin: _restAngle,
      end: _grooveAngle,
    ).animate(CurvedAnimation(
      parent: _tonearmController,
      curve: Curves.easeInOutCubic,
    ));

    if (widget.state.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant VinylPlayerLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.isPlaying != oldWidget.state.isPlaying) {
      if (widget.state.isPlaying) {
        _tonearmController.forward();
        if (!_rotationController.isAnimating) {
          _rotationController.repeat();
        }
      } else {
        _tonearmController.reverse();
        if (_rotationController.isAnimating) {
          _rotationController.stop();
        }
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _tonearmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.sizeOf(context).width > 600;

    return Column(
      children: [
        Expanded(
          child: widget.showLyrics
              ? PlayerLyricsView(
                  key: ValueKey('lyrics_${widget.song.id}'),
                  song: widget.song,
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? 500 : double.infinity,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 12),
                          // Turntable and rotating vinyl disk
                          _buildTurntable(context),
                          const SizedBox(height: 24),
                          // Track info with inline like button
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    GestureDetector(
                                      onTap: () => widget.onArtistTap(widget.song.artist),
                                      child: Text(
                                        widget.song.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    if (widget.song.album != null &&
                                        widget.song.album!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.song.album!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              BlocBuilder<LibraryBloc, LibraryState>(
                                builder: (context, lib) {
                                  final isLiked = lib.isSongLiked(widget.song.id);
                                  return IconButton(
                                    icon: Icon(
                                      isLiked
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_outline_rounded,
                                      color: isLiked
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    onPressed: () => context
                                        .read<LibraryBloc>()
                                        .add(ToggleLikeSongEvent(widget.song)),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        // Vinyl Scrubber
        PlayerSliderWidget(state: widget.state),
        const SizedBox(height: 12),
        // Transport Controls
        ClassicTransportControls(state: widget.state),
        const SizedBox(height: 12),
        // Bottom utilities
        ClassicUtilityRow(
          song: widget.song,
          state: widget.state,
          showLyrics: widget.showLyrics,
          onToggleLyrics: widget.onToggleLyrics,
          onProvenanceTap: widget.onProvenanceTap,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTurntable(BuildContext context) {
    final diskSize = (MediaQuery.sizeOf(context).width - 64).clamp(240.0, 310.0);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer turntable platter rim
          Container(
            width: diskSize + 12,
            height: diskSize + 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF161619),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 26,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          ),
          // Rotating Vinyl Disc
          RotationTransition(
            turns: _rotationController,
            child: Container(
              width: diskSize,
              height: diskSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFF26262C),
                    Color(0xFF141416),
                    Color(0xFF1D1D21),
                    Color(0xFF0F0F10),
                  ],
                  stops: [0.0, 0.45, 0.85, 1.0],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer groove ring
                  Container(
                    width: diskSize * 0.86,
                    height: diskSize * 0.86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                        width: 1,
                      ),
                    ),
                  ),
                  // Mid groove ring
                  Container(
                    width: diskSize * 0.72,
                    height: diskSize * 0.72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.04),
                        width: 1,
                      ),
                    ),
                  ),
                  // Inner groove ring
                  Container(
                    width: diskSize * 0.58,
                    height: diskSize * 0.58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                        width: 1,
                      ),
                    ),
                  ),
                  // Center artwork label
                  Container(
                    width: diskSize * 0.44,
                    height: diskSize * 0.44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: PrismArtwork(
                        url: widget.song.thumbnailUrl,
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: 0,
                      ),
                    ),
                  ),
                  // Spindle hole
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF121214),
                      border: Border.all(
                        color: const Color(0xFFD4AF37),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.7),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Audiophile Tonearm (animated between rest cradle and vinyl sound groove)
          Positioned(
            top: 2,
            right: 8,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _tonearmAngleAnimation,
                builder: (context, _) {
                  return AudiophileTonearm(
                    angle: _tonearmAngleAnimation.value,
                    armLength: diskSize * 0.46,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Detailed audiophile turntable tonearm with gimbal base, counterweight,
/// brushed aluminum wand, angled headshell cartridge, stylus needle, and rest cradle.
class AudiophileTonearm extends StatelessWidget {
  final double angle;
  final double armLength;

  const AudiophileTonearm({
    super.key,
    required this.angle,
    required this.armLength,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: armLength + 40,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topRight,
        children: [
          // 1. Tonearm Rest Post & Cradle (fixed to turntable deck at rest angle position)
          Positioned(
            top: 56,
            right: -2,
            child: Container(
              width: 14,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF222226),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 6,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141416),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ),
          ),

          // 2. Rotating Arm Assembly (swings around gimbal pivot center)
          Positioned(
            top: 15,
            right: 3,
            child: Transform.rotate(
              angle: angle,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 24,
                height: armLength + 24,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    // Counterweight (extends upward behind pivot)
                    Positioned(
                      top: -18,
                      child: Container(
                        width: 16,
                        height: 18,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF6E6E78),
                              Color(0xFF323238),
                              Color(0xFF1C1C20),
                              Color(0xFF4E4E56),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 4,
                              offset: const Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Tonearm Wand (precision brushed aluminum / chrome rod)
                    Positioned(
                      top: 0,
                      child: Container(
                        width: 5.5,
                        height: armLength,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2.5),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFE8E8EE),
                              Color(0xFFA8A8B2),
                              Color(0xFF686870),
                              Color(0xFF383840),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 6,
                              offset: const Offset(2.5, 3),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Subtle cueing lever accent along wand
                    Positioned(
                      top: 32,
                      right: 1,
                      child: Container(
                        width: 6,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC0C0C8),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),

                    // Headshell & Cartridge (angled inward toward groove)
                    Positioned(
                      top: armLength - 4,
                      child: Transform.rotate(
                        angle: -0.22,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Cartridge housing
                            Container(
                              width: 10,
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1E),
                                borderRadius: BorderRadius.circular(2.5),
                                border: Border.all(
                                  color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    blurRadius: 4,
                                    offset: const Offset(1.5, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  width: 2.5,
                                  height: 10,
                                  color: const Color(0xFFD4AF37),
                                ),
                              ),
                            ),
                            // Stylus needle tip (precision indicator)
                            Container(
                              width: 2.5,
                              height: 4.5,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF453A),
                                borderRadius: BorderRadius.circular(1),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF453A).withValues(alpha: 0.9),
                                    blurRadius: 3,
                                  ),
                                ],
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
          ),

          // 3. Fixed Gimbal Pivot Bearing (mounted on deck, above the rotating assembly)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFF5E5E68),
                    Color(0xFF2C2C32),
                    Color(0xFF141416),
                  ],
                  stops: [0.0, 0.65, 1.0],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 8,
                    offset: const Offset(1, 3),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
