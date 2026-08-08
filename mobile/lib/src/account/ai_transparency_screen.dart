import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/legal_urls.dart';
import '../core/paw_nav_bar.dart';
import '../emergency/emergency_help_screen.dart';
import '../health/health_sections.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import 'account_sections.dart';
import 'privacy_security_screen.dart';

/// `ai_transparency`, rebuilt against its reference.
///
/// The reference is the most dangerous plate in the whole set. It is a *trust*
/// screen, which means every sentence on it is one a worried owner will rely
/// on — and it asserts, four separate times, a veterinary review that does not
/// happen:
///
/// > "Advanced AI, **Vet-Verified** — Built with advanced AI models and
/// > reviewed by veterinary professionals."
/// > Step 3 of 4: "**Vet-Reviewed** — Veterinary experts review and validate
/// > AI-generated insights and content."
/// > "Vet Knowledge Base — **Vet-reviewed** medical content and guidelines ·
/// > Used to ensure accurate information."
///
/// **No veterinarian reviews any PawDoc output.** None is employed, contracted
/// or consulted; nothing in the pipeline routes to a human at all. Shipping
/// that claim would sell a licensed opinion that does not exist — the same
/// invention `entitlements.dart` refuses for "verified veterinarians", except
/// here it would be attached to the output itself rather than to a plan.
///
/// It also claims "Your data is encrypted and **never used to train AI
/// models**" and an "End-to-end Encryption" badge. PawDoc is not end-to-end
/// encrypted — the server decrypts every photo to moderate and analyse it — and
/// what a model provider does with an API payload is their contractual
/// commitment to make, on a page that binds them, not a chip in this app.
///
/// So this screen describes the pipeline that actually runs. Every claim below
/// is traceable to a file:
///
/// | Statement | Enforced by |
/// |---|---|
/// | Emergency words are checked before any model runs | `pipeline.py` step 2, `safety.py`, mirrored client-side in `emergency_keywords.dart` |
/// | Two models, escalating | `config.py` `TIER2_MODEL` / `TIER3_MODEL` |
/// | Temperature 0.1 on every health call | `config.py` `ANALYSIS_TEMPERATURE` |
/// | Structured output only, off-schema is rejected | `models.py` `parse_analysis_result` |
/// | Low certainty returns "not enough information" | `config.py` `CONFIDENCE_FLOOR = 0.60` |
/// | Always an action and a timeframe | contract v2, `invariant_no_dead_ends_test` |
/// | The disclaimer is forced server-side | `pipeline.py` step 7 |
/// | Images are moderated, failing closed | `moderation.py` |
/// | What the model receives | `prompts.py` `_pet_profile_lines` |
///
/// It never names the app's own confidence value, never grades severity and
/// never states a condition — the same rules the result screens ship under.
class AiTransparencyScreen extends ConsumerWidget {
  const AiTransparencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          title: 'AI Transparency',
          icon: LucideIcons.sparkles,
          subtitle: 'What PawDoc AI does, and what it ',
          subtitleTrail: 'cannot do.',
          actionsWidth: 56,
          actions: [
            HealthCircleButton(
              key: const Key('ai_transparency_policy'),
              icon: LucideIcons.fileText,
              tooltip: 'Published AI transparency page',
              onTap: () => LegalUrls.open(LegalUrls.aiTransparency),
            ),
          ],
        ),
        bottomNav: const PawNavBar(detached: true),
        children: [
          gap(6),
          const _Hero(),
          gap(12),
          const _DisclaimerBand(),
          gap(16),
          const _HowItWorks(),
          gap(16),
          const _WhatItSees(),
          gap(16),
          const _Guardrails(),
          gap(16),
          const _Limits(),
          gap(16),
          const _NeverClaims(),
          gap(14),
          const _WhenToSeeAVet(),
          gap(10),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) => const AccountHero(
        icon: LucideIcons.sparkles,
        title: 'A second look — not a ',
        highlight: 'second opinion',
        body: 'PawDoc AI reads what you describe and what you photograph, and '
            'helps you decide what to do next. It does not examine your pet, '
            'and it never tells you what is wrong with them.',
        assurances: [
          AccountAssurance(
              icon: LucideIcons.shieldCheck, label: 'Safety runs first'),
          AccountAssurance(
              icon: LucideIcons.listChecks, label: 'Always an action'),
          AccountAssurance(
              icon: LucideIcons.stethoscope, label: 'Never a diagnosis'),
        ],
      );
}

