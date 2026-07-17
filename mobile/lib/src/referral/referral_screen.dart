import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../config/legal_urls.dart';

import '../account/user_profile.dart';
import '../analytics/analytics.dart';
import '../auth/supabase_providers.dart';
import '../core/app_image.dart';
import '../core/app_motion_asset.dart';
import '../core/celebration_overlay.dart';
import '../theme/app_assets.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import 'referral_prefs.dart';
import 'referral_service.dart';

/// Referral code + deep-link generation. Reward payout + fraud controls go live
/// in Phase 3.3; here we generate the code and a shareable link.
String referralCodeFromUid(String uid) {
  final compact = uid.replaceAll('-', '').toUpperCase();
  return compact.isEmpty ? 'PAWDOC' : compact.substring(0, compact.length.clamp(0, 8));
}

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(supabaseClientProvider).auth.currentUser?.id ?? '';
    final code = referralCodeFromUid(uid);
    final link = 'https://pawdoc.app/r/$code';

    return PawBackground(
      variant: PawSurface.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: AppColors.ink50,
          title: const Text(
            'Refer a friend',
            style: TextStyle(
              color: AppColors.ink50,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s20,
              vertical: AppSpace.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Hero section ────────────────────────────────────────────
                _ReferralHero(),
                const SizedBox(height: AppSpace.s20),

                // ── Referral code card ───────────────────────────────────────
                _ReferralCodeCard(code: code),
                const SizedBox(height: AppSpace.s12),

                // ── Share invite link CTA ────────────────────────────────────
                PawPrimaryButton(
                  key: const Key('referral_share'),
                  onPressed: () => SharePlus.instance.share(ShareParams(
                    text: 'Try PawDoc — AI pet health triage in seconds. $link',
                  )),
                  icon: Icons.share_rounded,
                  child: const Text('Share invite link'),
                ),
                const SizedBox(height: AppSpace.s8),

                // ── Link row ─────────────────────────────────────────────────
                _LinkRow(link: link),
                const SizedBox(height: AppSpace.s16),

                // ── OR divider + social row ──────────────────────────────────
                const _OrDivider(),
                const SizedBox(height: AppSpace.s16),
                _SocialRow(link: link, code: code),
                const SizedBox(height: AppSpace.s20),

                // ── Benefits cards (They get / You get) ─────────────────────
                const _BenefitCards(),
                const SizedBox(height: AppSpace.s16),

                // ── How it works row ─────────────────────────────────────────
                const _HowItWorks(),
                const SizedBox(height: AppSpace.s12),

                // Referral program legal terms (no cash value; anti-fraud).
                Center(
                  child: TextButton(
                    onPressed: () => LegalUrls.open(LegalUrls.referrals),
                    child: Text(
                      'Referral terms apply',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.ink300,
                            decoration: TextDecoration.underline,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s8),

                // ── Claim code section ───────────────────────────────────────
                const _ClaimCodeCard(),
                const SizedBox(height: AppSpace.s16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero section ──────────────────────────────────────────────────────────────

class _ReferralHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good for them.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.ink50,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Great for you.',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: PawPalette.mint,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const WidgetSpan(
                      child: Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.favorite_rounded,
                            size: 20, color: PawPalette.heart),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s8),
              Text(
                'Give friends a free start, and earn rewards when they subscribe.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.ink300,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.s12),
        // M1 (A6): gift settles in once (marker), then idles with a tiny
        // wiggle + sparkle orbit; static PNG under reduce-motion.
        AppMotionAsset(
          AppMotionAssets.referralGiftIdle,
          fallbackAsset: AppAssets.referralGift,
          loopFromMarker: 'loop',
          height: 120,
          fallback: AppImage(
            AppAssets.premiumGiftOpen,
            height: 120,
            fallback: const Icon(Icons.card_giftcard_rounded,
                size: 72, color: PawPalette.mint),
          ),
        ),
      ],
    );
  }
}

// ── Referral code card ────────────────────────────────────────────────────────

class _ReferralCodeCard extends StatelessWidget {
  const _ReferralCodeCard({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return PawCard(
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code copied to clipboard')),
        );
      },
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: PawPalette.teal.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.discount_outlined,
                size: 18, color: PawPalette.mint),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your referral code',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.ink300,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  code,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.ink50,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                ),
              ],
            ),
          ),
          const Icon(Icons.copy_rounded, size: 20, color: PawPalette.mint),
        ],
      ),
    );
  }
}

