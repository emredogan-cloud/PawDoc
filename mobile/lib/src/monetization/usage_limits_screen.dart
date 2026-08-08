import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../account/user_profile.dart';
import '../config/legal_urls.dart';
import '../core/dates.dart';
import '../core/paw_nav_bar.dart';
import '../health/health_sections.dart';
import '../home/home_sections.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'entitlements.dart';
import 'paywall_screen.dart';
import 'premium_sections.dart';
import 'subscription_state.dart';
import 'usage_state.dart';

/// `usage_limits`, rebuilt against its reference.
///
/// **The reference draws seven meters; four of them count nothing.** It fills
/// a 70% bar for *"Cloud Storage 0.7 / 1 GB used · 307 MB left"* against a
/// quota no layer implements, prints *"Vet Chat · 2 / 3 used · Chat with
/// verified veterinarians"* for a service that does not exist, meters
/// *"Multi-Pet Profiles 1 / 2"* where PawDoc has never limited pets, and locks
/// *"Advanced Analytics 0 / 2"* behind a plan that has no analytics product.
///
/// What ships counts what is genuinely counted — the photo-check meter the
/// server enforces, the journal allowance, today's assistant messages — and
/// says outright, in the same row shape, when something is not metered. See
/// [buildUsageMeters]; the arithmetic is pure and unit-tested.
///
/// | Reference | Shipped | Why |
/// |---|---|---|
/// | "Cloud Storage · 0.7 / 1 GB used · 307 MB left" | "Photo & file storage · NOT METERED" | nothing counts bytes; neither the limit nor the usage exists |
/// | "Vet Chat · 2 / 3 used · Chat with verified veterinarians" | *(gone)* | there is no veterinarian to chat to |
/// | "Multi-Pet Profiles · 1 / 2 pets · 1 left" | "Pets · N · No limit applies" | pets have never been limited on any plan |
/// | "Advanced Analytics · 0 / 2 · Locked" | *(gone)* | no analytics capability exists in either plan |
/// | "AI Health Insights · 3 / 5 per month" | "Photo health checks · N / 5 per month" | the meter is photos, not "insights"; text checks are never metered |
/// | "Reset in 31 days" on every row | the real reset date per row, or none | the journal allowance is a total and never resets; storage has no window |
/// | "31 days left" billing-cycle chip | the photo-check reset, or the store's renewal date | there is no billing cycle for a free account |
/// | "7-day money-back guarantee" | *(gone)* | PawDoc runs no refund programme; refunds are Google's |
/// | "Contact our support team — we're here to help!" | a link to the published contact page | no support tier, no response-time promise |
class UsageLimitsScreen extends ConsumerStatefulWidget {
  const UsageLimitsScreen({super.key, this.initialTab = UsageTab.usage});

  final UsageTab initialTab;

  @override
  ConsumerState<UsageLimitsScreen> createState() => _UsageLimitsScreenState();
}

/// The reference's two segments.
enum UsageTab { usage, comparison }

class _UsageLimitsScreenState extends ConsumerState<UsageLimitsScreen> {
  late UsageTab _tab = widget.initialTab;

