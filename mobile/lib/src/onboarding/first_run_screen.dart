import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/ui_assets.dart';
import 'onboarding_ui.dart';

/// App-open screen — mockup `0001-app-first-screen`.
///
/// The first thing a new install shows, before onboarding. It is step 1 of 8 in
/// the progress rail, so the counter runs continuously from here through the
/// onboarding pages.
///
/// The logo and hero are the supplied artwork, composited with
/// [BlendMode.screen]: both are neon art rendered on solid black, and under
/// `screen` black is the identity value — so the plate's background disappears
/// into the canvas exactly, with no mask, no matte line and no hand-cut alpha.
///
/// The feature strip and CTA are rebuilt in Flutter rather than shipped as the
/// reference images: the strip's labels must localise and be reachable by a
/// screen reader, and the CTA has to be a real button.
class FirstRunScreen extends StatelessWidget {
  const FirstRunScreen({
    required this.onStart,
    required this.onSignIn,
    super.key,
  });

  final VoidCallback onStart;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return OnbSurface(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // ---- Logo lockup ------------------------------------------
                const _Screened(
                  asset: UiAssets.onbLogoPawdoc,
                  height: 128,
                ),

                // ---- Headline ---------------------------------------------
                const SizedBox(height: 0),
                const OnbHeadline('Welcome to', 'PawDoc!'),

                // ---- Paw divider ------------------------------------------
                const SizedBox(height: AppSpace.s16),
                const _PawDivider(),
                const SizedBox(height: AppSpace.s12),

                // ---- Subtitle, with the accented tail ----------------------
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: 'Your AI-powered pet health companion.\n'
                          'Smart insights, safe guidance, ',
                      style: text.bodyMedium?.copyWith(
                          color: const Color(0xFFC8D2DE),
                          fontSize: 15,
                          height: 1.45),
                    ),
                    TextSpan(
                      text: 'happier pets.',
                      style: text.bodyMedium?.copyWith(
                          color: AppColors.emerald400,
                          fontSize: 15,
                          height: 1.45,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                  textAlign: TextAlign.center,
                ),

                // ---- Hero: duo + neon ring + orbiting glyphs ---------------
                const SizedBox(height: AppSpace.s4),
                const _Screened(
                    asset: UiAssets.onbHeroDuoNeon, height: 288, bleed: 16),

                // ---- Feature strip ----------------------------------------
                const SizedBox(height: AppSpace.s4),
                const _FeatureStrip(),

                // ---- CTA ---------------------------------------------------
                const SizedBox(height: AppSpace.s20),
                OnbCta(
                  key: const Key('firstrun_start'),
                  label: 'Let\'s Start Your Pet\'s Journey',
                  onPressed: onStart,
                ),

                // ---- Sign-in line ------------------------------------------
                const SizedBox(height: AppSpace.s16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account? ',
                        style: text.bodyMedium
                            ?.copyWith(color: const Color(0xFF8C97A8))),
                    InkWell(
                      key: const Key('firstrun_sign_in'),
                      onTap: onSignIn,
                      borderRadius: AppRadius.brSm,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 12),
                        child: Text('Sign In',
                            style: text.bodyMedium?.copyWith(
                                color: AppColors.emerald400,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),

                // ---- Step rail ---------------------------------------------
                const SizedBox(height: AppSpace.s8),
                const OnbStepLabel(step: 0, total: 8),
                const SizedBox(height: AppSpace.s8),
                const OnbProgressRail(step: 0, total: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Neon art on solid black, composited so the black falls away.
///
/// `screen` leaves black untouched and lifts everything brighter than it, which
/// is exactly the compositing model this artwork was rendered for. Cheaper and
/// cleaner than keying an alpha channel that the plate never had.
class _Screened extends StatelessWidget {
  const _Screened({required this.asset, required this.height, this.bleed = 0});

  final String asset;
  final double height;

  /// Negative horizontal margin, so the hero can run past the page padding the
  /// way the reference lets it reach the screen edges.
  final double bleed;

  @override
  Widget build(BuildContext context) {
    // OverflowBox, not a negative margin: Container asserts that margins are
    // non-negative, and release builds strip asserts — so the negative version
    // rendered correctly on device while crashing in debug and in tests.
    return SizedBox(
      height: height,
      child: OverflowBox(
        maxWidth: bleed > 0 ? double.infinity : null,
        child: SizedBox(
          height: height,
          width: bleed > 0
              ? MediaQuery.sizeOf(context).width
              : null,
          child: BlendMask(
          blendMode: BlendMode.screen,
          child: Image.asset(
            asset,
            height: height,
            width: bleed > 0 ? double.infinity : null,
            fit: bleed > 0 ? BoxFit.cover : BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => Icon(Icons.pets_rounded,
                size: height * 0.4, color: AppColors.emerald400),
            ),
          ),
        ),
      ),
    );
  }
}

/// `———  🐾  ———` under the headline.
class _PawDivider extends StatelessWidget {
  const _PawDivider();

  @override
  Widget build(BuildContext context) {
    Widget rule(List<Color> colors) => Expanded(
          child: Container(
            height: 1,
            constraints: const BoxConstraints(maxWidth: 110),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
            ),
          ),
        );
    const fade = Color(0x00A9B4C4);
    const solid = Color(0x66A9B4C4);
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          rule(const [fade, solid]),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpace.s12),
            child: Icon(Icons.pets_rounded, size: 18, color: AppColors.emerald500),
          ),
          rule(const [solid, fade]),
        ],
      ),
    );
  }
}

/// The four-column glass strip: glyph in a soft disc, title, two-line caption,
/// hairline dividers between columns.
class _FeatureStrip extends StatelessWidget {
  const _FeatureStrip();

  static const _items = <(IconData, String, String)>[
    (Icons.saved_search, 'AI Insights', 'Understand your\npet better'),
    (Icons.shield_outlined, 'Emergency', 'Guidance when\nit matters most'),
    (Icons.notifications_none_rounded, 'Smart Reminders', 'Never miss\nimportant care'),
    (Icons.create_new_folder_outlined, 'Health Diary', 'All records in one\nsecure place'),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: AppSpace.s12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.028),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 86,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            Expanded(
              child: Column(
                children: [
                  // Soft disc behind the glyph, as the reference draws it.
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        AppColors.emerald500.withValues(alpha: 0.16),
                        Colors.transparent,
                      ]),
                    ),
                    child: Icon(_items[i].$1,
                        size: 24, color: AppColors.emerald400),
                  ),
                  const SizedBox(height: AppSpace.s8),
                  Text(_items[i].$2,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: text.labelMedium?.copyWith(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          height: 1.15)),
                  const SizedBox(height: 3),
                  Text(_items[i].$3.replaceAll('\n', ' '),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      style: text.bodySmall?.copyWith(
                          color: const Color(0xFF8C97A8),
                          fontSize: 10,
                          letterSpacing: -0.1,
                          height: 1.25)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
