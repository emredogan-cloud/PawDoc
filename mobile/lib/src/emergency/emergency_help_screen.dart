import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../analytics/analytics.dart';
import '../health/health_sections.dart';
import '../theme/design_tokens.dart';
import '../vet_finder/maps_links.dart';
import 'emergency_sections.dart';
import 'first_aid.dart';

/// The RED BUTTON target (evolution Phase 3 / C1): offline, instant, zero AI.
///
/// This screen must work with no network, no backend, and no model: an OS
/// maps deep link, a tap-to-dial poison-control number, and bundled first-aid
/// cards. It is reachable in one tap from home and routed to instantly by the
/// client-side keyword router.
///
/// NEVER add monetization, affiliates, upsells, paywalls, quota, or any
/// AI-driven content to this screen. Its contents are exactly: help contacts,
/// first aid, and the honesty note. (See CLAUDE.md — emergency-path rule.)
class EmergencyHelpScreen extends StatelessWidget {
  const EmergencyHelpScreen({super.key, this.matchedKeyword});

  /// Set when the client keyword router sent the user here (shown so the user
  /// understands why the app escalated).
  final String? matchedKeyword;

  static const _poisonControlLabel = 'ASPCA Animal Poison Control (US)';
  static const _poisonControlNumber = '+18884264435'; // (888) 426-4435

  Future<void> _dialPoisonControl() async {
    await Analytics.vetCalled();
    await launchUrl(Uri.parse('tel:$_poisonControlNumber'));
  }

  Future<void> _openMaps() async {
    await Analytics.vetFinderOpened();
    await launchUrl(emergencyVetSearchMapsUri(),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    const red = AppColors.emergencyLight;
    return Scaffold(
      backgroundColor: red,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Emergency help',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s20),
          children: [
            if (matchedKeyword != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpace.s12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: AppRadius.brMd,
                ),
                child: Text(
                  'What you described ("$matchedKeyword") can be an emergency.',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpace.s16),
            ],
            const Text(
              'If your pet is in danger, act now — don’t wait on an app.',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.s20),
            FilledButton.icon(
              key: const Key('help_find_vet'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: red,
                shape: const StadiumBorder(),
                minimumSize: const Size.fromHeight(56),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              onPressed: _openMaps,
              icon: const Icon(Icons.local_hospital),
              label: const Text('Find an emergency vet now'),
            ),
            const SizedBox(height: AppSpace.s12),
            FilledButton.icon(
              key: const Key('help_poison_control'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: red,
                shape: const StadiumBorder(),
                minimumSize: const Size.fromHeight(56),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              onPressed: _dialPoisonControl,
              icon: const Icon(Icons.phone_in_talk_rounded),
              label: const Text('Call poison control'),
            ),
            const SizedBox(height: AppSpace.s4),
            const Text(
              '$_poisonControlLabel — a consultation fee may apply.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.s24),
            const Text(
              'First aid while you get help',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpace.s8),
            for (final t in kFirstAidTopics)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s8),
                child: Material(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brMd,
                  child: ListTile(
                    key: Key('first_aid_${t.id}'),
                    shape:
                        RoundedRectangleBorder(borderRadius: AppRadius.brMd),
                    title: Text(t.title,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: Text(t.subtitle,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: Colors.white),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => FirstAidScreen(topic: t))),
                  ),
                ),
              ),
            const SizedBox(height: AppSpace.s16),
            Container(
              padding: const EdgeInsets.all(AppSpace.s12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: AppRadius.brMd,
              ),
              child: const Text(
                'First aid buys time — it never replaces a veterinarian. '
                'This screen works offline and involves no AI.',
                style: TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
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
