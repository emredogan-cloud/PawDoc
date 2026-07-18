import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../analytics/analytics.dart';
import '../theme/design_tokens.dart';
import '../vet_finder/maps_links.dart';
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
class FirstAidScreen extends StatelessWidget {
  const FirstAidScreen({super.key, required this.topic});
  final FirstAidTopic topic;

  @override
  Widget build(BuildContext context) {
    const red = AppColors.emergencyLight;
    return Scaffold(
      backgroundColor: red,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(topic.title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s20),
          children: [
            Text(topic.subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: AppSpace.s16),
            const Text('Do this now',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpace.s8),
            for (var i = 0; i < topic.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s8),
                child: Text('${i + 1}. ${topic.steps[i]}',
                    style:
                        const TextStyle(color: Colors.white, fontSize: 15)),
              ),
            const SizedBox(height: AppSpace.s12),
            const Text('Never',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpace.s8),
            for (final n in topic.never)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s8),
                child: Text('• $n',
                    style:
                        const TextStyle(color: Colors.white, fontSize: 15)),
              ),
            const SizedBox(height: AppSpace.s16),
            Container(
              padding: const EdgeInsets.all(AppSpace.s12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: AppRadius.brMd,
              ),
              child: const Text(
                'First aid buys time — the veterinarian treats. '
                'Head to a clinic as soon as you can.',
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
