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
/// use on every page. The rail is **centred** and the Skip pill sits on the
/// right, which is how every mockup from `002` on draws it; the rail is sized
/// so eight segments still clear the pill at 360dp.
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
          AppSpace.s16, AppSpace.s8, AppSpace.s16, AppSpace.s8),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(child: OnbProgressRail(step: step, total: total)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('onb_skip'),
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  minimumSize: const Size(72, 48),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    side:
                        BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                  ),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                ),
                child: const Text('Skip'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dot rail the `004` and `005` mockups close with, in place of the
/// `Step N of 8` label the later pages use. The current step is an open ring.
class OnbDots extends StatelessWidget {
  const OnbDots({required this.step, required this.total, super.key});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            Container(
              width: i == step ? 15 : 7,
              height: i == step ? 15 : 7,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == step ? null : const Color(0xFF26313F),
                border: i == step
                    ? Border.all(color: AppColors.emerald400, width: 2)
                    : null,
                boxShadow: i == step
                    ? [
                        BoxShadow(
                            color: AppColors.emerald400.withValues(alpha: 0.45),
                            blurRadius: 10)
                      ]
                    : null,
              ),
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
///
/// Measured off the mockups: ~28dp glyphs on a 30dp line pitch, so the leading
/// is deliberately tighter than the display ramp's 34/28. [trailing] carries the
/// small glyph some pages hang off the end of the accent line (`008`'s paw,
/// `009`'s heart).
class OnbHeadline extends StatelessWidget {
  const OnbHeadline(this.top, this.accent, {this.trailing, super.key});

  final String top;
  final String accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 28,
          height: 1.07,
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
            if (trailing != null)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: trailing!,
                ),
              ),
          ]),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Deck copy under the headline: ~15dp on a 17dp pitch, centred, cool grey.
///
/// The mockups colour a clause inside the sentence — pass [spans] for that;
/// [OnbSubtitle.new] is the plain-string form.
class OnbSubtitle extends StatelessWidget {
  const OnbSubtitle(String this.text, {super.key}) : spans = null;

  /// `(text, accented)` pairs, concatenated in order.
  const OnbSubtitle.rich(this.spans, {super.key}) : text = null;

  final String? text;
  final List<(String, Color?)>? spans;

