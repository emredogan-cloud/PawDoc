import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/design_tokens.dart';

/// Motion foundation primitives (PAWDOC_UI_UX_MASTER_ROADMAP.md §4).
///
/// Philosophy: *calm confidence.* Every animation in the app must honor
/// [reduceMotion] and render a static equivalent — mandatory for an
/// accessibility- and anxiety-sensitive health app (§4.9 rule #1).

/// True when the user/OS has requested reduced motion (Android "Remove
/// animations", iOS "Reduce Motion"). Drives the static fallbacks below.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// Primary-CTA wrapper: press-scale 1.0→0.97 + a light haptic on tap, spring
/// back on release (§4.2 / §4.4). Layout-identical to a [FilledButton]; honors
/// reduce-motion (no scale). Drop-in: `AppButton(onPressed: …, child: Text(…))`.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
  });

  final VoidCallback? onPressed;
  final Widget child;

  /// Optional leading icon → renders a [FilledButton.icon] instead of a plain
  /// [FilledButton].
  final Widget? icon;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  double _scale = 1.0;

  void _setPressed(bool pressed) {
    if (widget.onPressed == null || reduceMotion(context)) return;
    setState(() => _scale = pressed ? 0.97 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = widget.onPressed == null
        ? null
        : () {
            HapticFeedback.lightImpact();
            widget.onPressed!();
          };
    final button = widget.icon == null
        ? FilledButton(onPressed: onPressed, child: widget.child)
        : FilledButton.icon(
            onPressed: onPressed,
            icon: widget.icon!,
            label: widget.child,
          );
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _scale,
        duration: AppMotion.micro,
        curve: AppMotion.standardCurve,
        child: button,
      ),
    );
  }
}

/// A single shimmering placeholder block (skeleton loading, §4.3). The base uses
/// the raised surface (ink/700 in dark) so it matches real cards; the shimmer
/// sweep is a 1.2s loop. Under reduce-motion it renders as a static block (no
/// loop, no pending timers).
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final block = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    if (reduceMotion(context)) return block;
    return block
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: const Duration(milliseconds: 1200),
          color: scheme.surfaceContainerHighest,
        );
  }
}

/// A card-shaped skeleton matching the home pet-hero / insight cards.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height = 92});
  final double height;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
        child: Skeleton(height: height, radius: AppRadius.md),
      );
}

/// A timeline-node skeleton (a small dot + two text lines) matching the history
/// timeline (§4.3 — "3 ghost nodes + lines").
class SkeletonTimelineNode extends StatelessWidget {
  const SkeletonTimelineNode({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s16, vertical: AppSpace.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Skeleton(width: 20, height: 20, radius: AppRadius.pill),
            const SizedBox(width: AppSpace.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Skeleton(width: 140, height: 14),
                  SizedBox(height: AppSpace.s8),
                  Skeleton(height: 12),
                ],
              ),
            ),
          ],
        ),
      );
}