/// The pinned disclaimer. Same sentence the result screens render when the
/// server sets `disclaimer_required`, quoted here as the standing statement.
class _DisclaimerBand extends StatelessWidget {
  const _DisclaimerBand();

  @override
  Widget build(BuildContext context) {
    final emergency = AppColors.emergency(Theme.of(context).brightness);
    return Container(
      key: const Key('ai_transparency_disclaimer'),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: emergency.withValues(alpha: 0.06),
        border: Border.all(color: emergency.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.triangleAlert, size: 20, color: emergency),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('PawDoc does not replace a veterinarian',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        height: 1.25,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 3),
                Text(
                    'PawDoc provides information, not a veterinary diagnosis. '
                    'When in doubt, contact your vet.',
                    style: TextStyle(
                        color: AccountTone.dim, fontSize: 11.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The reference's four-step flow, with its third step replaced.
///
/// Its steps are: You Share → AI Analyzes → **Vet-Reviewed** → You Get
/// Insights. The third does not happen. The step that genuinely sits between
/// input and output — and the one worth telling a user about — is the emergency
/// override, which runs *before* the model rather than after it.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(3, 0, 3, 8),
          child: Text('What happens when you run a check',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w700)),
        ),
        AccountStepFlow(
          key: const Key('ai_transparency_steps'),
          steps: [
            const AccountStep(
              icon: LucideIcons.penLine,
              title: 'You describe what you are seeing',
              body: 'Your words, and a photo or video if you added one. '
                  'Photos have their EXIF and GPS data stripped on your phone '
                  'before they are uploaded.',
            ),
            AccountStep(
              icon: LucideIcons.shieldAlert,
              title: 'Emergency words are checked first',
              body: 'Before any model is called — and again on your own device '
                  'so it works with no signal — your text is matched against a '
                  'fixed list of emergency signs. A match goes straight to '
                  'emergency help. No model can talk you out of that.',
              tint: AppColors.emergency(Theme.of(context).brightness),
            ),
            const AccountStep(
              icon: LucideIcons.cpu,
              title: 'A model reads it',
              body: 'gemini-2.0-flash reads it first; anything it is not clear '
                  'on is escalated to claude-sonnet-4-6. Both run at '
                  'temperature 0.1 and must answer in a fixed structure — an '
                  'answer that does not fit is rejected rather than shown.',
            ),
            const AccountStep(
              icon: LucideIcons.listChecks,
              title: 'You get an action and a timeframe',
              // Careful with this sentence: `safety_copy_test` bans the
              // reassurance vocabulary outright, and the first draft of this
              // line tripped it by quoting the phrase it was rejecting.
              body: 'What was observed, what to watch for, what to do, and by '
                  'when. Every result ends on an action and a timeframe — the '
                  'ladder has no "do nothing" rung, because that is not '
                  'something PawDoc can responsibly say about an animal it '
                  'cannot examine.',
            ),
          ],
        ),
      ],
    );
  }
}

/// The reference's "What Data We Use", corrected.
///
/// It lists "Your Data", a "Vet Knowledge Base — vet-reviewed medical content"
/// and "Usage Data", and closes on a band reading "Your data stays yours · We
/// never sell your data. Ever." with End-to-end Encryption / No AI Model
/// Training / No Data Selling badges. There is no vet-reviewed knowledge base;
/// the model's veterinary knowledge is whatever it was trained on, which is
/// exactly the thing a user should know.
class _WhatItSees extends StatelessWidget {
  const _WhatItSees();