  static const Color ink = Color(0xFFB4BECC);

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: ink,
          fontSize: 13,
          height: 1.38,
        );
    if (text != null) {
      return Text(text!, textAlign: TextAlign.center, style: base);
    }
    return Text.rich(
      TextSpan(children: [
        for (final (s, c) in spans!)
          TextSpan(
            text: s,
            style: c == null
                ? base
                : base?.copyWith(color: c, fontWeight: FontWeight.w600),
          ),
      ]),
      textAlign: TextAlign.center,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < total; i++)
              Container(
                // The mockups draw four ~21dp dashes; eight of those would run
                // under the Skip pill, so the rail scales down rather than
                // wrapping or being pushed off-centre.
                width: i == step ? 24 : 16,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
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
///
/// The mockups draw these glyphs in a soft halo rather than a hard ring, and
/// tint each column independently (`004`: cyan · cyan · cyan; `005`: cyan ·
/// emerald · cyan), so both are parameters.
class OnbTrustRow extends StatelessWidget {
  const OnbTrustRow({required this.items, this.dividers = true, super.key});

  /// (icon, title, caption, tint)
  final List<(IconData, String, String?, Color?)> items;
  final bool dividers;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0 && dividers)
            Container(
              width: 1,
              height: 96,
              margin: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
              color: Colors.white.withValues(alpha: 0.07),
            ),
          Expanded(
            child: Column(
              children: [
                OnbHaloIcon(items[i].$1,
                    tint: items[i].$4 ?? AppColors.cyan400, size: 38, halo: 64),
                const SizedBox(height: 4),
                Text(items[i].$2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        height: 1.2,
                        fontWeight: FontWeight.w700)),
                if (items[i].$3 != null) ...[
                  const SizedBox(height: 3),
                  Text(items[i].$3!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFF97A2B2), fontSize: 11, height: 1.28)),
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
/// The vertical-rhythm multiplier for the page currently being laid out.
///
/// The mockups are composed for a 393x851 handset. On anything shorter the
/// choice is to shrink the artwork, drop something, or close the gaps — and
/// the gaps are the only one of the three that costs nothing. [OnbGap] reads
/// this; the artwork never does.
class OnbSpacing extends InheritedWidget {
  const OnbSpacing({required this.scale, required super.child, super.key});

  final double scale;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OnbSpacing>()?.scale ?? 1.0;

  @override
  bool updateShouldNotify(OnbSpacing old) => old.scale != scale;
}

/// A vertical gap that breathes with the viewport. `OnbGap(20)` is 20dp on the
/// reference handset and proportionally tighter on a short one.
class OnbGap extends StatelessWidget {
  const OnbGap(this.height, {super.key});

  final double height;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: height * OnbSpacing.of(context));
}

/// An onboarding page: scrolling content under a **pinned** action footer.
///
/// Every mockup puts its CTA at the foot of the screen, and every one of them
/// is drawn with ~9dp body copy that cannot ship. At readable sizes the
/// composition runs past the viewport, and the CTA went with it — so the first
/// thing a new user had to do on all eight pages was scroll to find the button.
///
/// The fix keeps the artwork at full size and pins the footer instead: the
/// content scrolls independently beneath it, dissolving into a scrim so the
/// join reads as depth rather than as a bar. The CTA lands exactly where the
/// mockups draw it and is reachable on the first frame.
///
/// [footerOverlap] lets the last block run *under* the footer — `006`, `007`
/// and `009` draw their hero with the CTA sitting on top of it.
class OnbPage extends StatefulWidget {
  const OnbPage({
    required this.body,
    required this.footer,
    this.footerOverlap = 0,
    super.key,
  });

  /// Named `body` rather than `children` so the analyzer's
  /// `sort_child_properties_last` does not demand the pinned footer be
  /// declared before the page it belongs under.
  final List<Widget> body;

  /// CTA plus its step indicator. Pinned; never scrolls away.
  final Widget footer;

  /// How far the last block is allowed to run *under* the footer. `006`, `007`
  /// and `009` draw their hero with the CTA sitting on top of it.
  final double footerOverlap;

  /// Used for the first frame, before the footer has reported its real height.
  static const double _initialReserve = 136;

  /// The height the mockups are composed for.
  static const double _referenceHeight = 780;

  @override
  State<OnbPage> createState() => _OnbPageState();
}

class _OnbPageState extends State<OnbPage> {
  double _footerHeight = OnbPage._initialReserve;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale =
            (constraints.maxHeight / OnbPage._referenceHeight).clamp(0.68, 1.08);
        final reserve =
            (_footerHeight - widget.footerOverlap).clamp(0.0, 400.0) + 8;
        return OnbSpacing(
          scale: scale,
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(18, AppSpace.s8, 18, reserve),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: widget.body,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                // Measured rather than assumed: the footer is a different
                // height on the page that carries a footnote under its CTA,
                // and a constant would leave that page's last card hidden.
                child: _MeasureHeight(
                  onChange: (h) {
                    if ((h - _footerHeight).abs() > 0.5) {
                      setState(() => _footerHeight = h);
                    }
                  },
                  child: _PinnedFooter(child: widget.footer),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The footer plate: a fade strip that dissolves the scrolling content, then an
/// opaque plate carrying the action. Opaque, because a translucent one let the
/// card behind it read straight through the button.
class _PinnedFooter extends StatelessWidget {
  const _PinnedFooter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          height: 34,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00050B14), Color(0xCC050B14), Color(0xFF050B14)],
                stops: [0.0, 0.62, 1.0],
              ),
            ),
            child: SizedBox.expand(),
          ),
        ),
        ColoredBox(
          color: AppColors.navy900,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Reports its child's laid-out height, once it settles.
class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({required this.onChange, required Widget child})
      : super(child: child);

  final ValueChanged<double> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureHeight(onChange);

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderObject renderObject) {
    (renderObject as _RenderMeasureHeight).onChange = onChange;
  }
}

class _RenderMeasureHeight extends RenderProxyBox {
  _RenderMeasureHeight(this.onChange);

  ValueChanged<double> onChange;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (_last != size.height) {
      _last = size.height;
      // Deferred: reporting during layout would rebuild mid-pass.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => onChange(_last ?? 0));
    }
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

// ---------------------------------------------------------------------------
// Neon language
// ---------------------------------------------------------------------------

/// A Lucide glyph rendered the way the mockups draw every icon: a saturated
/// stroke sitting in its own bloom.
///
/// Lucide is font-based, so the bloom is a text shadow rather than a second
/// asset — the same reason the emergency colourway is an argument and not an
/// icon set (UI_PROGRESS architecture note 5).
class OnbNeonGlyph extends StatelessWidget {
  const OnbNeonGlyph(
    this.icon, {
    required this.tint,
    this.size = 30,
    this.strength = 1.0,
    super.key,
  });

