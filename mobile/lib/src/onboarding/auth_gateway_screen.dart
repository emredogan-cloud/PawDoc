import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../auth/auth_controller.dart';
import '../router/app_router.dart';
import '../auth/google_sign_in_diagnosis.dart';

import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/ui_assets.dart';
import 'onboarding_ui.dart';

/// Authentication gateway — mockup `000`.
///
/// Shown *after* onboarding, not as part of it: onboarding sells the product,
/// this screen asks how the user wants in. Three ways out — Google, email, or
/// continue as a guest.
///
/// The hero is flanked by four floating capability cards, as the mockup draws
/// them. They are positioned against the hero rather than laid out in a column,
/// because their overlap with the artwork is the composition.
class AuthGatewayScreen extends StatelessWidget {
  const AuthGatewayScreen({
    required this.onGoogle,
    required this.onEmail,
    required this.onGuest,
    this.busy = false,
    super.key,
  });

  final VoidCallback onGoogle;
  final VoidCallback onEmail;
  final VoidCallback onGuest;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return OnbSurface(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                _Screened(UiAssets.onbLogoPawdoc, height: 120),
                const SizedBox(height: 2),

                // The mockup sets this headline in caps — it is the brand
                // statement, not body copy.
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: 'AI PET HEALTH.\n',
                      style: text.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -0.5),
                    ),
                    TextSpan(
                      text: 'IN YOUR POCKET.',
                      style: text.displaySmall?.copyWith(
                          color: AppColors.emerald400,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -0.5),
                    ),
                  ]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpace.s12),
                const OnbSubtitle(
                    'AI-powered health tracking, smart insights, and emergency '
                    'guidance for your pets.'),

                const SizedBox(height: AppSpace.s8),
                const _HeroWithCards(),

                const SizedBox(height: AppSpace.s16),
                const _SocialProof(),

                const SizedBox(height: AppSpace.s20),
                OnbCta(
                  key: const Key('gateway_get_started'),
                  label: 'Get Started',
                  busy: busy,
                  onPressed: busy ? null : onGuest,
                ),
                const SizedBox(height: AppSpace.s12),
                _ProviderButton(
                  key: const Key('gateway_google'),
                  label: 'Continue with Google',
                  leading: const _GoogleMark(),
                  onTap: busy ? null : onGoogle,
                ),
                const SizedBox(height: AppSpace.s12),
                _ProviderButton(
                  key: const Key('gateway_email'),
                  label: 'Continue with Email',
                  leading: const Icon(Icons.mail_outline_rounded,
                      size: 22, color: Colors.white),
                  onTap: busy ? null : onEmail,
                ),

                const SizedBox(height: AppSpace.s16),
                const OnbFooterNote(
                    'Your pet\'s health. Your data. Always safe.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero photo with the four capability cards floating over its corners.
class _HeroWithCards extends StatelessWidget {
  const _HeroWithCards();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Orbit rings behind the subject.
          const Positioned.fill(
            child: ExcludeSemantics(child: CustomPaint(painter: _OrbitPainter())),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: OnbHero(UiAssets.onbHeroDogKittenCutout, height: 340),
          ),
          // Shield badge sitting over the pets, as the mockup composes it.
          const Positioned(
            bottom: 66,
            child: _ShieldBadge(),
          ),
          const Positioned(
            left: 0,
            top: 34,
            child: _FloatCard(
                icon: Icons.psychology_outlined,
                title: 'AI Insights',
                caption: 'Smart health\nanalysis'),
          ),
          const Positioned(
            right: 0,
            top: 84,
            child: _FloatCard(
                icon: Icons.add_box_outlined,
                title: 'Emergency\nGuide',
                caption: 'Always here\nwhen needed',
                tint: AppColors.emerald400),
          ),
          const Positioned(
            left: 0,
            bottom: 74,
            child: _FloatCard(
                icon: Icons.menu_book_outlined,
                title: 'Health Diary',
                caption: 'Track history\nwith ease',
                tint: AppColors.cyan300),
          ),
          const Positioned(
            right: 0,
            bottom: 40,
            child: _FloatCard(
                icon: Icons.notifications_none_rounded,
                title: 'Reminders',
                caption: 'Never miss\nimportant care',
                tint: AppColors.cyan400),
          ),
        ],
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.52);
    for (final (rx, ry, col, w) in [
      (size.width * 0.40, size.height * 0.30, AppColors.emerald500, 2.0),
      (size.width * 0.34, size.height * 0.36, AppColors.cyan400, 1.4),
    ]) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-0.28);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..color = col.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShieldBadge extends StatelessWidget {
  const _ShieldBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 104,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.cyan300.withValues(alpha: 0.55),
            AppColors.cyan400.withValues(alpha: 0.25),
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(18),
          bottom: Radius.circular(46),
        ),
        border: Border.all(color: AppColors.cyan300.withValues(alpha: 0.9), width: 2),
        boxShadow: [
          BoxShadow(
              color: AppColors.cyan400.withValues(alpha: 0.45),
              blurRadius: 26,
              spreadRadius: -4),
        ],
      ),
      child: const Icon(Icons.pets_rounded, size: 44, color: Colors.white),
    );
  }
}