// ── Link row ──────────────────────────────────────────────────────────────────

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link});
  final String link;

  @override
  Widget build(BuildContext context) {
    return PawCard(
      onTap: () {
        Clipboard.setData(ClipboardData(text: link));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied to clipboard')),
        );
      },
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.link_rounded, size: 18, color: PawPalette.mint),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: Text(
              link,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.ink300,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          const Icon(Icons.copy_rounded, size: 16, color: PawPalette.mint),
        ],
      ),
    );
  }
}

// ── OR divider ────────────────────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: AppColors.ink600,
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
          child: Text(
            'OR',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.ink300,
                ),
          ),
        ),
        Expanded(
          child: Divider(
            color: AppColors.ink600,
            thickness: 1,
          ),
        ),
      ],
    );
  }
}

// ── Social share row ──────────────────────────────────────────────────────────

class _SocialRow extends StatelessWidget {
  const _SocialRow({required this.link, required this.code});
  final String link;
  final String code;

  @override
  Widget build(BuildContext context) {
    // Keep existing social share icons as-is — no fabricated brand icons or counts.
    final shareText = 'Try PawDoc — AI pet health triage in seconds. $link';
    final items = <_SocialItem>[
      _SocialItem(
        label: 'WhatsApp',
        icon: Icons.chat_bubble_rounded,
        color: const Color(0xFF25D366),
        onTap: () => SharePlus.instance.share(ShareParams(text: shareText)),
      ),
      _SocialItem(
        label: 'Instagram',
        icon: Icons.camera_alt_rounded,
        color: const Color(0xFFE1306C),
        onTap: () => SharePlus.instance.share(ShareParams(text: shareText)),
      ),
      _SocialItem(
        label: 'Messenger',
        icon: Icons.messenger_rounded,
        color: const Color(0xFF0078FF),
        onTap: () => SharePlus.instance.share(ShareParams(text: shareText)),
      ),
      _SocialItem(
        label: 'Email',
        icon: Icons.email_rounded,
        color: PawPalette.mint,
        onTap: () => SharePlus.instance.share(ShareParams(
          text: shareText,
          subject: 'Join me on PawDoc!',
        )),
      ),
      _SocialItem(
        label: 'More',
        icon: Icons.more_horiz_rounded,
        color: AppColors.ink300,
        onTap: () => SharePlus.instance.share(ShareParams(text: shareText)),
      ),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: items.map((item) {
        return _SocialButton(item: item);
      }).toList(),
    );
  }
}

class _SocialItem {
  const _SocialItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.item});
  final _SocialItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: item.color.withValues(alpha: 0.30),
                width: 1,
              ),
            ),
            child: Icon(item.icon, size: 22, color: item.color),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            item.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.ink300,
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Benefit cards (They get / You get) ───────────────────────────────────────

