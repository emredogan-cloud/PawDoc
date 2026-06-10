import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/motion.dart';
import '../theme/design_tokens.dart';

/// Standardized go_router page transitions — Material 3 motion (§4.1).
///
/// SAFETY: the analysis result and EMERGENCY screens are pushed via Navigator
/// (`MaterialPageRoute`), NOT go_router routes, so they keep their default,
/// clear platform transition — no playful motion on the safety path (§4.9
/// rule #2). These helpers are applied only to the standard UX routes.
///
/// Reduce-motion: when on, the transition duration collapses to zero and the
/// child is shown directly (truly instant, no orphaned animation) (§4.9 rule #1).
class AppPageTransitions {
  const AppPageTransitions._();

  /// Sections / root-level destinations (home, sign-in, onboarding, history).
  static Page<void> fadeThrough(BuildContext context, Widget child) =>
      _build(context, child, _Pattern.fadeThrough);

  /// Pushed modal/detail screens (pets, family, capture, describe).
  static Page<void> sharedAxisVertical(BuildContext context, Widget child) =>
      _build(context, child, _Pattern.sharedAxisVertical);

  static Page<void> _build(BuildContext context, Widget child, _Pattern pattern) {
    final rm = reduceMotion(context);
    return CustomTransitionPage<void>(
      child: child,
      transitionDuration: rm ? Duration.zero : AppMotion.hero,
      reverseTransitionDuration: rm ? Duration.zero : AppMotion.standard,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (rm) return child;
        switch (pattern) {
          case _Pattern.fadeThrough:
            return FadeThroughTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              child: child,
            );
          case _Pattern.sharedAxisVertical:
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
              child: child,
            );
        }
      },
    );
  }
}

enum _Pattern { fadeThrough, sharedAxisVertical }
