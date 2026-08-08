import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../health/health_sections.dart';
import '../theme/design_tokens.dart';
import 'emergency_sections.dart';
import 'first_aid.dart';
import 'first_aid_guide_screen.dart';

/// The RED BUTTON target (evolution Phase 3 / C1): offline, instant, zero AI.
/// Rebuilt against mockup `emergency_hub`.
///
/// This screen must work with no network, no backend, and no model: an OS
/// maps deep link, a tap-to-dial poison-control number, and bundled first-aid
/// cards. It is reachable in one tap from home and routed to instantly by the
/// client-side keyword router.
///
/// NEVER add monetization, affiliates, upsells, paywalls, quota, or any
/// AI-driven content to this screen. Its contents are exactly: help contacts,
/// first aid, and the honesty note. (See CLAUDE.md — emergency-path rule.)
///
/// **It is a `StatelessWidget` that reads no provider, and that is a
/// guarantee, not an accident.** `emergency_router_test` pumps it with no
/// `ProviderScope` at all; if it ever grows a dependency on app state, that
/// test stops compiling, which is the point. It is also why the mockup's
/// bottom navigation is the one piece of its chrome this screen does not
/// adopt — `PawNavBar` is a `ConsumerWidget`, and a tab bar is not worth
/// trading the proof for. `first_aid_guide`, a browse surface, carries it.
///
/// **What the reference draws that this screen does not.** Six blocks, five of
/// them ruled out by the emergency-path rule and one by a deleted feature:
///
///  * **"AI Triage · Check symptoms now"** in Quick Actions — review item
///    V-16, CRITICAL. The one screen that must work offline cannot lead with
///    a control that needs a model.
///  * **"At Risk Pets · 1 · Luna · ⚠ Needs Attention · Based on recent
///    symptoms (Vomiting, Loss of appetite) · [View Triage]"** — a graded
///    assessment of a named animal, which the contract forbids anywhere, on
///    the surface where it would be read hardest. V-16 proposes a relabelled
///    version ("Recently logged · Symptoms logged 2 days ago"); that is a
///    change to what this screen may contain, so it is an owner decision in
///    the shape of D-7, not something to fold in quietly. It would also need
///    an offline story — the row is a database read.
///  * **"Emergency Transport · Request help"** — PawDoc has no transport
///    partner. There is nothing behind this tile in any tier.
///  * **"Share Records · Send health info instantly"** — the PDF export is
///    premium-gated (`pdf_entitlement_test`). A premium-gated tile on the red
///    path is a paywall on the red path.
///  * **"Nearest 24/7 Vet Clinics"** with a map, photographs, star ratings,
///    review counts, drive times and 24/7 badges. The Places-backed vet finder
///    was deleted in PR #80 in favour of the OS maps hand-off, so every one of
///    those values would be fabricated — and "24/7" fabricated about a clinic
///    is the one that gets an owner driving to a locked door.
///  * **"Heat Alert in Your Area"** — a pushed environmental alert says the
///    app is watching. It is not, and this screen least of all.
///
/// And **"Available 24/7"** under the call button: PawDoc runs no staffed
/// line. What it has is somebody else's poison-control number, with a fee,
/// and a hand-off to the maps app.
class EmergencyHelpScreen extends StatelessWidget {
  const EmergencyHelpScreen({super.key, this.matchedKeyword});

  /// Set when the client keyword router sent the user here (shown so the user
  /// understands why the app escalated).
  final String? matchedKeyword;

