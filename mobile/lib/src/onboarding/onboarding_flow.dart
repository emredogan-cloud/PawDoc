import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../analytics/analytics.dart';
import '../core/living_pet_avatar.dart';
import '../core/motion.dart';
import '../core/pet_display.dart';
import '../pets/pet.dart';
import '../pets/pets_repository.dart';
import '../pets/species_chip.dart';
import '../theme/design_tokens.dart';
import '../theme/ui_assets.dart';
import 'onboarding_ui.dart';

/// The 8-screen onboarding wizard, rebuilt against mockups `002`–`009`.
///
/// **Visual system.** Onboarding is System A — navy canvas, emerald primary,
/// heavy cyan co-accent (UI_ASSET_SPECIFICATION §1.3). It declares that scope
/// itself: the app root is System B, and since the shared accent palette now
/// resolves to lime, an undeclared subtree would render the wrong system.
///
/// **Safety.** Three mockups depict product output that breaks the contract,
/// and the depictions are corrected here rather than reproduced:
///
/// * `003` renders *"No critical signs detected"* inside its sample result —
///   an all-clear, and a terminating reassurance with no action and no
///   timeframe (review V-14).
/// * `005` renders a timeline row reading *"Mild coughing detected"* with a
///   `Low` badge — a finding plus a severity grade (V-14).
/// * `006` has the assistant answer *"Sneezing can be caused by mild
///   irritants, allergies, or infections"* — naming conditions as causes
///   (V-13).
///
/// Each sample now follows the voice of `007`, which the safety review names as
/// the compliant reference: describe the observation, never the cause; always
/// end with an action **and** a timeframe.
///
/// Analytics, pet creation, routing and every widget key are unchanged;
/// `_names` grew with the flow so per-step events stay meaningful.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _pageController = PageController();
  final _name = TextEditingController();
  final _breed = TextEditingController();
  String _species = kSpecies.first;
  DateTime? _birthDate;
  Pet? _createdPet;
  bool _busy = false;
  int _page = 0;

  static const _names = [
    'value_hook',
    'ai_insights',
    'emergency_guidance',
    'health_diary',
    'assistant',
    'pet_setup',
    'activation',
    'welcome',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _name.dispose();
    _breed.dispose();
    super.dispose();
  }

  Future<void> _advance() async {
    await Analytics.onboardingStepCompleted(_page + 1, _names[_page]);
    setState(() => _page += 1);
    await _pageController.animateToPage(
      _page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _submitPetSetup() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your pet’s name.')));
      return;
    }
    setState(() => _busy = true);
    try {
      _createdPet = await ref.read(petsRepositoryProvider).create(
            Pet(
              userId: '',
              name: _name.text.trim(),
              species: _species,
              breed: _breed.text.trim().isEmpty ? null : _breed.text.trim(),
              birthDate: _birthDate,
            ),
          );
      ref.invalidate(petsListProvider);
      await _advance();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save your pet. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    await Analytics.onboardingCompleted();
    if (mounted) context.go('/');
  }

  /// Top-right Skip → home. Routing is unchanged: onboarding is an optional
  /// flow entered from the home empty state, so leaving returns to home (which
  /// re-shows the "set up your pet" prompt if no pet exists).
  void _skip() => context.go('/');

  String get _petName => petDisplayName(_createdPet?.name);

  @override
  Widget build(BuildContext context) {
    return OnbSurface(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              OnbHeader(step: _page, total: _names.length, onSkip: _skip),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _valueHook(),
                    _aiInsights(),
                    _emergency(),
                    _healthDiary(),
                    _assistant(),
                    _petSetup(),
                    _activation(),
                    _welcome(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Every page closes with its CTA and the step counter.
  List<Widget> _footer(Widget cta) => [
        const SizedBox(height: AppSpace.s20),
        cta,
        const SizedBox(height: AppSpace.s12),
        OnbStepLabel(step: _page, total: _names.length),
      ];

  // -------------------------------------------------------------------------
  // 1 · Value hook (mockup 002)
  // -------------------------------------------------------------------------
  Widget _valueHook() => OnbPage(children: [
        const SizedBox(height: AppSpace.s8),
        const OnbHeadline('Every pet deserves', 'calm, informed care.'),
        const SizedBox(height: AppSpace.s12),
        const OnbSubtitle(
            'A calm, clear read on your pet\'s symptoms — in seconds.'),
        const SizedBox(height: AppSpace.s20),
        const Center(child: OnbHero(UiAssets.onbHeroDogCatHalo, height: 250)),
        const SizedBox(height: AppSpace.s20),
        const OnbPanel(
          child: OnbTrustRow(items: [
            (Icons.verified_user_outlined, 'Built on care', 'Guidance, never a diagnosis.'),
            (Icons.lock_outline_rounded, 'Your data is private', 'You choose what to share.'),
            (Icons.support_agent_rounded, 'We\'re here to help', 'Day or night.'),
          ]),
        ),
        ..._footer(OnbCta(
          key: const Key('onb_get_started'),
          label: 'Let\'s Continue',
          onPressed: _advance,
        )),
        const SizedBox(height: AppSpace.s8),
        const OnbFooterNote('Emergency guidance is always free.'),
      ]);

  // -------------------------------------------------------------------------
  // 2 · AI insights (mockup 003)
  // -------------------------------------------------------------------------
  Widget _aiInsights() => OnbPage(children: [
        const SizedBox(height: AppSpace.s8),
        const OnbHeadline('AI insights,', 'real-time clarity.'),
        const SizedBox(height: AppSpace.s12),
        const OnbSubtitle(
            'Describe symptoms or upload a photo. PawDoc helps you understand '
            'how soon to act.'),
        const SizedBox(height: AppSpace.s20),
        // The mockup's sample result reads "Monitor at Home / Low urgency /
        // No critical signs detected" — an all-clear with no action and no
        // timeframe. Rewritten to the compliant voice of `007`.
        const _SamplePhone(
          title: 'AI Health Check',
          disclaimer:
              'This is AI-generated guidance, not a diagnosis. Always consult '
              'your veterinarian.',
          children: [
            _SampleRow(
                label: 'What we observed',
                body: 'An occasional dry cough, no change in appetite or energy.'),
            _SampleRow(
                label: 'What to do',
                body: 'Keep them rested and watch breathing and appetite.'),
            _SampleRow(
                label: 'Timing',
                body:
                    'If it continues past 24–48 hours, or worsens at any point, '
                    'contact your vet.'),
          ],
        ),
        const SizedBox(height: AppSpace.s20),
        const Row(children: [
          Expanded(
              child: OnbFeatureCard(
                  icon: Icons.photo_camera_outlined,
                  title: 'Photo check',
                  caption: 'Share what you can see.')),
          SizedBox(width: AppSpace.s8),
          Expanded(
              child: OnbFeatureCard(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Symptom check',
                  caption: 'Answer a few questions.',
                  color: AppColors.cyan400)),
        ]),
        ..._footer(OnbCta(
          key: const Key('onb_next_emergency'),
          label: 'Next: Emergency guidance',
          onPressed: _advance,
        )),
      ]);

  // -------------------------------------------------------------------------
  // 3 · Emergency (mockup 004)
  // -------------------------------------------------------------------------
  Widget _emergency() => OnbPage(children: [
        const SizedBox(height: AppSpace.s8),
        Center(
            child: OnbGlowIcon(Icons.shield_outlined,
                color: AppColors.cyan300, size: 68)),
        const SizedBox(height: AppSpace.s16),
        const OnbHeadline('When it\'s urgent,', 'PawDoc guides you.'),
        const SizedBox(height: AppSpace.s12),
        const OnbSubtitle(
            'Emergency guidance works offline and is always free — no account '
            'limits, no paywall.'),
        const SizedBox(height: AppSpace.s20),
        Row(children: [
          Expanded(
            child: _CompareCard(
              tint: AppColors.emergencyDark,
              title: 'Emergency',
              subtitle: 'Act now',
              rows: [
                (Icons.monitor_heart_outlined, 'Immediate guidance'),
                (Icons.medical_services_outlined, 'First-aid steps'),
                (Icons.location_on_outlined, 'Find a vet near you'),
              ],
              chip: 'Always free',
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: _CompareCard(
              tint: AppColors.emerald500,
              title: 'Keep watching',
              subtitle: 'With a timeframe',
              rows: [
                (Icons.visibility_outlined, 'What to look for'),
                (Icons.calendar_today_outlined, 'Track changes over time'),
                (Icons.schedule_rounded, 'When to call the vet'),
              ],
              chip: 'Clear next step',
            ),
          ),
        ]),
        const SizedBox(height: AppSpace.s16),
        // Kept verbatim from the mockup — the review calls this framing correct.
        OnbPanel(
          child: Row(children: [
            const OnbGlowIcon(Icons.health_and_safety_outlined, size: 46),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PawDoc does not diagnose.',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.emerald400)),
                  const SizedBox(height: 2),
                  Text(
                    'We provide AI-powered guidance, not a replacement for '
                    'your veterinarian.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFA9B4C4), height: 1.35),
                  ),
                ],
              ),
            ),
          ]),
        ),
        ..._footer(OnbCta(
          key: const Key('onb_next_diary'),
          label: 'Next: Your pet\'s health diary',
          onPressed: _advance,
        )),
      ]);

  // -------------------------------------------------------------------------
  // 4 · Health diary (mockup 005)
  // -------------------------------------------------------------------------
  Widget _healthDiary() => OnbPage(children: [
        const SizedBox(height: AppSpace.s8),
        Center(
            child: OnbGlowIcon(Icons.auto_stories_outlined,
                color: AppColors.cyan400, size: 64)),
        const SizedBox(height: AppSpace.s16),
        const OnbHeadline('All your pet\'s health,', 'in one place.'),
        const SizedBox(height: AppSpace.s12),
        const OnbSubtitle(
            'Checks, vaccines, weight and notes on a single timeline — easy to '
            'track, easy to share with your vet.'),
        const SizedBox(height: AppSpace.s20),
        // The mockup's timeline row reads "Mild coughing detected" with a `Low`
        // badge — a finding plus a severity grade. Reframed as an observation.
        const _SamplePhone(
          title: 'Timeline',
          children: [
            _SampleRow(label: 'Today', body: 'AI check — cough noted, keep watching'),
            _SampleRow(label: 'May 28', body: 'Rabies vaccine — next due May 2026'),
            _SampleRow(label: 'May 20', body: 'Weight — 24.3 kg'),
            _SampleRow(label: 'May 10', body: 'Memory — first beach day'),
          ],
        ),
        const SizedBox(height: AppSpace.s20),
        const OnbPanel(
          child: OnbTrustRow(items: [
            (Icons.lock_outline_rounded, 'Always private', 'Only you can see it.'),
            (Icons.cloud_done_outlined, 'Always safe', 'Backed up securely.'),
            (Icons.ios_share_rounded, 'Easy to share', 'Export for your vet.'),
          ]),
        ),
        ..._footer(OnbCta(
          key: const Key('onb_next_assistant'),
          label: 'Next: Meet your assistant',
          onPressed: _advance,
        )),
      ]);

  // -------------------------------------------------------------------------
  // 5 · Assistant (mockups 006 + 007)
  // -------------------------------------------------------------------------
  Widget _assistant() => OnbPage(children: [
        const SizedBox(height: AppSpace.s8),
        Center(
            child: OnbGlowIcon(Icons.smart_toy_outlined,
                color: AppColors.cyan400, size: 68)),
        const SizedBox(height: AppSpace.s16),
        const OnbHeadline('One assistant.', 'All paws covered.'),
        const SizedBox(height: AppSpace.s12),
        const OnbSubtitle(
            'Ask about anything to do with your pet and get clear, practical '
            'guidance — any time, day or night.'),
        const SizedBox(height: AppSpace.s20),
        // `007` is the safety review's compliant reference: no condition named,
        // no cause asserted, an action and a timeframe. `006`'s reply ("mild
        // irritants, allergies, or infections") is not reproduced.
        const _SamplePhone(
          title: 'PawDoc Assistant',
          question: 'My dog is eating less than usual. Should I be worried?',
          disclaimer:
              'This is AI-generated guidance, not a diagnosis. Always consult '
              'your veterinarian.',
          children: [
            _SampleRow(
                label: '',
                body:
                    'It depends on a few factors. A mild loss of appetite can '
                    'happen for many reasons.'),
            _SampleRow(
                label: 'Things to check',
                body:
                    'Any other symptoms, recent diet or environment changes, '
                    'hydration and energy levels.'),
            _SampleRow(
                label: 'Timing',
                body:
                    'If it continues for more than 24–48 hours or worsens, '
                    'please consult your veterinarian.'),
          ],
        ),
        const SizedBox(height: AppSpace.s20),
        const Row(children: [
          Expanded(
              child: OnbFeatureCard(
                  icon: Icons.pets_rounded,
                  title: 'Pet-aware',
                  caption: 'Remembers your pet\'s details.')),
          SizedBox(width: AppSpace.s8),
          Expanded(
              child: OnbFeatureCard(
                  icon: Icons.verified_user_outlined,
                  title: 'Safe & responsible',
                  caption: 'Educational — never a substitute for a vet.',
                  color: AppColors.cyan400)),
        ]),
        ..._footer(OnbCta(
          key: const Key('onb_next_pet'),
          label: 'Next: Add your first pet',
          onPressed: _advance,
        )),
      ]);

  // -------------------------------------------------------------------------
  // 6 · Add first pet (mockup 008)
  // -------------------------------------------------------------------------
  Widget _petSetup() => OnbPage(children: [
        const SizedBox(height: AppSpace.s8),
        Center(
            child: OnbGlowIcon(Icons.add_circle_outline_rounded,
                color: AppColors.cyan400, size: 62)),
        const SizedBox(height: AppSpace.s16),
        const OnbHeadline('Let\'s add your', 'first furry friend'),
        const SizedBox(height: AppSpace.s12),
        const OnbSubtitle(
            'Adding your pet unlocks personalised reminders and a complete '
            'health diary.'),
        const SizedBox(height: AppSpace.s20),
        Text('What kind of pet are they?',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: const Color(0xFFA9B4C4))),
        const SizedBox(height: AppSpace.s12),
        // Horizontal rail of photo cards, as mockup 008 draws it. Scrolls
        // rather than wrapping so the row reads as one gallery at 320dp.
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kSpecies.length,
            padding: const EdgeInsets.symmetric(vertical: 4),
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s8),
            itemBuilder: (_, i) => SpeciesChip(
              species: kSpecies[i],
              selected: _species == kSpecies[i],
              variant: SpeciesChipVariant.card,
              onTap: () => setState(() => _species = kSpecies[i]),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s20),
        OnbPanel(
          child: Column(children: [
            TextField(
              key: const Key('onb_pet_name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Pet\'s name', filled: true),
            ),
            const SizedBox(height: AppSpace.s16),
            TextField(
              controller: _breed,
              decoration: const InputDecoration(
                  labelText: 'Breed (optional)', filled: true),
            ),
          ]),
        ),
        ..._footer(OnbCta(
          key: const Key('onb_pet_continue'),
          label: _busy ? 'Saving…' : 'Next: Enable smart features',
          busy: _busy,
          onPressed: _busy ? null : _submitPetSetup,
        )),
        const SizedBox(height: AppSpace.s8),
        const OnbFooterNote('Your pet\'s data is private and encrypted.',
            icon: Icons.lock_outline_rounded),
      ]);

  // -------------------------------------------------------------------------
  // 7 · Activation
  // -------------------------------------------------------------------------
  Widget _activation() => OnbPage(children: [
        const SizedBox(height: AppSpace.s24),
        Center(child: _petAvatar()),
        const SizedBox(height: AppSpace.s20),
        OnbHeadline('Ready to check on', '$_petName?'),
        const SizedBox(height: AppSpace.s12),
        const OnbSubtitle('Symptom checks are free — no card, no limit.'),
        const SizedBox(height: AppSpace.s24),
        const OnbPanel(
          child: OnbTrustRow(items: [
            (Icons.bolt_rounded, 'Text checks', 'Always free.'),
            (Icons.notifications_none_rounded, 'Reminders', 'Asked for only when you add one.'),
            (Icons.health_and_safety_outlined, 'Emergency', 'Never paywalled.'),
          ]),
        ),
        ..._footer(OnbCta(
          key: const Key('onb_activation_continue'),
          label: 'Continue',
          onPressed: _advance,
        )),
      ]);

  // -------------------------------------------------------------------------
  // 8 · Welcome (mockup 009)
  // -------------------------------------------------------------------------
  Widget _welcome() => OnbPage(children: [
        const SizedBox(height: AppSpace.s16),
        Center(
            child: OnbGlowIcon(Icons.check_circle_outline_rounded,
                color: AppColors.emerald400, size: 78)),
        const SizedBox(height: AppSpace.s16),
        const OnbHeadline('You\'re all set,', 'welcome to PawDoc!'),
        const SizedBox(height: AppSpace.s12),
        const OnbSubtitle(
            'Everything you need to care better, track smarter, and be there '
            'when it matters most.'),
        const SizedBox(height: AppSpace.s20),
        const Center(child: OnbHero(UiAssets.onbHeroDogKittenCelebration, height: 210)),
        const SizedBox(height: AppSpace.s20),
        Text('Here\'s what you can do now',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: const Color(0xFFA9B4C4))),
        const SizedBox(height: AppSpace.s12),
        const Row(children: [
          Expanded(
              child: OnbFeatureCard(
                  icon: Icons.auto_stories_outlined,
                  title: 'Health diary',
                  caption: 'Track every moment.')),
          SizedBox(width: AppSpace.s8),
          Expanded(
              child: OnbFeatureCard(
                  icon: Icons.smart_toy_outlined,
                  title: 'Assistant',
                  caption: 'Guidance, anytime.',
                  color: AppColors.cyan400)),
        ]),
        const SizedBox(height: AppSpace.s8),
        const Row(children: [
          Expanded(
              child: OnbFeatureCard(
                  icon: Icons.notifications_none_rounded,
                  title: 'Reminders',
                  caption: 'Vaccines, meds, checkups.',
                  color: AppColors.cyan400)),
          SizedBox(width: AppSpace.s8),
          Expanded(
              child: OnbFeatureCard(
                  icon: Icons.ios_share_rounded,
                  title: 'Share & export',
                  caption: 'Reports for your vet.')),
        ]),
        ..._footer(OnbCta(
          key: const Key('onb_finish'),
          label: 'Start my journey',
          trailing: Icons.arrow_forward_rounded,
          onPressed: _finish,
        )),
        const SizedBox(height: AppSpace.s8),
        const OnbFooterNote('We never sell your data. Ever.',
            icon: Icons.lock_outline_rounded),
      ]);

  Widget _petAvatar() {
    final key = _createdPet?.species ?? 'other';
    // The first emotional moment — the species Paw Pal arrives, does one happy
    // beat, then idles. Reduce-motion renders the static species art.
    final avatar = LivingPetAvatar(
      species: key,
      size: 108,
      seed: _createdPet?.id,
      photoKey: _createdPet?.photoKey,
      mountBeat: PalBeat.happy,
    );
    if (reduceMotion(context)) return avatar;
    return avatar
        .animate()
        .scaleXY(
            begin: 0.8,
            end: 1.0,
            duration: AppMotion.hero,
            curve: Curves.easeOutBack)
        .then(delay: const Duration(milliseconds: 80))
        .shimmer(
            duration: const Duration(milliseconds: 900),
            color: AppColors.emerald400);
  }
}

