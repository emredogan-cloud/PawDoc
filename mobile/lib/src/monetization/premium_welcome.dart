import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/motion.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';

/// Next Evolution Phase 8 — the premium welcome moment.
///
/// Shown ONLY from explicit entitlement-active events (purchase success /
/// restore success), so it inherently fires once per transition — no state
/// observation, no double-trigger from webhook races. Copy is limited to
/// REAL entitlements (no overclaims), and it closes on the honesty line:
/// safety checks stay free for everyone.
Future<void> showPremiumWelcome(BuildContext context,
    {bool restored = false}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Premium welcome',
    barrierColor: Colors.black54,
    transitionDuration:
        reduceMotion(context) ? Duration.zero : AppMotion.standard,
    pageBuilder: (dialogContext, _, _) =>
        _PremiumWelcome(restored: restored),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: child,
    ),
  );
}

class _PremiumWelcome extends StatelessWidget {
  const _PremiumWelcome({required this.restored});

  final bool restored;

  static const _benefits = [
    (Icons.photo_camera_rounded, 'Unlimited photo health checks'),
    (Icons.auto_awesome_rounded, 'Unlimited Assistant conversations'),
    (Icons.photo_library_rounded, 'Unlimited pet memories'),
    (Icons.picture_as_pdf_rounded, 'PDF health reports included'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final still = reduceMotion(context);

    Widget staged(Widget child, int index) {
      if (still) return child;
      return child
          .animate()
          .fadeIn(
            duration: AppMotion.standard,
            delay: Duration(milliseconds: 120 * index),
          )
          .slideY(
            begin: 0.15,
            end: 0,
            duration: AppMotion.standard,
            curve: AppMotion.emphasized,
          );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // Brand navy (the icon world) melting into the app's dark green.
            colors: [Color(0xFF071129), Color(0xFF0A1A22), PawPalette.bgBottom],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: ExcludeSemantics(child: _SparkleField()),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpace.s24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxWidth: AppSpace.maxContentWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        staged(
                          Container(
                            width: 104,
                            height: 104,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                  colors: [PawPalette.mint, PawPalette.teal]),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      PawPalette.glow.withValues(alpha: 0.45),
                                  blurRadius: 48,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.workspace_premium_rounded,
                                size: 52, color: PawPalette.bgBottom),
                          ),
                          0,
                        ),
                        const SizedBox(height: AppSpace.s24),
                        staged(
                          Text(
                            restored
                                ? 'Welcome back to Premium'
                                : 'Welcome to Premium',
                            key: const Key('premium_welcome_title'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium
                                ?.copyWith(color: AppColors.ink50),
                          ),
                          1,
                        ),
                        const SizedBox(height: AppSpace.s8),
                        staged(
                          Text(
                            'Thank you for backing ${'PawDoc'}\'s mission — '
                            'every memory, every check, every walk, all in '
                            'one place.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: AppColors.ink300),
                          ),
                          2,
                        ),
                        const SizedBox(height: AppSpace.s24),
                        for (var i = 0; i < _benefits.length; i++)
                          staged(
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpace.s8),
                              child: PawFeatureRow(
                                icon: _benefits[i].$1,
                                title: _benefits[i].$2,
                                trailing: const PawCheck(),
                              ),
                            ),
                            3 + i,
                          ),
                        const SizedBox(height: AppSpace.s16),
                        staged(
                          PawPrimaryButton(
                            key: const Key('premium_welcome_continue'),
                            icon: Icons.pets_rounded,
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Continue'),
                          ),
                          3 + _benefits.length,
                        ),
                        const SizedBox(height: AppSpace.s12),
                        staged(
                          Text(
                            'And as always — safety checks stay free for '
                            'everyone.',
                            key: const Key('premium_welcome_honesty'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: AppColors.ink300),
                          ),
                          4 + _benefits.length,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sparse deterministic sparkles + two faint paw marks — painted, no assets.
class _SparkleField extends StatelessWidget {
  const _SparkleField();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _SparklePainter(), size: Size.infinite);
}

class _SparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(21);
    final star = Paint()..color = PawPalette.mint.withValues(alpha: 0.20);
    for (var i = 0; i < 34; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 1.8 + 0.4,
        star,
      );
    }
    final paw = Paint()..color = Colors.white.withValues(alpha: 0.035);
    for (final (cx, cy, s, rot) in [
      (size.width * 0.16, size.height * 0.20, 30.0, -0.4),
      (size.width * 0.85, size.height * 0.78, 38.0, 0.5),
    ]) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(0, s * 0.35), width: s * 1.15, height: s * 0.9),
          paw);
      for (final (dx, dy) in [(-0.62, -0.25), (-0.22, -0.52), (0.22, -0.52), (0.62, -0.25)]) {
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(s * dx, s * dy),
                width: s * 0.38,
                height: s * 0.5),
            paw);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
