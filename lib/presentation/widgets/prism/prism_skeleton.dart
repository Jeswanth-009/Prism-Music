import 'package:flutter/material.dart';

import '../../theme/prism_theme.dart';

/// Animated shimmer block. Wrap a group of these in a [PrismSkeletonGroup]
/// so the whole group shares one animation controller.
class PrismSkeleton extends StatelessWidget {
  const PrismSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.borderRadius,
  });

  final double width;
  final double height;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final spec = context.prismSpec;
    final controller = PrismSkeletonGroup.maybeOf(context);

    Widget block = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: spec.skeletonBase,
        borderRadius: BorderRadius.circular(borderRadius ?? height / 2),
      ),
    );

    if (controller == null) return block;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = bounds.width * (t * 2 - 1);
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                spec.skeletonBase,
                spec.skeletonHighlight,
                spec.skeletonBase,
              ],
              stops: const [0.25, 0.5, 0.75],
            ).createShader(Rect.fromLTWH(dx, 0, bounds.width, bounds.height));
          },
          child: child,
        );
      },
      child: block,
    );
  }
}

/// Drives one shared shimmer animation for all descendant [PrismSkeleton]s.
class PrismSkeletonGroup extends StatefulWidget {
  const PrismSkeletonGroup({super.key, required this.child});

  final Widget child;

  static AnimationController? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<_PrismSkeletonGroupState>()?._controller;

  @override
  State<PrismSkeletonGroup> createState() => _PrismSkeletonGroupState();
}

class _PrismSkeletonGroupState extends State<PrismSkeletonGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Ready-made skeleton for a horizontal rail of artwork cards.
class PrismRailSkeleton extends StatelessWidget {
  const PrismRailSkeleton({super.key, this.cardWidth = 140});

  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    return PrismSkeletonGroup(
      child: SizedBox(
        height: cardWidth + 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(3, (i) {
            return Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 14),
              child: SizedBox(
                width: cardWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: PrismSkeleton(
                        borderRadius: PrismRadius.lg,
                        height: double.infinity,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const PrismSkeleton(width: 100, height: 12),
                    const SizedBox(height: 6),
                    const PrismSkeleton(width: 60, height: 10),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Ready-made skeleton for a vertical list of song rows.
class PrismListSkeleton extends StatelessWidget {
  const PrismListSkeleton({super.key, this.count = 6, this.padding});

  final int count;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return PrismSkeletonGroup(
      child: Column(
        children: List.generate(count, (i) {
          return Padding(
            padding: (padding ?? const EdgeInsets.symmetric(horizontal: 20))
                .add(const EdgeInsets.only(bottom: 14)),
            child: Row(
              children: [
                PrismSkeleton(
                  width: 48,
                  height: 48,
                  borderRadius: PrismRadius.sm,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PrismSkeleton(height: 12),
                      SizedBox(height: 6),
                      PrismSkeleton(width: 110, height: 10),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
