import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../account/user_profile.dart';
import '../core/paw_nav_bar.dart';
import '../health/health_sections.dart';
import '../home/home_sections.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'entitlements.dart';
import 'paywall_screen.dart';
import 'premium_sections.dart';
import 'usage_limits_screen.dart';

/// `upgrade_benefits`, rebuilt against its reference.
///
/// The reference's comparison table is a good idea wrapped around ten rows,
/// **six of which are not true**. It sells access to "verified veterinarians",
/// grades free storage at "Limit: 1 GB" against "Unlimited", offers "Advanced
/// Analytics", "Priority" support from a "care team", "Export & Share Data" as
/// a premium unlock (it is free, and always has been), and caps free accounts
/// at "1 Pet" against "Up to 15 Pets" — PawDoc has never limited pets on any
/// plan.
///
/// The shape survives; the rows come from [kEntitlements], where every line is
/// traceable to the code that enforces it.
///
/// | Reference row | Shipped | Why |
/// |---|---|---|
/// | "Vet Chat Priority · Get faster responses from verified veterinarians" | *(gone)* | no veterinarian is employed, contracted or verified |
/// | "Unlimited Cloud Storage · Free: Limit 1 GB" | "Photo & file storage · Not metered" on both plans | no layer counts bytes |
/// | "Multi-Pet Management · Free: 1 Pet · Premium: Up to 15 Pets" | "Pets · Unlimited" on both plans | no pet limit exists |
/// | "Advanced Analytics" | *(gone)* | there is no analytics capability in either plan |
/// | "Dedicated Support · Standard vs Priority" | *(gone)* | there is one support channel, and no tier |
/// | "Export & Share Data · Free: ✗" | "Share the record as text · Included" both | the text export has never been gated |
/// | "Community & Nearby Owners · Free: Limited · Premium: Full Access" | "Opt-in" on both | no plan buys reach or ranking |
/// | "Cancel anytime · No hidden fees / 7-Day Money-Back Guarantee" | "Cancel anytime in Google Play" | refunds are Google's, on Google's terms |
/// | "Join thousands of pet parents who trust PawDoc Premium." | *(gone)* | pre-launch; there are no thousands |
class UpgradeBenefitsScreen extends ConsumerWidget {
  const UpgradeBenefitsScreen({super.key});

  static const _reasons = <({IconData icon, String title, String body})>[
    (
      icon: LucideIcons.infinity,
      title: 'No ceiling',
      body: 'Photo checks, journal entries and assistant messages stop '
          'being counted.',
    ),
    (
      icon: LucideIcons.fileText,
      title: 'A file for the vet',
      body: 'The PDF report is built on the server and handed straight to '
          'your share sheet.',
    ),
    (
      icon: LucideIcons.shieldCheck,
      title: 'Safety stays free',
      body: 'Emergency help and text checks are unmetered for everyone. '
          'Subscriptions are what pay for that.',
    ),
    (
      icon: LucideIcons.lockKeyhole,
      title: 'No ads, ever',
      body: 'PawDoc is paid for by subscriptions, not by advertising or by '
          'selling your data.',
    ),
  ];