  @override
  Widget build(BuildContext context) {
    return const AccountGroup(
      key: Key('ai_transparency_inputs'),
      title: 'What the model actually receives',
      caption: 'A check sends these and nothing else.',
      children: [
        AccountFactRow(
          icon: LucideIcons.penLine,
          title: 'What you wrote',
          subtitle: 'The description you typed for this check.',
          value: 'Sent',
          positive: true,
        ),
        AccountFactRow(
          icon: LucideIcons.camera,
          title: 'The photo or video',
          subtitle: 'If you added one. Location and camera metadata are '
              'removed on your phone first.',
          value: 'Sent',
          positive: true,
        ),
        AccountFactRow(
          icon: LucideIcons.pawPrint,
          title: 'Your pet’s facts',
          subtitle: 'Species, breed, age, sex and weight — the things that '
              'change what a sign means. Not your pet’s name.',
          value: 'Sent',
          positive: true,
        ),
        AccountFactRow(
          icon: LucideIcons.history,
          title: 'Recent entries',
          subtitle: 'A short summary of the last 30 days of checks and records '
              'for this pet, as background — never as fact.',
          value: 'Sent',
          positive: true,
        ),
        AccountFactRow(
          icon: LucideIcons.userRound,
          title: 'Anything about you',
          subtitle: 'Who you are plays no part in a check. Your name, your '
              'email address, your location and your account never leave with '
              'it.',
          value: 'Never sent',
          positive: false,
        ),
      ],
    );
  }
}

/// The rules the pipeline enforces, in the order it enforces them.
class _Guardrails extends StatelessWidget {
  const _Guardrails();

  @override
  Widget build(BuildContext context) {
    return const AccountGroup(
      key: Key('ai_transparency_guardrails'),
      title: 'The rules it runs under',
      children: [
        AccountFactRow(
          icon: LucideIcons.shieldAlert,
          title: 'Emergency signs bypass the model entirely',
          subtitle: 'The keyword list lives in three places — the server, the '
              'edge and your phone — and a test fails the build if they ever '
              'disagree.',
          value: 'Always',
          positive: true,
        ),
        AccountFactRow(
          icon: LucideIcons.circleHelp,
          title: 'Unsure means unsure',
          subtitle: 'When the model is not confident enough, PawDoc returns '
              '"not enough information" and asks for a clearer photo or more '
              'detail. It does not guess and it does not fill the gap.',
          value: 'Always',
          positive: true,
        ),
        AccountFactRow(
          icon: LucideIcons.ban,
          title: 'It never names a condition',
          subtitle: 'A result describes what can be observed. Naming a disease '
              'from a photo is a diagnosis, and diagnosing is a vet’s job.',
          value: 'Never',
          positive: false,
        ),
        AccountFactRow(
          icon: LucideIcons.gauge,
          title: 'No score, no severity, no percentage',
          subtitle: 'PawDoc never shows a certainty figure or grades how bad '
              'something is. A number would imply a precision this cannot have.',
          value: 'Never',
          positive: false,
        ),
        AccountFactRow(
          icon: LucideIcons.eyeOff,
          title: 'Uploaded images are screened',
          subtitle: 'Every image is checked before analysis, and a check that '
              'cannot be screened is refused rather than passed through.',
          value: 'Always',
          positive: true,
        ),
      ],
    );
  }
}

class _Limits extends StatelessWidget {
  const _Limits();