  final IconData icon;
  final Color tint;
  final double size;

  /// Multiplies the bloom. `0` draws the stroke flat.
  final double strength;

  @override
  Widget build(BuildContext context) => Icon(
        icon,
        size: size,
        color: tint,
        shadows: strength <= 0
            ? null
            : [
                Shadow(
                    color: tint.withValues(alpha: 0.85 * strength),
                    blurRadius: size * 0.34),
                Shadow(
                    color: tint.withValues(alpha: 0.45 * strength),
                    blurRadius: size * 0.85),
              ],
      );
}

/// A glyph resting in a soft circular halo, with no ring — the treatment the
/// `004` trust strip and the `009` feature grid use.
class OnbHaloIcon extends StatelessWidget {
  const OnbHaloIcon(
    this.icon, {
    required this.tint,
    this.size = 46,
    this.halo = 76,
    super.key,
  });

  final IconData icon;
  final Color tint;
  final double size;
  final double halo;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: halo,
        height: halo,
        child: Stack(
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  tint.withValues(alpha: 0.14),
                  tint.withValues(alpha: 0.05),
                  Colors.transparent,
                ], stops: const [0.0, 0.55, 1.0]),
              ),
              child: SizedBox(width: halo, height: halo),
            ),
            OnbNeonGlyph(icon, tint: tint, size: size, strength: 0.55),
          ],
        ),
      );
}

/// The concentric ground ellipses every mockup floats its top crest on.
class OnbGroundRings extends StatelessWidget {
  const OnbGroundRings({this.tint = AppColors.cyan400, this.rings = 3, super.key});

  final Color tint;
  final int rings;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(painter: _RingPainter(tint, rings), size: Size.infinite),
      );
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.tint, this.rings);

  final Color tint;
  final int rings;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.5);
    for (var i = 0; i < rings; i++) {
      final t = (i + 1) / rings;
      canvas.drawOval(
        Rect.fromCenter(
            center: c, width: size.width * (0.42 + 0.29 * t), height: size.height * t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = tint.withValues(alpha: 0.34 * (1 - t * 0.66)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.tint != tint || old.rings != rings;
}

/// The page crest: supplied artwork floating over its ground rings and bloom.
class OnbCrest extends StatelessWidget {
  const OnbCrest({
    required this.asset,
    this.height = 76,
    this.tint = AppColors.cyan400,
    this.width = 132,
    super.key,
  });

  final String asset;
  final double height;
  final double width;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height + 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 26,
            child: OnbGroundRings(tint: tint),
          ),
          Positioned(
            top: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: tint.withValues(alpha: 0.30),
                      blurRadius: 34,
                      spreadRadius: -4),
                ],
              ),
              child: Image.asset(
                asset,
                height: height,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) =>
                    OnbNeonGlyph(Icons.shield_outlined, tint: tint, size: height),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The glass slab the mockups build every panel from: a neon hairline, a barely
/// tinted fill and an outer bloom of the same hue.
///
/// [notch] hangs a glyph off the top edge, straddling the border the way `004`
/// hangs its siren and its house — hence `Clip.none` and the reserved padding.
class OnbNeonCard extends StatelessWidget {
  const OnbNeonCard({
    required this.tint,
    required this.child,
    this.radius = 26,
    this.padding = const EdgeInsets.all(AppSpace.s16),
    this.notch,
    this.notchSize = 46,
    this.borderAlpha = 0.72,
    this.glow = 0.26,
    this.fill = 0.045,
    super.key,
  });

  final Color tint;
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Widget? notch;
  final double notchSize;
  final double borderAlpha;
  final double glow;
  final double fill;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tint.withValues(alpha: borderAlpha), width: 1.4),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.30, 1.0],
          colors: [
            tint.withValues(alpha: fill * 2.6),
            const Color(0xF7050B14),
            tint.withValues(alpha: fill * 1.0),
          ],
        ),
        boxShadow: [
          BoxShadow(
              color: tint.withValues(alpha: glow), blurRadius: 22, spreadRadius: -4),
        ],
      ),
      child: child,
    );
    if (notch == null) return card;
    // `passthrough` hands the incoming constraints to the card, so a row of
    // notched cards under `IntrinsicHeight`/`stretch` still comes out flush —
    // with the default loose fit each card would keep its own intrinsic height
    // and the two borders would end at different places.
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        Padding(padding: EdgeInsets.only(top: notchSize / 2), child: card),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(child: SizedBox(height: notchSize, child: notch)),
        ),
      ],
    );
  }
}

