import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/ui_assets.dart';

/// System A presentation layer for onboarding.
///
/// The onboarding mockups (`000`, `002`–`009`) are a different visual system
/// from the in-app product: navy canvas, emerald primary, heavy cyan co-accent,
/// split-colour display headlines and neon-outlined glyphs
/// (UI_ASSET_SPECIFICATION §1.3). These primitives reproduce that language once
/// so each page composes rather than re-styling by hand.
///
/// Nothing here carries copy, safety logic or navigation — pages own those.

// ---------------------------------------------------------------------------
// Backdrop
// ---------------------------------------------------------------------------

/// Navy canvas with the mockups' faint star field and paw watermarks.
///
/// Painted rather than shipped as an asset: it is a handful of primitives, it
/// scales to any screen without a 3x raster, and it costs nothing in bundle
/// size. Decorative only — excluded from semantics.
class OnbBackdrop extends StatelessWidget {
  const OnbBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navy900, Color(0xFF060D1B), AppColors.navy900],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(painter: _StarFieldPainter()),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final star = Paint()..color = const Color(0x33BFD9FF);
    for (var i = 0; i < 46; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(dx, dy), rng.nextDouble() * 1.5 + 0.4, star);
    }

    // Paw watermarks, very low alpha, like the mockups' background texture.
    final paw = Paint()..color = const Color(0x0F7FE6D6);
    for (var i = 0; i < 7; i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final s = rng.nextDouble() * 16 + 14;
      _paw(canvas, Offset(cx, cy), s, paw);
    }
  }

  void _paw(Canvas c, Offset o, double s, Paint p) {
    c.drawOval(Rect.fromCenter(center: o.translate(0, s * .28), width: s * .78, height: s * .66), p);
    for (final a in [-0.62, -0.21, 0.21, 0.62]) {
      c.drawOval(
        Rect.fromCenter(
          center: o.translate(math.sin(a) * s * .46, -math.cos(a) * s * .42),
          width: s * .27,
          height: s * .34,
        ),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Chrome
// ---------------------------------------------------------------------------

/// Segmented progress + Skip, matching the mockups' header.
///
/// Completed segments are cyan, the current one emerald — the co-accent
/// carrying "done" and the primary carrying "here" is the pattern the mockups
/// use on every page.
class OnbHeader extends StatelessWidget {
  const OnbHeader({
    required this.step,
    required this.total,
    required this.onSkip,
    super.key,
  });

  final int step;
  final int total;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.s20, AppSpace.s12, AppSpace.s20, AppSpace.s8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: 'Step ${step + 1} of $total',
              child: ExcludeSemantics(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < total; i++)
                      AnimatedContainer(
                        duration: AppMotion.standard,
                        width: i == step ? 30 : 22,
                        height: 5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: i < step
                              ? AppColors.cyan400
                              : i == step
                                  ? AppColors.emerald400
                                  : const Color(0xFF243044),
                          boxShadow: i == step
                              ? [
                                  BoxShadow(
                                      color: AppColors.emerald400
                                          .withValues(alpha: 0.5),
                                      blurRadius: 8)
                                ]
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          TextButton(
            key: const Key('onb_skip'),
            onPressed: onSkip,
            style: TextButton.styleFrom(
              minimumSize: const Size(88, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
              ),
              foregroundColor: Colors.white,
            ),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }
}

/// `Step 5 of 8`, with the number in the accent — the mockups' footer label.
class OnbStepLabel extends StatelessWidget {
  const OnbStepLabel({required this.step, required this.total, super.key});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: const Color(0xFF7C8AA0));
    return ExcludeSemantics(
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: 'Step ', style: muted),
          TextSpan(
            text: '${step + 1}',
            style: muted?.copyWith(
                color: AppColors.emerald400, fontWeight: FontWeight.w700),
          ),
          TextSpan(text: ' of $total', style: muted),
        ]),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Type
// ---------------------------------------------------------------------------

/// The two-line split-colour display headline used on every onboarding page:
/// first line white, second line emerald.
class OnbHeadline extends StatelessWidget {
  const OnbHeadline(this.top, this.accent, {super.key});

  final String top;
  final String accent;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          height: 1.12,
          letterSpacing: -0.5,
        );
    return Semantics(
      header: true,
      label: '$top $accent',
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '$top\n', style: base?.copyWith(color: Colors.white)),
            TextSpan(
                text: accent,
                style: base?.copyWith(color: AppColors.emerald400)),
          ]),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class OnbSubtitle extends StatelessWidget {
  const OnbSubtitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: const Color(0xFFA9B4C4),
            height: 1.45,
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// Content blocks
// ---------------------------------------------------------------------------

/// Applies a [BlendMode] against everything already painted beneath it.
///
/// Flutter's `ColorFiltered`/`Opacity` cannot do this: a blend has to be
/// composited against the backdrop, which needs its own saveLayer. Used to drop
/// the solid-black background out of the supplied neon artwork — under `screen`
/// black is the identity value, so the plate merges into the canvas with no
/// matte line and no alpha channel to author.
class BlendMask extends SingleChildRenderObjectWidget {
  const BlendMask({required this.blendMode, super.child, super.key});

  final BlendMode blendMode;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBlendMask(blendMode);

  @override
  void updateRenderObject(BuildContext context, covariant RenderObject renderObject) {
    (renderObject as _RenderBlendMask).blendMode = blendMode;
  }
}

class _RenderBlendMask extends RenderProxyBox {
  _RenderBlendMask(this._blendMode);

  BlendMode _blendMode;
  set blendMode(BlendMode v) {
    if (v == _blendMode) return;
    _blendMode = v;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    context.canvas.saveLayer(offset & size, Paint()..blendMode = _blendMode);
    super.paint(context, offset);
    context.canvas.restore();
  }
}

/// The segmented step rail on its own, for screens that show it without the
/// Skip affordance (the app-open screen).
class OnbProgressRail extends StatelessWidget {
  const OnbProgressRail({required this.step, required this.total, super.key});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${step + 1} of $total',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < total; i++)
              Container(
                width: i == step ? 30 : 22,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: i < step
                      ? AppColors.cyan400
                      : i == step
                          ? AppColors.emerald400
                          : const Color(0xFF243044),
                  boxShadow: i == step
                      ? [
                          BoxShadow(
                              color:
                                  AppColors.emerald400.withValues(alpha: 0.5),
                              blurRadius: 8)
                        ]
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Photographic hero, faded into the canvas at its edges.
///
/// The generated hero plates came back **opaque** — the subject sits on a
/// rendered dark background rather than on alpha — so placing one directly on
/// the navy canvas draws a hard rectangle, which is exactly what device
/// validation showed. The mockups have no such seam. A radial alpha mask
/// dissolves the edge, so the photo reads as part of the page the way a true
/// cut-out would, without needing the asset regenerated.
class OnbHero extends StatelessWidget {
  const OnbHero(this.asset, {this.height = 240, super.key});

  final String asset;
  final double height;

  @override
  Widget build(BuildContext context) {
    // No outer SizedBox: it would span the full row width, so on a portrait
    // asset the fade zone fell outside the image and the hard edge survived.
    // ShaderMask sizes to its child, and an Image given only a height
    // shrink-wraps to its aspect ratio — so the gradient lands on the artwork.
    return ShaderMask(
      shaderCallback: (rect) => const RadialGradient(
        center: Alignment.center,
        radius: 0.78,
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0.0, 0.55, 1.0],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: Image.asset(
        asset,
        height: height,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => Icon(Icons.pets_rounded,
            size: height * 0.45, color: AppColors.emerald400),
      ),
    );
  }
}

/// Circular neon-outlined glyph — the mockups' icon treatment.
class OnbGlowIcon extends StatelessWidget {
  const OnbGlowIcon(this.icon, {this.color, this.size = 56, super.key});

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.cyan400;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: 0.08),
        border: Border.all(color: c.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(color: c.withValues(alpha: 0.22), blurRadius: 16, spreadRadius: -2),
        ],
      ),
      child: Icon(icon, size: size * 0.45, color: c),
    );
  }
}