  void _openPlans() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const PaywallScreen()));
  }

  void _explain() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const HealthSheet(
        title: 'How these meters work',
        scrollable: true,
        children: [
          HealthDetailRow(
            icon: LucideIcons.shieldCheck,
            label: 'Safety is never counted',
            value: 'Emergency help and symptom checks by text are unmetered '
                'on every plan. Only photo checks draw on an allowance.',
          ),
          HealthDetailRow(
            icon: LucideIcons.server,
            label: 'The server keeps the count',
            value: 'The photo allowance is enforced before any model runs, so '
                'what you see here is the same number the check itself uses.',
          ),
          HealthDetailRow(
            icon: LucideIcons.circleSlash,
            label: 'A row with no bar has no meter',
            value: 'Where PawDoc does not count something, it says so rather '
                'than drawing a number it does not have.',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final usage = ref.watch(accountUsageProvider);
    final isPremium =
        profile.maybeWhen(data: (p) => p.isPremium, orElse: () => false);

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          title: 'Usage & Limits',
          icon: LucideIcons.gauge,
          subtitleLead: 'What you have used',
          subtitle: ', and what your plan includes.',
          actions: [
            HealthCircleButton(
              key: const Key('usage_help'),
              icon: LucideIcons.circleHelp,
              tooltip: 'How these meters work',
              onTap: _explain,
            ),
          ],
        ),
        bottomNav: const PawNavBar(detached: true),
        children: [
          gap(4),
          if (isPremium)
            _PremiumPlanBanner(onManage: _openPlans)
          else
            PremiumHeroCard(
              headline: 'You are on the ',
              headlineAccent: 'free plan',
              deck: 'Emergency help and text symptom checks are unlimited '
                  'here — always. Premium lifts the photo, journal and '
                  'assistant allowances and adds the PDF report.',
              ctaLabel: 'See Premium plans',
              onCta: _openPlans,
              footnote: 'Cancel anytime in Google Play.',
            ),
          gap(13),
          _SegmentedTabs(
            tab: _tab,
            onChanged: (t) => setState(() => _tab = t),
          ),
          gap(13),
          if (_tab == UsageTab.comparison) ...[
            EntitlementCompareTable(
              entitlements: kEntitlements,
              title: 'Free and Premium',
            ),
            gap(13),
          ] else ...[
            _CycleStrip(isPremium: isPremium),
            gap(9),
            profile.when(
              data: (p) => usage.when(
                data: (u) => _MeterCard(
                  meters: buildUsageMeters(
                    isPremium: p.isPremium,
                    photoChecksUsed: p.photoLogsUsedThisMonth,
                    photoChecksResetAt: p.photoLogsResetAt,
                    journalEntries: u.journalEntries,
                    assistantMessagesToday: u.assistantMessagesToday,
                    petCount: u.petCount,
                  ),
                  onUpgrade: _openPlans,
                ),
                loading: () => const _MeterPlaceholder(
                    message: 'Counting what you have used…'),
                error: (_, _) => _MeterPlaceholder(
                  message: 'Your usage could not be read just now.',
                  onRetry: () => ref.invalidate(accountUsageProvider),
                ),
              ),
              loading: () => const _MeterPlaceholder(
                  message: 'Reading your plan…'),
              error: (_, _) => _MeterPlaceholder(
                message: 'Your plan could not be read just now.',
                onRetry: () => ref.invalidate(userProfileProvider),
              ),
            ),
            gap(13),
          ],
          if (!isPremium) ...[
            PremiumBand(
              key: const Key('usage_upgrade_band'),
              title: 'Lift the allowances',
              body: 'Unlimited photo checks, unlimited journal entries, '
                  'unlimited assistant messages and the PDF health report.',
              ctaLabel: 'See plans & pricing',
              onCta: _openPlans,
              footnote: 'Billing is handled by Google Play. '
                  'Emergency help stays free on every plan.',
            ),
            gap(13),
          ],
          PremiumFaq(
            title: 'Questions about limits',
            items: const [
              (
                question: 'What happens when I reach a limit?',
                answer: 'The capability that hit its allowance stops until it '
                    'resets or you upgrade. Nothing else changes: emergency '
                    'help, symptom checks by text, your records, your '
                    'reminders and everything you have already saved stay '
                    'exactly as they are.',
              ),
              (
                question: 'Is my data affected?',
                answer: 'No. Allowances govern how much new work you can '
                    'start, never what is already stored. Nothing is deleted '
                    'when a meter runs out.',
              ),
              (
                question: 'Can an allowance block an emergency?',
                answer: 'No — by design. Emergency help never touches a '
                    'model, a network call or a meter, and symptom checks by '
                    'text are unmetered on every plan. Only photo checks are '
                    'counted, and that gate runs before anything else.',
              ),
              (
                question: 'When does the photo allowance reset?',
                answer: 'At the start of each month, on the server. The date '
                    'shown on the photo row is the one the check itself '
                    'uses — the app does not keep a second count.',
              ),
            ],
          ),
          gap(11),
          HealthDangerCard(
            key: const Key('usage_contact'),
            icon: LucideIcons.messageCircle,
            title: 'Something not adding up?',
            body: 'The contact page lists how to reach us.',
            onTap: () => LegalUrls.open(LegalUrls.contact),
          ),
          gap(11),
          const PremiumHonestyNote(lines: [
            'No storage quota is applied today, so there is no gigabyte '
                'figure to show you — used or included.',
            'Pets, records and reminders have never been limited on any plan.',
            'A count that could not be read says so; it is never shown as '
                'zero.',
          ]),
          gap(18),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// The reference's two-segment control.
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.tab, required this.onChanged});

  final UsageTab tab;
  final ValueChanged<UsageTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              fieldKey: const Key('usage_tab_usage'),
              icon: LucideIcons.chartPie,
              label: 'My usage',
              selected: tab == UsageTab.usage,
              onTap: () => onChanged(UsageTab.usage),
            ),
          ),
          Expanded(
            child: _Segment(
              fieldKey: const Key('usage_tab_comparison'),
              icon: LucideIcons.crown,
              label: 'Plan comparison',
              selected: tab == UsageTab.comparison,
              onTap: () => onChanged(UsageTab.comparison),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.fieldKey,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key fieldKey;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? t.accent.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            key: fieldKey,
            onTap: onTap,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                    color: selected
                        ? t.accent.withValues(alpha: 0.55)
                        : Colors.transparent),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: 15,
                      color: selected ? t.accent : HealthTone.muted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: selected ? t.accent : HealthTone.muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The reference's "Billing cycle · May 24 – Jun 24 · 31 days left" strip.
///
/// A free account has no billing cycle, so the strip carries the only window
/// that genuinely applies to it — when the photo allowance rolls over. A
/// premium account gets the store's own renewal date, and says "access until"
/// rather than "renews" once a cancellation has been detected.
class _CycleStrip extends ConsumerWidget {
  const _CycleStrip({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = PawTone.of(context);
    final (label, trailing) = isPremium
        ? _premiumLine(ref)
        : _freeLine(ref.watch(userProfileProvider).asData?.value);
    return Row(
      children: [
        Icon(LucideIcons.calendar, size: 14, color: t.accent),
        const SizedBox(width: 7),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: HealthTone.muted, fontSize: 11.5, height: 1.3)),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          PremiumChip(label: trailing),
        ],
      ],
    );
  }

  (String, String?) _freeLine(UserProfile? profile) {
    final resetAt = profile?.photoLogsResetAt;
    if (resetAt == null) {
      return ('Photo checks roll over at the start of each month.', null);
    }
    final days = resetAt.difference(DateTime.now()).inDays;
    return (
      'Photo checks reset ${shortDate(resetAt)}',
      days >= 0 ? '${days + 1} days left' : null,
    );
  }

  (String, String?) _premiumLine(WidgetRef ref) {
    final snap = ref.watch(subscriptionSnapshotProvider).asData?.value;
    if (snap == null || !snap.readable) {
      return ('Your plan could not be read from the store just now.', null);
    }
    if (!snap.active) {
      return ('No active store subscription is attached to this device.', null);
    }
    final at = snap.renewsAt;
    if (at == null) return ('Premium is active on this account.', null);
    return (
      snap.willRenew
          ? 'Renews ${shortDate(at)}'
          : 'Access until ${shortDate(at)}',
      snap.inTrial ? 'TRIAL' : null,
    );
  }
}