/// The tinted circular chip that leads every list row inside a neon card.
class OnbRowChip extends StatelessWidget {
  const OnbRowChip(this.icon, {required this.tint, this.size = 34, super.key});

  final IconData icon;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tint.withValues(alpha: 0.10),
          border: Border.all(color: tint.withValues(alpha: 0.55)),
        ),
        child: OnbNeonGlyph(icon, tint: tint, size: size * 0.5, strength: 0.4),
      );
}

/// The flanking capability card on `006`/`007` — glyph, title, caption, all
/// centred inside a small neon slab.
class OnbSideCard extends StatelessWidget {
  const OnbSideCard({
    required this.icon,
    required this.title,
    required this.caption,
    required this.tint,
    this.width = 108,
    super.key,
  });

  final IconData icon;
  final String title;
  final String caption;
  final Color tint;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: OnbNeonCard(
        tint: tint,
        radius: 16,
        borderAlpha: 0.42,
        glow: 0.14,
        fill: 0.03,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OnbNeonGlyph(icon, tint: tint, size: 24, strength: 0.7),
            const SizedBox(height: 6),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    height: 1.18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(caption,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF8B96A6), fontSize: 9, height: 1.26)),
          ],
        ),
      ),
    );
  }
}

/// The dashed tether the mockups run from a flanking card to the device.
class OnbDashTether extends StatelessWidget {
  const OnbDashTether({
    required this.tint,
    this.width = 26,
    this.fromLeft = true,
    super.key,
  });

  final Color tint;
  final double width;
  final bool fromLeft;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: 10,
          child: CustomPaint(painter: _TetherPainter(tint, fromLeft)),
        ),
      );
}

class _TetherPainter extends CustomPainter {
  const _TetherPainter(this.tint, this.fromLeft);

  final Color tint;
  final bool fromLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final line = Paint()
      ..color = tint.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var x = 0.0; x < size.width - 6; x += 7) {
      canvas.drawLine(Offset(x, y), Offset(x + 3.6, y), line);
    }
    final nodeX = fromLeft ? size.width - 2 : 2.0;
    canvas.drawCircle(Offset(nodeX, y), 2.6,
        Paint()..color = tint.withValues(alpha: 0.95));
    canvas.drawCircle(
        Offset(nodeX, y),
        5.2,
        Paint()
          ..color = tint.withValues(alpha: 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  }

  @override
  bool shouldRepaint(covariant _TetherPainter old) =>
      old.tint != tint || old.fromLeft != fromLeft;
}

/// `005`'s callout: a neon-bordered bubble with a tail pointing down-left at the
/// device, and a crest badge straddling its top edge.
class OnbSpeechBubble extends StatelessWidget {
  const OnbSpeechBubble({
    required this.child,
    required this.tint,
    this.width = 130,
    super.key,
  });

  final Widget child;
  final Color tint;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tint.withValues(alpha: 0.55), width: 1.3),
              color: const Color(0xFF071019).withValues(alpha: 0.72),
              boxShadow: [
                BoxShadow(
                    color: tint.withValues(alpha: 0.22),
                    blurRadius: 20,
                    spreadRadius: -4),
              ],
            ),
            child: child,
          ),
          Positioned(
            left: -7,
            bottom: 12,
            child: ExcludeSemantics(
              child: CustomPaint(size: const Size(10, 16), painter: _TailPainter(tint)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter(this.tint);

  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height * 0.62)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF071019));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = tint.withValues(alpha: 0.55));
  }

  @override
  bool shouldRepaint(covariant _TailPainter old) => old.tint != tint;
}

/// The wide elliptical light arcs the mockups pool under a device.
class OnbFloorGlow extends StatelessWidget {
  const OnbFloorGlow({this.tint = AppColors.cyan400, super.key});

  final Color tint;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(painter: _FloorPainter(tint), size: Size.infinite),
      );
}

class _FloorPainter extends CustomPainter {
  const _FloorPainter(this.tint);

  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.86);
    for (final (w, h, a, blur) in [
      (1.35, 0.62, 0.28, 2.0),
      (1.02, 0.44, 0.20, 3.0),
      (0.72, 0.28, 0.14, 4.0),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(
            center: c, width: size.width * w, height: size.height * h),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = tint.withValues(alpha: a)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FloorPainter old) => old.tint != tint;
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