  void _openPlans(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const PaywallScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(userProfileProvider).maybeWhen(
        data: (p) => p.isPremium, orElse: () => false);

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: const PetModuleAppBar(
          title: 'Upgrade Benefits',
          icon: LucideIcons.crown,
          subtitle: 'What Premium changes, and what it does not.',
        ),
        bottomNav: const PawNavBar(detached: true),
        children: [
          gap(4),
          PremiumHeroCard(
            headline: 'Keep the whole record.\n',
            headlineAccent: 'Without limits.',
            deck: 'Unlimited photo checks, an unlimited journal, unlimited '
                'assistant messages, and the PDF report a vet can read.',
            chips: const [
              (
                icon: LucideIcons.repeat,
                title: 'Cancel anytime',
                body: 'Managed in Google Play',
              ),
              (
                icon: LucideIcons.circleAlert,
                title: 'Emergency stays free',
                body: 'On every plan, always',
              ),
            ],
          ),
          gap(13),
          const EntitlementCompareTable(entitlements: kEntitlements),
          gap(13),
          _ReasonGrid(reasons: _reasons),
          gap(13),
          _UnaffectedCard(onUsage: () {
            Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const UsageLimitsScreen()));
          }),
          gap(13),
          if (!isPremium)
            PremiumBand(
              key: const Key('benefits_upgrade_band'),
              title: 'Ready to lift the limits?',
              body: 'One plan, everything included. No tiers, no add-ons, '
                  'nothing sold separately.',
              ctaLabel: 'See plans & pricing',
              onCta: () => _openPlans(context),
              footnote: 'Billing and cancellation are handled by Google Play.',
            )
          else
            const _AlreadyPremiumCard(),
          gap(13),
          const PremiumHonestyNote(lines: [
            'PawDoc employs no veterinarians and offers no chat with one. '
                'Nothing here connects you to a professional.',
            'There is no free trial unless Google Play offers one on the '
                'product, and no money-back guarantee of PawDoc’s own.',
            'No storage figure appears above because no storage quota is '
                'applied on either plan.',
          ]),
          gap(18),
        ],
      ),
    );
  }
}

/// The reference's "Why upgrade to Premium?" four-up.
///
/// Drawn as 2×2 rather than 4-across: at 393dp the reference gives each tile
/// 88dp for a title and three lines of body, which is four characters a line.
class _ReasonGrid extends StatelessWidget {
  const _ReasonGrid({required this.reasons});

  final List<({IconData icon, String title, String body})> reasons;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Why upgrade?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 11),
          for (var r = 0; r < reasons.length; r += 2) ...[
            if (r > 0) const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _ReasonTile(reason: reasons[r])),
                  const SizedBox(width: 10),
                  Expanded(
                    child: r + 1 < reasons.length
                        ? _ReasonTile(reason: reasons[r + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({required this.reason});

  final ({IconData icon, String title, String body}) reason;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 12, 11, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.022),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(reason.icon, size: 21, color: t.accent),
          const SizedBox(height: 9),
          Text(reason.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  height: 1.2,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(reason.body,
              style: const TextStyle(
                  color: HealthTone.dim, fontSize: 10.5, height: 1.35)),
        ],
      ),
    );
  }
}

/// The counterweight the reference has no room for: what an upgrade does
/// **not** change. It matters commercially — an owner who buys expecting a
/// veterinarian is a refund and a one-star review — and it matters more than
/// that if they buy expecting one in an emergency.
class _UnaffectedCard extends StatelessWidget {
  const _UnaffectedCard({required this.onUsage});

  final VoidCallback onUsage;

  static const _rows = <({IconData icon, String label, String value})>[
    (
      icon: LucideIcons.stethoscope,
      label: 'You are not buying a vet',
      value: 'No plan connects you to a veterinarian. PawDoc organises what '
          'you record and tells you when to call one.',
    ),
    (
      icon: LucideIcons.circleAlert,
      label: 'Emergency does not change',
      value: 'The red path is identical on both plans: offline, model-free '
          'and never metered.',
    ),
    (
      icon: LucideIcons.brain,
      label: 'The AI does not change',
      value: 'Premium lifts how many checks you can run. It does not buy a '
          'different model, a deeper analysis or a diagnosis.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      key: const Key('benefits_unaffected'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HealthSectionHead(
            title: 'What Premium does not change',
            actionLabel: 'Your usage',
            actionIcon: LucideIcons.gauge,
            actionBoxed: true,
            onAction: onUsage,
          ),
          const SizedBox(height: 4),
          for (final r in _rows)
            HealthDetailRow(icon: r.icon, label: r.label, value: r.value),
        ],
      ),
    );
  }
}

class _AlreadyPremiumCard extends StatelessWidget {
  const _AlreadyPremiumCard();

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      key: const Key('benefits_already_premium'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(13, 14, 13, 14),
      accent: t.accent.withValues(alpha: 0.26),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumCrest(size: 38),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('You already have all of this',
                    style: TextStyle(
                        color: t.accent,
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                const Text(
                    'Premium is active on this account. Nothing above is '
                    'locked, and nothing is counted.',
                    style: TextStyle(
                        color: HealthTone.dim, fontSize: 11, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