class _MeterCard extends StatelessWidget {
  const _MeterCard({required this.meters, required this.onUpgrade});

  final List<UsageMeter> meters;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      key: const Key('usage_meters'),
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < meters.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.06)),
            UsageMeterRow(
              key: Key('usage_meter_${meters[i].id}'),
              meter: meters[i],
              onUpgrade: onUpgrade,
            ),
          ],
        ],
      ),
    );
  }
}

class _MeterPlaceholder extends StatelessWidget {
  const _MeterPlaceholder({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
      child: Column(
        children: [
          Icon(onRetry == null ? LucideIcons.gauge : LucideIcons.wifiOff,
              size: 24, color: HealthTone.muted),
          const SizedBox(height: 9),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: HealthTone.dim, fontSize: 12, height: 1.35)),
          if (onRetry != null) ...[
            const SizedBox(height: 11),
            HealthActionPill(
                label: 'Try again',
                icon: LucideIcons.refreshCw,
                onTap: onRetry!),
          ],
        ],
      ),
    );
  }
}

/// What a paying account sees in the hero's place.
class _PremiumPlanBanner extends ConsumerWidget {
  const _PremiumPlanBanner({required this.onManage});

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = PawTone.of(context);
    final snap = ref.watch(subscriptionSnapshotProvider).asData?.value;
    final plan = snap?.planLabel;
    return HomeCard(
      key: const Key('usage_premium_banner'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
      accent: t.accent.withValues(alpha: 0.28),
      glow: 0.08,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumCrest(size: 40),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Premium is active',
                    style: TextStyle(
                        color: t.accent,
                        fontSize: 14.5,
                        height: 1.2,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                    plan == null
                        ? 'Photo checks, journal entries and assistant '
                            'messages are unlimited on this account.'
                        : '$plan plan. Photo checks, journal entries and '
                            'assistant messages are unlimited.',
                    style: const TextStyle(
                        color: HealthTone.dim, fontSize: 11, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
