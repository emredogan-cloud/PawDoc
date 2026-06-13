import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/motion.dart';
import 'design_tokens.dart';

/// NEW UI translation design-system layer (OLD→NEW migration, 2026-06-12).
///
/// The new mockups live in a deep **teal-green gradient world** (cream on the
/// login screen) with glowing hero art, soft particles, mint→teal gradient pill
/// CTAs and dark rounded feature cards. These primitives reproduce that language
/// once, so every translated screen restyles by composition — not by hand.
///
/// Nothing here carries safety logic, routing, or business rules. Widget keys,
/// callbacks and providers stay on the screens that own them.

/// Background flavor: the signature dark teal-green, or the login-only cream.
enum PawSurface { dark, cream }

/// Shared palette for the new look (sampled from the mockups; close enough for
/// ≥95% parity, exact values tuned on device).
class PawPalette {
  const PawPalette._();

  // Dark teal-green background ramp (top → bottom).
  static const Color bgTop = Color(0xFF123A31);
  static const Color bgMid = Color(0xFF0C211C);
  static const Color bgBottom = Color(0xFF07100E);

  // Cream (login) ramp.
  static const Color creamTop = Color(0xFFF8F2E6);
  static const Color creamBottom = Color(0xFFF0E6D4);
  static const Color forestInk = Color(0xFF1E4A40); // cream-screen headings
  static const Color forestBody = Color(0xFF4B6F66); // cream-screen body

  // Mint→teal CTA gradient.
  static const Color mint = Color(0xFF7FE6D6);
  static const Color teal = Color(0xFF34C7AE);

  // Glow + accents.
  static const Color glow = Color(0xFF2BD8BE);
  static const Color leaf = Color(0xFF1B4E40);
  static const Color heart = Color(0xFFFF8A80);
}

/// Full-bleed background: gradient + a soft hero glow + faint particles and
/// bottom botanicals. Purely decorative (excluded from semantics).
class PawBackground extends StatelessWidget {
  const PawBackground({
    super.key,
    required this.child,
    this.variant = PawSurface.dark,
    this.showDecor = true,
  });

  final Widget child;
  final PawSurface variant;
  final bool showDecor;

  @override
  Widget build(BuildContext context) {
    final dark = variant == PawSurface.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [PawPalette.bgTop, PawPalette.bgMid, PawPalette.bgBottom]
              : const [PawPalette.creamTop, PawPalette.creamBottom],
          stops: dark ? const [0.0, 0.5, 1.0] : const [0.0, 1.0],
        ),
      ),
      child: Stack(
        children: [
          if (showDecor)
            Positioned.fill(
              child: ExcludeSemantics(
                child: CustomPaint(painter: _PawDecorPainter(dark: dark)),
              ),
            ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// A [Scaffold] pre-wrapped in [PawBackground] with a transparent app bar slot.
/// Keeps `resizeToAvoidBottomInset` semantics so keyboards behave as before.
class PawScaffold extends StatelessWidget {
  const PawScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.variant = PawSurface.dark,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.showDecor = true,
    this.safeArea = true,
    this.resizeToAvoidBottomInset,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final PawSurface variant;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool showDecor;
  final bool safeArea;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: PawBackground(
        variant: variant,
        showDecor: showDecor,
        child: safeArea ? SafeArea(child: body) : body,
      ),
    );
  }
}

/// Mint→teal gradient stadium CTA with a soft glow and an optional leading icon
/// (the mockups put a small paw inside primary buttons). Reproduces
/// [AppButton]'s press-scale + light haptic, reduce-motion-gated. Pass a `key`
/// through for tests — disabled when [onPressed] is null.
class PawPrimaryButton extends StatefulWidget {
  const PawPrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.expand = true,
    this.variant = PawSurface.dark,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final bool expand;

  /// Dark world → mint→teal gradient with dark ink text. Cream (login) → deep
  /// teal fill with white text (matches the 001 reference).
  final PawSurface variant;

  @override
  State<PawPrimaryButton> createState() => _PawPrimaryButtonState();
}

class _PawPrimaryButtonState extends State<PawPrimaryButton> {
  double _scale = 1.0;

  void _setPressed(bool pressed) {
    if (widget.onPressed == null || reduceMotion(context)) return;
    setState(() => _scale = pressed ? 0.97 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final cream = widget.variant == PawSurface.cream;
    final fg = cream ? Colors.white : PawPalette.bgBottom;
    final gradientColors = cream
        ? const [Color(0xFF2FA28E), Color(0xFF1B7565)]
        : const [PawPalette.mint, PawPalette.teal];
    final label = DefaultTextStyle.merge(
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
          ),
      child: IconTheme.merge(
        data: IconThemeData(color: fg, size: 20),
        child: widget.child,
      ),
    );
    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 20, color: fg),
          const SizedBox(width: AppSpace.s8),
        ],
        Flexible(child: label),
      ],
    );
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: AnimatedScale(
        scale: _scale,
        duration: AppMotion.micro,
        curve: AppMotion.standardCurve,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            gradient: LinearGradient(colors: gradientColors),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: PawPalette.glow.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled
                  ? () {
                      HapticFeedback.lightImpact();
                      widget.onPressed!();
                    }
                  : null,
              onTapDown: (_) => _setPressed(true),
              onTapUp: (_) => _setPressed(false),
              onTapCancel: () => _setPressed(false),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s24, vertical: AppSpace.s16),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined stadium pill (secondary action) in the new palette.