/// Glyph + title + caption in a translucent card — the floating feature tiles
/// that flank the hero on `000`, `003`, `006` and `007`.
class OnbFeatureCard extends StatelessWidget {
  const OnbFeatureCard({
    required this.icon,
    required this.title,
    required this.caption,
    this.color,
    super.key,
  });

  final IconData icon;
  final String title;
  final String caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.emerald400;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          OnbGlowIcon(icon, color: c, size: 44),
          const SizedBox(height: AppSpace.s8),
          Text(title,
              style: text.titleSmall?.copyWith(color: Colors.white, height: 1.2)),
          const SizedBox(height: 2),
          Text(caption,
              style: text.bodySmall?.copyWith(
                  color: const Color(0xFF8C97A8), height: 1.3)),
        ],
      ),
    );
  }
}

/// The 3-across trust strip that closes most onboarding pages.
class OnbTrustRow extends StatelessWidget {
  const OnbTrustRow({required this.items, super.key});

  /// (icon, title, caption)
  final List<(IconData, String, String?)> items;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 64,
              margin: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
              color: Colors.white.withValues(alpha: 0.08),
            ),
          Expanded(
            child: Column(
              children: [
                OnbGlowIcon(items[i].$1, size: 48),
                const SizedBox(height: AppSpace.s8),
                Text(items[i].$2,
                    textAlign: TextAlign.center,
                    style: text.titleSmall
                        ?.copyWith(color: Colors.white, height: 1.2)),
                if (items[i].$3 != null) ...[
                  const SizedBox(height: 2),
                  Text(items[i].$3!,
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(
                          color: const Color(0xFF8C97A8), height: 1.3)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Bordered panel used for the reassurance / transparency blocks.
class OnbPanel extends StatelessWidget {
  const OnbPanel({
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(AppSpace.s16),
    super.key,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.emerald500;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.22)),
      ),
      child: child,
    );
  }
}

/// Small shield + line, the footer reassurance on `000`, `002` and `008`.
class OnbFooterNote extends StatelessWidget {
  const OnbFooterNote(this.text, {this.icon = Icons.verified_user_outlined, super.key});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppColors.emerald500),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: const Color(0xFF8C97A8)),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Action
// ---------------------------------------------------------------------------

/// Emerald gradient pill with a trailing chevron and the mockups' outer glow.
class OnbCta extends StatelessWidget {
  const OnbCta({
    required this.label,
    required this.onPressed,
    this.trailing = Icons.chevron_right_rounded,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData trailing;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Ink(
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5BE36B), AppColors.emerald500],
                ),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: AppColors.emerald500.withValues(alpha: 0.42),
                          blurRadius: 26,
                          offset: const Offset(0, 6),
                        )
                      ]
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (busy)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF04140A)),
                      )
                    else ...[
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  color: const Color(0xFF04140A),
                                  fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(trailing, size: 24, color: const Color(0xFF04140A)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scrolls on short screens instead of overflowing, so a CTA is always
/// reachable — carried over from the previous flow, which fixed exactly that.
class OnbPage extends StatelessWidget {
  const OnbPage({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.s20, AppSpace.s8, AppSpace.s20, AppSpace.s24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Wraps a page body in the System A scope + backdrop.
class OnbSurface extends StatelessWidget {
  const OnbSurface({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      PawSystemScope(system: PawSystem.a, child: OnbBackdrop(child: child));
}

// ---------------------------------------------------------------------------
// Device mockup
// ---------------------------------------------------------------------------

/// A real iPhone frame with live Flutter content inside its screen.
///
/// The frame is the supplied `onb-device-iphone-frame` plate, trimmed to the
/// device itself — the original carried ~45% empty margin, which squeezed the
/// usable screen down to about 120dp and made any content inside unreadable.
///
/// Content is a live child rather than a baked screenshot: the copy inside
/// these mockups is safety-relevant, so it has to stay translatable, scalable
/// and reachable by a screen reader.
class OnbPhoneMockup extends StatelessWidget {
  const OnbPhoneMockup({
    required this.child,
    this.height = 380,
    this.glow = AppColors.cyan400,
    super.key,
  });

  final Widget child;
  final double height;
  final Color glow;

  /// Screen aperture as a fraction of the trimmed frame, measured off the
  /// asset's white screen area.
  static const _l = 0.041, _r = 0.959, _t = 0.021, _b = 0.979;

  @override
  Widget build(BuildContext context) {
    final w = height * (509 / 1100);
    return SizedBox(
      width: w,
      height: height,
      child: Stack(
        children: [
          // Bloom behind the device, as the mockups light it.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                        color: glow.withValues(alpha: 0.30),
                        blurRadius: 44,
                        spreadRadius: -6),
                  ],
                  borderRadius: BorderRadius.circular(w * 0.14),
                ),
              ),
            ),
          ),
          // Screen content, clipped to the aperture and sitting under the frame
          // so the bezel and the notch draw over it.
          Positioned(
            left: w * _l,
            right: w * (1 - _r),
            top: height * _t,
            bottom: height * (1 - _b),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(w * 0.115),
              child: ColoredBox(
                color: const Color(0xFF060C16),
                child: MediaQuery(
                  // The mockup is a picture of an app, not the app: freeze text
                  // scaling so the user's accessibility setting cannot reflow
                  // a decorative screenshot into an overflow.
                  data: MediaQuery.of(context).copyWith(
                      textScaler: const TextScaler.linear(1.0)),
                  child: child,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Image.asset(
                UiAssets.onbDeviceFrameTrimmed,
                fit: BoxFit.fill,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The cyan light ribbon that sweeps behind the hero on `002`.
class OnbSwoosh extends StatelessWidget {
  const OnbSwoosh({this.color = AppColors.cyan300, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: CustomPaint(painter: _SwooshPainter(color), size: Size.infinite));
}

class _SwooshPainter extends CustomPainter {
  const _SwooshPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    for (final (stroke, alpha, blur) in [(9.0, 0.20, 16.0), (3.4, 0.95, 3.0)]) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
      // An S that passes behind the subject: in at the upper left, out at the
      // lower right.
      final path = Path()
        ..moveTo(w * 0.02, h * 0.44)
        ..cubicTo(w * 0.16, h * 0.16, w * 0.44, h * 0.20, w * 0.52, h * 0.46)
        ..cubicTo(w * 0.60, h * 0.72, w * 0.86, h * 0.74, w * 0.99, h * 0.58);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _SwooshPainter old) => old.color != color;
}