class _FloatCard extends StatelessWidget {
  const _FloatCard({
    required this.icon,
    required this.title,
    required this.caption,
    this.tint = AppColors.emerald400,
  });

  final IconData icon;
  final String title;
  final String caption;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: 108,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1120).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 26, color: tint),
          const SizedBox(height: 6),
          Text(title,
              textAlign: TextAlign.center,
              style: text.labelMedium?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w700, height: 1.15)),
          const SizedBox(height: 2),
          Text(caption,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(
                  color: const Color(0xFF9AA6B6), fontSize: 10.5, height: 1.2)),
        ],
      ),
    );
  }
}

/// `[avatars]  Trusted by pet parents  ★★★★★  10K+ Happy Pets`
class _SocialProof extends StatelessWidget {
  const _SocialProof();

  static const _avatars = [
    UiAssets.avtSocialProof01,
    UiAssets.avtSocialProof02,
    UiAssets.avtSocialProof03,
    UiAssets.avtSocialProof04,
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26.0 * _avatars.length + 8,
            height: 34,
            child: Stack(
              children: [
                for (var i = 0; i < _avatars.length; i++)
                  Positioned(
                    left: i * 22.0,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.navy900, width: 2),
                      ),
                      child: ClipOval(
                        child: Image.asset(_avatars[i],
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                            errorBuilder: (_, _, _) => const ColoredBox(
                                color: Color(0xFF243044))),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: Text('Trusted by pet parents',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: const Color(0xFFC8D2DE))),
          ),
          const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFC233)),
          const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFC233)),
          const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFC233)),
          const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFC233)),
          const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFC233)),
        ],
      ),
    );
  }
}

/// Outlined provider button — Google / email.
class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.leading,
    required this.onTap,
    super.key,
  });

  final String label;
  final Widget leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Material(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  leading,
                  const SizedBox(width: AppSpace.s12),
                  Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Google's four-colour "G".
///
/// Drawn, not AI-generated: the mark is a registered trademark
/// (UI_ASSET_SPECIFICATION §1.7, `TPB-1701`). This is a faithful geometric
/// rendering in the official brand colours; if the brand kit asset is added
/// later it drops straight in here.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => const SizedBox(
      width: 22, height: 22, child: CustomPaint(painter: _GooglePainter()));
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final rect = Rect.fromCircle(center: c, radius: r * 0.86);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.46
      ..strokeCap = StrokeCap.butt;

    void arc(double from, double sweep, Color col) {
      canvas.drawArc(rect, from, sweep, false, p..color = col);
    }

    arc(-0.35, -1.25, const Color(0xFFEA4335)); // red
    arc(-1.60, -1.35, const Color(0xFFFBBC05)); // yellow
    arc(1.55, 1.30, const Color(0xFF34A853)); // green
    arc(-0.35, 0.95, const Color(0xFF4285F4)); // blue

    // The blue crossbar into the centre.
    canvas.drawRect(
      Rect.fromLTWH(c.dx, c.dy - r * 0.19, r * 0.92, r * 0.38),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Screened extends StatelessWidget {
  const _Screened(this.asset, {required this.height});

  final String asset;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: Center(
          child: BlendMask(
            blendMode: BlendMode.screen,
            child: Image.asset(asset,
                height: height,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink()),
          ),
        ),
      );
}

/// Live wiring for [AuthGatewayScreen].
///
/// Kept separate so the presentation widget stays a pure, testable
/// stateless screen with three callbacks.
class AuthGatewayScreen2 extends ConsumerStatefulWidget {
  const AuthGatewayScreen2({super.key});

  @override
  ConsumerState<AuthGatewayScreen2> createState() => _AuthGatewayScreen2State();
}

class _AuthGatewayScreen2State extends ConsumerState<AuthGatewayScreen2> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Reaching the gateway ends the first-run journey, however the user got
    // here — so a returning signed-out user lands straight on this screen
    // instead of replaying eight onboarding pages.
    FirstRun.markDone();
  }

  Future<void> _run(Future<void> Function() action, String failure) async {
    setState(() => _busy = true);
    try {
      await action();
      // The router's auth listener redirects to `/` on success.
    } on GoogleSignInException catch (e) {
      // Mirrors sign_in_screen: a configuration failure is not something a
      // second tap fixes, so say what actually went wrong.
      if (mounted) {
        _snack(diagnoseGoogleSignIn(
          code: e.code.name,
          description: e.description,
        ).userMessage);
      }
    } catch (e) {
      // Backing out of the Google sheet is a choice, not an error.
      if (identical(e, AuthController.googleCancelled)) return;
      if (mounted) _snack(failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return AuthGatewayScreen(
      busy: _busy,
      onGoogle: () =>
          _run(ref.read(authControllerProvider).signInWithGoogle,
              'Could not sign in with Google. Please try again.'),
      onEmail: () => context.go('/sign-in'),
      onGuest: () => _run(ref.read(authControllerProvider).continueAsGuest,
          'Could not start a guest session. Please try again.'),
    );
  }
}
