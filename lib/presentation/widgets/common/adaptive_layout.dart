import 'package:flutter/material.dart';

/// Breakpoints and responsive layout utilities for tablet, desktop,
/// and landscape orientations across Prism Music.
class AdaptiveBreakpoints {
  const AdaptiveBreakpoints._();

  /// Standard compact breakpoint threshold (e.g. phones in portrait).
  static const double tabletWidth = 720.0;

  /// Large tablet / desktop threshold.
  static const double desktopWidth = 1024.0;

  /// Returns true if the device width meets or exceeds tablet sizing.
  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= tabletWidth;
  }

  /// Returns true if the screen is in landscape orientation.
  static bool isLandscape(BuildContext context) {
    return MediaQuery.orientationOf(context) == Orientation.landscape;
  }

  /// Returns true if an expanded two-pane or rail layout should be used.
  static bool isExpanded(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width >= tabletWidth ||
        (size.width > 540 && isLandscape(context));
  }
}

/// A responsive widget builder that switches between compact (mobile portrait)
/// and expanded (tablet / landscape) presentations.
class AdaptiveLayoutBuilder extends StatelessWidget {
  const AdaptiveLayoutBuilder({
    super.key,
    required this.compact,
    required this.expanded,
  });

  final Widget Function(BuildContext context) compact;
  final Widget Function(BuildContext context) expanded;

  @override
  Widget build(BuildContext context) {
    if (AdaptiveBreakpoints.isExpanded(context)) {
      return expanded(context);
    }
    return compact(context);
  }
}

/// Split-pane container for side-by-side presentation in landscape/tablet mode.
class AdaptiveSplitPane extends StatelessWidget {
  const AdaptiveSplitPane({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
    this.spacing = 24.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  final double spacing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: leftFlex,
            child: left,
          ),
          SizedBox(width: spacing),
          Expanded(
            flex: rightFlex,
            child: right,
          ),
        ],
      ),
    );
  }
}