class _BenefitCards extends StatelessWidget {
  const _BenefitCards();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PawCard(
            padding: const EdgeInsets.all(AppSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: PawPalette.teal.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(Icons.favorite_rounded,
                          size: 16, color: PawPalette.mint),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: Text(
                        'They get',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.ink300,
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s8),
                Text(
                  '3 free health checks',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.ink50,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: PawCard(
            padding: const EdgeInsets.all(AppSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: PawPalette.teal.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(Icons.star_rounded,
                          size: 16, color: PawPalette.mint),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: Text(
                        'You get',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.ink300,
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s8),
                Text(
                  'Amazing rewards',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: PawPalette.mint,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── How it works (3-step process) ────────────────────────────────────────────

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    return PawCard(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        children: [
          Row(
            children: [
              _StepDot(number: '1'),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.mail_outline_rounded,
                        size: 18, color: PawPalette.mint),
                    Text(
                      'Invite',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.ink50,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      'Share your code or link.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.ink300,
                            fontSize: 10,
                          ),
                    ),
                  ],
                ),
              ),
              const _StepArrow(),
              const SizedBox(width: AppSpace.s4),
              _StepDot(number: '2'),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.people_outline_rounded,
                        size: 18, color: PawPalette.mint),
                    Text(
                      'They join',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.ink50,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      'Their friend signs up and subscribes.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.ink300,
                            fontSize: 10,
                          ),
                    ),
                  ],
                ),
              ),
              const _StepArrow(),
              const SizedBox(width: AppSpace.s4),
              _StepDot(number: '3'),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.card_giftcard_rounded,
                        size: 18, color: PawPalette.mint),
                    Text(
                      'You earn',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.ink50,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      'You both get rewards!',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.ink300,
                            fontSize: 10,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.number});
  final String number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: PawPalette.teal,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          number,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: PawPalette.bgBottom,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
        ),
      ),
    );
  }
}

class _StepArrow extends StatelessWidget {
  const _StepArrow();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.chevron_right_rounded,
        size: 16, color: AppColors.ink600);
  }
}

// ── Claim code section ────────────────────────────────────────────────────────

/// "Got a code from a friend?" — enter it to claim the reward. The claim runs
/// entirely server-side (Edge Function + transactional RPC); this only collects
/// the code, shows progress, and reports the outcome.
class _ClaimCodeCard extends ConsumerStatefulWidget {
  const _ClaimCodeCard();

  @override
  ConsumerState<_ClaimCodeCard> createState() => _ClaimCodeCardState();
}

class _ClaimCodeCardState extends ConsumerState<_ClaimCodeCard> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Prefill a code captured from a referral deep link, if any.
    ReferralPrefs.pending().then((code) {
      if (code != null && code.isNotEmpty && mounted && _controller.text.isEmpty) {
        _controller.text = code;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a referral code first.')));
      return;
    }
    setState(() => _busy = true);
    await Analytics.referralCodeSubmitted();
    final result = await ref.read(referralServiceProvider).claim(code);
    if (!mounted) return;
    if (result.ok) {
      await Analytics.referralSuccess();
      ref.invalidate(userProfileProvider); // reflect the new bonus balance
    } else if (result.isFraud) {
      await Analytics.referralFraudPrevented(result.status);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.ok) {
      // M3 (#14): the gift-open reveal replaces the bare snackbar — REAL
      // claim success only; ≤2.2s, tap-skippable, reduce-motion → text.
      await showCelebration(
        context,
        motionAsset: AppMotionAssets.referralGiftOpen,
        fallbackAsset: AppAssets.referralGiftOpen,
        message: result.message,
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PawCard(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.redeem_rounded, size: 18, color: PawPalette.mint),
              const SizedBox(width: AppSpace.s8),
              Text(
                'Got a code from a friend?',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.ink50,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          TextField(
            key: const Key('referral_code_input'),
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: AppColors.ink50),
            decoration: InputDecoration(
              hintText: 'Enter referral code',
              hintStyle:
                  const TextStyle(color: AppColors.ink300),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.10)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: PawPalette.mint),
              ),
              prefixIcon: const Icon(Icons.tag_rounded,
                  size: 18, color: AppColors.ink300),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s16,
                vertical: AppSpace.s12,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s12),
          PawPrimaryButton(
            key: const Key('referral_claim_button'),
            onPressed: _busy ? null : _claim,
            icon: _busy ? null : Icons.redeem_rounded,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: PawPalette.bgBottom))
                : const Text('Claim reward'),
          ),
        ],
      ),
    );
  }
}
