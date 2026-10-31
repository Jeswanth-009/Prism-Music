import 'package:flutter/material.dart';
import 'prism_theme.dart';

/// A Material 3 style smooth fade-through & subtle vertical slide page transition
/// that respects system and user reduced-motion preferences.
class PrismPageTransitionsBuilder extends PageTransitionsBuilder {
  const PrismPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (PrismMotion.isReducedMotion(context)) {
      return child;
    }

    // Forward entrance: subtle slide up (12dp) with easeOutCubic curve
    final slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: PrismMotion.curve,
    ));

    final fadeAnimation = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
    );

    // Subtle scale & fade out for outgoing page
    final secondaryFade = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeIn,
      ),
    );

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: FadeTransition(
          opacity: secondaryFade,
          child: child,
        ),
      ),
    );
  }
}

/// A PageRoute that uses Prism\'s signature page transition.
class PrismPageRoute<T> extends MaterialPageRoute<T> {
  PrismPageRoute({
    required super.builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
    super.allowSnapshotting,
    super.barrierDismissible,
  });

  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return const PrismPageTransitionsBuilder().buildTransitions(
      this,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