class PawSecondaryButton extends StatelessWidget {
  const PawSecondaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.variant = PawSurface.dark,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final PawSurface variant;

  @override
  Widget build(BuildContext context) {
    final cream = variant == PawSurface.cream;
    final fg = cream ? PawPalette.forestInk : PawPalette.mint;
    final border = cream
        ? PawPalette.forestInk.withValues(alpha: 0.25)
        : PawPalette.mint.withValues(alpha: 0.45);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null
          ? const SizedBox.shrink()
          : Icon(icon, size: 20, color: fg),
      label: child,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s24, vertical: AppSpace.s16),
        minimumSize: const Size.fromHeight(0),
      ),
    );
  }
}

/// Rounded translucent surface used for cards/sheets on the dark world.
class PawCard extends StatelessWidget {
  const PawCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.s16),
    this.variant = PawSurface.dark,
    this.onTap,
    this.radius = AppRadius.lg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final PawSurface variant;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cream = variant == PawSurface.cream;
    final bg = cream
        ? Colors.white.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.045);
    final border = cream
        ? PawPalette.forestInk.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.07);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: border),
    );
    return Material(
      color: bg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A feature/benefit row: leading rounded icon tile + title + optional subtitle
/// + optional trailing (check / chevron). Matches the dark card rows used across
/// onboarding, premium, account and capture screens.
class PawFeatureRow extends StatelessWidget {
  const PawFeatureRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.variant = PawSurface.dark,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final PawSurface variant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cream = variant == PawSurface.cream;
    final titleColor = cream ? PawPalette.forestInk : AppColors.ink50;
    final subColor = cream ? PawPalette.forestBody : AppColors.ink300;
    return PawCard(
      variant: variant,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpace.s12),
      radius: AppRadius.md,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: PawPalette.teal.withValues(alpha: cream ? 0.14 : 0.18),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 20, color: PawPalette.mint),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleSmall?.copyWith(color: titleColor)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(color: subColor)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpace.s8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Small green check used as the trailing affordance on feature rows.
class PawCheck extends StatelessWidget {
  const PawCheck({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) => Icon(
        Icons.check_circle_rounded,
        size: size,
        color: PawPalette.mint,
      );
}

/// Painter for the decorative layer: a soft hero glow, sparse twinkles (dark
/// only) and two low-opacity botanical clusters anchored to the bottom corners.
class _PawDecorPainter extends CustomPainter {
  _PawDecorPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    // Hero glow — a soft radial bloom in the upper third.
    final glowCenter = Offset(size.width * 0.5, size.height * 0.24);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          PawPalette.glow.withValues(alpha: dark ? 0.16 : 0.10),
          PawPalette.glow.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: glowCenter, radius: size.width * 0.7));
    canvas.drawCircle(glowCenter, size.width * 0.7, glowPaint);

    if (dark) {
      // Sparse twinkles — deterministic (seeded) so they don't shimmer-repaint.
      final rng = math.Random(42);
      final star = Paint()..color = Colors.white.withValues(alpha: 0.18);
      for (var i = 0; i < 26; i++) {
        final dx = rng.nextDouble() * size.width;
        final dy = rng.nextDouble() * size.height * 0.7;
        canvas.drawCircle(Offset(dx, dy), rng.nextDouble() * 1.4 + 0.4, star);
      }
    }

    // Bottom botanical clusters (both corners), low opacity.
    final leafPaint = Paint()
      ..color = (dark ? PawPalette.leaf : PawPalette.forestInk)
          .withValues(alpha: dark ? 0.55 : 0.14);
    _leaf(canvas, leafPaint, Offset(size.width * 0.06, size.height * 0.95), 26, -0.5);
    _leaf(canvas, leafPaint, Offset(size.width * 0.12, size.height * 0.97), 20, 0.3);
    _leaf(canvas, leafPaint, Offset(size.width * 0.95, size.height * 0.95), 26, 0.5);
    _leaf(canvas, leafPaint, Offset(size.width * 0.88, size.height * 0.97), 20, -0.3);
  }

  void _leaf(Canvas canvas, Paint paint, Offset center, double r, double rot) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rot);
    final path = Path()
      ..moveTo(0, -r)
      ..quadraticBezierTo(r * 0.7, -r * 0.2, 0, r)
      ..quadraticBezierTo(-r * 0.7, -r * 0.2, 0, -r)
      ..close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PawDecorPainter oldDelegate) =>
      oldDelegate.dark != dark;
}