  @override
  Widget build(BuildContext context) {
    return const AccountGroup(
      key: Key('ai_transparency_limits'),
      title: 'What it cannot do',
      caption: 'The honest version of the limits, not a footnote.',
      children: [
        AccountFactRow(
          icon: LucideIcons.stethoscope,
          title: 'It cannot examine your pet',
          subtitle: 'No temperature, no heartbeat, no abdomen, no bloods, no '
              'imaging. A photograph is a fraction of what a vet uses in the '
              'first thirty seconds of a consultation.',
        ),
        AccountFactRow(
          icon: LucideIcons.circleAlert,
          title: 'It can be wrong',
          subtitle: 'It can miss something serious and it can flag something '
              'harmless. If your instinct says something is wrong, act on your '
              'instinct, not on this app.',
        ),
        AccountFactRow(
          icon: LucideIcons.clock,
          title: 'It is a snapshot, not monitoring',
          subtitle: 'PawDoc only looks when you ask it to. Nothing watches '
              'your pet between checks, and no alert will arrive if something '
              'changes.',
        ),
        AccountFactRow(
          icon: LucideIcons.pill,
          title: 'It will not tell you what to give',
          subtitle: 'No medicine, no dose, no treatment. Many things that are '
              'safe for people are toxic to animals, and the dose is the whole '
              'question.',
        ),
      ],
    );
  }
}

/// The claims this screen deliberately refuses to make.
///
/// Stating them as absences is stronger than omitting them: a user who has seen
/// "vet-reviewed AI" advertised elsewhere gets a direct answer here rather than
/// having to infer one from silence.
class _NeverClaims extends StatelessWidget {
  const _NeverClaims();

  @override
  Widget build(BuildContext context) {
    return const AccountGroup(
      key: Key('ai_transparency_never'),
      title: 'What PawDoc does not claim',
      children: [
        AccountFactRow(
          icon: LucideIcons.userRoundX,
          title: 'No veterinarian reviews these results',
          // Deliberately does not quote the marketing phrase it is denying.
          // `settings_screens_test`'s claim scan reads what a user reads, and
          // a rendered string cannot carry its own context — someone skimming
          // this row would take the quoted phrase for the claim.
          subtitle: 'No vet is employed, contracted or consulted by PawDoc, and '
              'nothing you send is seen by one. No professional has checked '
              'any answer this app gives you.',
          value: 'Not reviewed',
          positive: false,
        ),
        AccountFactRow(
          icon: LucideIcons.badgeX,
          title: 'It is not a medical device',
          // Says this without using the phrase it is denying: the source-level
          // scan in `settings_claims_test` reads string literals, and cannot
          // tell a rejection from an assertion.
          subtitle: 'No regulator or veterinary body has certified or cleared '
              'PawDoc, and no clinical study stands behind it.',
          value: 'Not certified',
          positive: false,
        ),
        AccountFactRow(
          icon: LucideIcons.lockOpen,
          title: 'PawDoc can read what you upload',
          subtitle: 'Connections use HTTPS and your records are scoped to your '
              'account, but a photo has to be readable by the service in order '
              'to be analysed at all. No app that looks at your images can '
              'also be sealed from them.',
          value: 'Be aware',
          positive: false,
        ),
      ],
    );
  }
}

class _WhenToSeeAVet extends StatelessWidget {
  const _WhenToSeeAVet();

  @override
  Widget build(BuildContext context) {
    return AccountCallout(
      icon: LucideIcons.circleAlert,
      title: 'When not to use this at all',
      body: 'Collapse, seizures, trouble breathing, a swollen or hard belly, '
          'bleeding that will not stop, a suspected poisoning, or a pet in '
          'obvious pain: stop and call a vet now. Do not run a check first.',
      actions: [
        HealthActionPill(
          key: const Key('ai_transparency_emergency'),
          label: 'Emergency help',
          icon: LucideIcons.chevronRight,
          color: AppColors.emergency(Theme.of(context).brightness),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const EmergencyHelpScreen())),
        ),
        HealthActionPill(
          key: const Key('ai_transparency_privacy'),
          label: 'Privacy & security',
          icon: LucideIcons.chevronRight,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const PrivacySecurityScreen())),
        ),
        HealthActionPill(
          key: const Key('ai_transparency_disclaimer_link'),
          label: 'Veterinary disclaimer',
          icon: LucideIcons.externalLink,
          onTap: () => LegalUrls.open(LegalUrls.vetDisclaimer),
        ),
      ],
    );
  }
}