  void _openGuide(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FirstAidGuideScreen()),
    );
  }

  void _openTopic(BuildContext context, FirstAidTopic topic) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => FirstAidScreen(topic: topic)),
    );
  }

  void _showAbout(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const HealthSheet(
        title: 'What this screen is',
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4, 2, 4, 14),
            child: Text(
              'Two ways to reach help, and first-aid steps to follow while you '
              'get there. All of it is stored in the app: it opens with no '
              'signal, no account and no AI.\n\n'
              'PawDoc does not run an emergency line, does not know which '
              'clinics near you are open, and cannot tell you what is wrong '
              'with your pet. It can only get you to someone who can.\n\n'
              'If you are unsure, treat it as an emergency.',
              style: TextStyle(
                  color: HealthTone.muted, fontSize: 13.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topics = orderedFirstAidTopics();
    return HealthRecordScaffold(
      appBar: PetModuleAppBar(
        title: 'Emergency Hub',
        icon: LucideIcons.shieldAlert,
        subtitle: 'Help, and what to do while you get there.',
        actionsWidth: 96,
        actions: [
          HealthActionPill(
            key: const Key('emergency_about'),
            label: 'About',
            icon: LucideIcons.info,
            onTap: () => _showAbout(context),
          ),
        ],
      ),
      children: [
        if (matchedKeyword != null) ...[
          gap(2),
          Container(
            key: const Key('emergency_matched_banner'),
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
            decoration: BoxDecoration(
              color: AppColors.emergencyDark.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.emergencyDark.withValues(alpha: 0.45)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.triangleAlert,
                    size: 17, color: AppColors.emergencyDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'What you described ("$matchedKeyword") can be an '
                    'emergency.',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13.5, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
        gap(2),
        const EmergencyCallBand(
          title: 'In an emergency?',
          subtitle: 'Act now — don’t wait on an app.',
        ),
        gap(18),
        const HealthSectionHead(title: 'Quick actions'),
        gap(9),
        Row(
          children: [
            Expanded(
              child: _QuickTile(
                tileKey: const Key('emergency_tile_firstaid'),
                icon: LucideIcons.briefcaseMedical,
                title: 'Pet First Aid',
                subtitle: 'Step-by-step guides',
                onTap: () => _openGuide(context),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _QuickTile(
                tileKey: const Key('emergency_tile_vet'),
                icon: LucideIcons.mapPin,
                title: 'Find a vet',
                subtitle: 'Opens your maps app',
                onTap: openEmergencyVetMaps,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _QuickTile(
                tileKey: const Key('emergency_tile_poison'),
                icon: LucideIcons.phoneCall,
                title: 'Poison control',
                subtitle: 'Tap to dial',
                onTap: dialPoisonControl,
              ),
            ),
          ],
        ),
        gap(18),
        HealthSectionHead(
          title: 'First aid while you get help',
          actionLabel: 'Search',
          actionBoxed: true,
          actionIcon: LucideIcons.search,
          onAction: () => _openGuide(context),
        ),
        gap(8),
        Container(
          decoration: BoxDecoration(
            color: HealthTone.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 2),
          child: Column(
            children: [
              for (var i = 0; i < topics.length; i++)
                FirstAidRow(
                  topic: topics[i],
                  showDivider: i != topics.length - 1,
                  onTap: () => _openTopic(context, topics[i]),
                ),
            ],
          ),
        ),
        gap(14),
        const EmergencyHonestyNote(),
        gap(6),
      ],
    );
  }
}

/// One tile in the Quick Actions row. The reference draws five in a scrolling
/// rail; three of its five had nothing behind them, so three remain and the
/// row fits without scrolling.
class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.tileKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Key tileKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.lime500;
    return Material(
      color: HealthTone.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: tileKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 118,
          padding: const EdgeInsets.fromLTRB(9, 12, 9, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                  border:
                      Border.all(color: accent.withValues(alpha: 0.40)),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(height: 9),
              // Inside a fixed-height tile a Text reports its unwrapped
              // height, so the two label slots are sized explicitly rather
              // than left to overflow the box on a long word.
              SizedBox(
                height: 17,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 3),
              Expanded(
                child: Text(subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: HealthTone.muted, fontSize: 10.5, height: 1.3)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One bundled first-aid card. Static content; readable offline.
///
/// Restyled onto System B alongside `first_aid_guide`, which pushes it: a
/// near-black guide that opens a full-red card reads as two different apps,
/// and the red now means one thing on these screens — the call band.
class FirstAidScreen extends StatelessWidget {
  const FirstAidScreen({super.key, required this.topic});
  final FirstAidTopic topic;

  @override
  Widget build(BuildContext context) {
    const red = AppColors.emergencyDark;
    final glyph = firstAidGlyph(topic.id);
    return HealthRecordScaffold(
      appBar: PetModuleAppBar(
        title: topic.title,
        icon: LucideIcons.shieldPlus,
        subtitle: 'Do this while you get to a veterinarian.',
      ),
      children: [
        gap(2),
        Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
          decoration: BoxDecoration(
            color: HealthTone.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: red.withValues(alpha: 0.30)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (glyph != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(glyph,
                      width: 44, height: 44, fit: BoxFit.cover),
                )
              else
                HealthGlyphDisc(
                    icon: firstAidRailIcon(topic.id),
                    tint: red,
                    size: 44,
                    square: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('What it looks like',
                        style: TextStyle(
                            color: red,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(topic.subtitle,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        ),
        gap(16),
        const HealthSectionHead(title: 'Do this now'),
        gap(8),
        Container(
          padding: const EdgeInsets.fromLTRB(13, 4, 13, 4),
          decoration: BoxDecoration(
            color: HealthTone.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < topic.steps.length; i++)
                _Step(index: i + 1, text: topic.steps[i]),
            ],
          ),
        ),
        gap(16),
        const HealthSectionHead(title: 'Never'),
        gap(8),
        Container(
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
          decoration: BoxDecoration(
            color: red.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: red.withValues(alpha: 0.30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final n in topic.never)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child:
                            Icon(LucideIcons.circleX, size: 15, color: red),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(n,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                height: 1.4)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        gap(14),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: HealthTone.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: const Text(
            'First aid buys time — the veterinarian treats. '
            'Head to a clinic as soon as you can.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: HealthTone.muted, fontSize: 12.5, height: 1.4),
          ),
        ),
        gap(12),
        const EmergencyCallBand(),
        gap(6),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.lime500.withValues(alpha: 0.14),
              border: Border.all(
                  color: AppColors.lime500.withValues(alpha: 0.45)),
            ),
            child: Text('$index',
                style: const TextStyle(
                    color: AppColors.lime500,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13.5, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

/// The permanent home-screen red button (one tap to [EmergencyHelpScreen]).
/// Deliberately quiet in styling but always present and first-tap reachable.
class EmergencyHelpButton extends StatelessWidget {
  const EmergencyHelpButton({super.key});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('home_emergency_button'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.emergencyLight,
        side: const BorderSide(color: AppColors.emergencyLight, width: 1.4),
        minimumSize: const Size.fromHeight(48),
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const EmergencyHelpScreen()),
      ),
      icon: const Icon(Icons.emergency_rounded),
      label: const Text('Emergency? Get help now'),
    );
  }
}