// ---------------------------------------------------------------------------
// Page-local building blocks
// ---------------------------------------------------------------------------

/// A device-framed preview of product output.
///
/// Drawn rather than composited over the `onb-device-iphone-frame` raster: the
/// frame is a rounded rectangle and a notch, and drawing it keeps the sample
/// copy live text — which matters, because this copy is safety-relevant and
/// must stay translatable and screen-reader accessible rather than baked into
/// an image.
class _SamplePhone extends StatelessWidget {
  const _SamplePhone({
    required this.title,
    required this.children,
    this.question,
    this.disclaimer,
  });

  final String title;
  final String? question;
  final List<_SampleRow> children;
  final String? disclaimer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1220),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 2),
        boxShadow: [
          BoxShadow(
              color: AppColors.cyan400.withValues(alpha: 0.10),
              blurRadius: 26,
              spreadRadius: -6),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.s12),
        decoration: BoxDecoration(
          color: const Color(0xFF070E19),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 54,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpace.s12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(children: [
              const OnbGlowIcon(Icons.pets_rounded,
                  color: AppColors.emerald400, size: 26),
              const SizedBox(width: AppSpace.s8),
              Text(title,
                  style: text.titleSmall?.copyWith(color: Colors.white)),
            ]),
            const SizedBox(height: AppSpace.s12),
            if (question != null) ...[
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s12, vertical: AppSpace.s8),
                  decoration: BoxDecoration(
                    color: AppColors.emerald500.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(question!,
                      style: text.bodySmall
                          ?.copyWith(color: Colors.white, height: 1.35)),
                ),
              ),
              const SizedBox(height: AppSpace.s8),
            ],
            ...children,
            if (disclaimer != null) ...[
              const SizedBox(height: AppSpace.s8),
              Container(
                padding: const EdgeInsets.all(AppSpace.s8),
                decoration: BoxDecoration(
                  color: AppColors.emerald500.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.emerald500.withValues(alpha: 0.30)),
                ),
                child: Row(children: [
                  const Icon(Icons.verified_user_outlined,
                      size: 14, color: AppColors.emerald400),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(disclaimer!,
                        style: text.bodySmall?.copyWith(
                            color: const Color(0xFFBFE8CB),
                            fontSize: 11,
                            height: 1.3)),
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SampleRow extends StatelessWidget {
  const _SampleRow({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            Text(label,
                style: text.labelMedium?.copyWith(
                    color: AppColors.cyan300, fontWeight: FontWeight.w600)),
          Text(body,
              style: text.bodySmall
                  ?.copyWith(color: const Color(0xFFD3DBE6), height: 1.4)),
        ],
      ),
    );
  }
}

/// The two side-by-side cards on `004`.
class _CompareCard extends StatelessWidget {
  const _CompareCard({
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.rows,
    required this.chip,
  });

  final Color tint;
  final String title;
  final String subtitle;
  final List<(IconData, String)> rows;
  final String chip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleSmall?.copyWith(color: Colors.white)),
          Text(subtitle, style: text.bodySmall?.copyWith(color: tint)),
          const SizedBox(height: AppSpace.s12),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(r.$1, size: 16, color: tint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(r.$2,
                      style: text.bodySmall?.copyWith(
                          color: const Color(0xFFD3DBE6), height: 1.3)),
                ),
              ]),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(chip,
                textAlign: TextAlign.center,
                style: text.labelMedium?.copyWith(color: tint)),
          ),
        ],
      ),
    );
  }
}
