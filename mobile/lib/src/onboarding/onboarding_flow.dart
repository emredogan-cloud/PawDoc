import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../analytics/analytics.dart';
import '../core/living_pet_avatar.dart';
import '../core/motion.dart';
import '../core/pet_display.dart';
import '../pets/pet.dart';
import '../pets/pets_repository.dart';
import '../pets/species_chip.dart';
import '../theme/design_tokens.dart';
import '../theme/ui_assets.dart';
import 'onboarding_stages.dart';
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
        const SizedBox(height: AppSpace.s4),
        const OnbHeadline('Every pet deserves', 'calm, informed care.'),
        const SizedBox(height: AppSpace.s12),
        const OnbSubtitle(
            'PawDoc helps you understand your pet\'s health and make the best '
            'decisions, together.'),

        // Hero stage: the pets sit whole and uncropped, with the cyan ribbon
        // sweeping behind them and a labelled glyph on each side — the
        // composition the reference builds, not just the photo.
        const SizedBox(height: AppSpace.s8),
        const _ValueHeroStage(),

        // Shield badge overlapping the top edge of the trust card.
        const SizedBox(height: AppSpace.s20),
        const _TrustCard(),

        ..._footer(OnbCta(
          key: const Key('onb_get_started'),
          label: 'Let\'s Continue',
          onPressed: _advance,
        )),
        const SizedBox(height: AppSpace.s8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.verified_user_outlined,
              size: 16, color: AppColors.emerald500),
          const SizedBox(width: 6),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: 'Always ',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: const Color(0xFF8C97A8))),
              TextSpan(
                  text: 'free',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.emerald400,
                      fontWeight: FontWeight.w700)),
              TextSpan(
                  text: ' emergency guidance.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: const Color(0xFF8C97A8))),
            ]),
          ),
        ]),
      ]);

  // -------------------------------------------------------------------------
  // 2 · AI insights (mockup 003)
  // -------------------------------------------------------------------------
  Widget _aiInsights() => OnbPage(children: [
        const SizedBox(height: AppSpace.s4),
        const OnbHeadline('AI insights,', 'real-time clarity.'),
        const SizedBox(height: AppSpace.s12),
        const OnbSubtitle(
            'Describe symptoms or upload a photo. PawDoc helps you understand '
            'how soon to act.'),

        // Device mockup on a lit stage, with orbiting glyphs and the scan ring
        // behind it — the reference's whole composition, not a bare card.
        const SizedBox(height: AppSpace.s8),
        const _AiStage(),

        const SizedBox(height: AppSpace.s16),
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
  // 3 · Emergency guidance (mockup 004)
  // -------------------------------------------------------------------------
  //
  // Two copy departures from the mockup, both deliberate:
  //
  // * the right card is titled "Not Urgent" in the reference — a triage verdict,
  //   and the closest thing in the whole flow to an all-clear. The action ladder
  //   has no "do nothing" rung, so the card is titled by its *action*.
  // * the deck reads "Instant emergency detection" in the reference, which
  //   promises a reliability the pipeline does not claim. What is true — and
  //   what actually matters here — is that the guidance is free and always
  //   reachable, so that is what it says.
  Widget _emergency() => OnbPage(children: [
        const SizedBox(height: AppSpace.s4),
        const Center(
            child: OnbCrest(
                asset: UiAssets.onbShieldPawTeal3d,
                height: 76,
                tint: AppColors.cyan300)),
        const SizedBox(height: AppSpace.s12),
        const OnbHeadline('When it\u2019s urgent,', 'PawDoc guides you.'),
        const SizedBox(height: AppSpace.s12),
        const OnbSubtitle.rich([
          ('Step-by-step emergency guidance —\n', null),
          ('always free', AppColors.emerald400),
          (', always available.', null),
        ]),
        const SizedBox(height: AppSpace.s24),
        const EmergencyCompareStage(),
        const SizedBox(height: AppSpace.s24),
        const DoesNotDiagnosePanel(),
        const SizedBox(height: AppSpace.s24),
        const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: _TrustColumn(
              art: OnbAlwaysOnDial(size: 56),
              title: 'Always Available',
              caption: 'Guidance anytime,\nday or night.',
            ),
          ),
          _TrustDivider(),
          Expanded(
            child: _TrustColumn(
              art: OnbHaloIcon(LucideIcons.bookOpen,
                  tint: AppColors.cyan300, size: 42, halo: 72),
              title: 'Clear Steps',
              caption: 'Easy-to-follow\ninstructions.',
            ),
          ),
          _TrustDivider(),
          Expanded(
            child: _TrustColumn(
              art: OnbHaloIcon(LucideIcons.handHeart,
                  tint: AppColors.cyan300, size: 42, halo: 72),
              title: 'Safer Decisions',
              caption: 'Know when to act\nand what to do.',
            ),
          ),
        ]),
        const SizedBox(height: AppSpace.s24),
        OnbCta(
          key: const Key('onb_next_diary'),
          label: 'Next: Your Pet\'s Health Diary',
          onPressed: _advance,
        ),
        const SizedBox(height: AppSpace.s16),
        OnbDots(step: _page, total: _names.length),
      ]);

  // -------------------------------------------------------------------------
  // 4 · Health diary (mockup 005)
  // -------------------------------------------------------------------------
  Widget _healthDiary() => OnbPage(children: [
        const SizedBox(height: AppSpace.s4),
        const Center(
            child: OnbCrest(
                asset: UiAssets.onbGlyphDiaryPawCyan,
                height: 74,
                tint: AppColors.cyan400)),
        const SizedBox(height: AppSpace.s12),
        const OnbHeadline('All your pet’s health,', 'organized beautifully.'),
        const SizedBox(height: AppSpace.s12),
        const OnbSubtitle.rich([
          ('PawDoc keeps every important moment in one\nsmart timeline — ', null),
          ('easy to track, easy to share.', AppColors.emerald400),
        ]),
        const SizedBox(height: AppSpace.s16),
        const DiaryStage(),
        const SizedBox(height: AppSpace.s20),
        const OnbPanel(
          padding: EdgeInsets.fromLTRB(
              AppSpace.s8, AppSpace.s16, AppSpace.s8, AppSpace.s16),
          child: OnbTrustRow(items: [
            (
              LucideIcons.shieldCheck,
              'Always private',
              'Only you can see your pet’s data.',
              AppColors.cyan400
            ),
            (
              LucideIcons.cloudUpload,
              'Always safe',
              'Secure cloud backup you can trust.',
              AppColors.emerald400
            ),
            (
              LucideIcons.share2,
              'Easy to share',
              'Share reports instantly with your vet.',
              AppColors.cyan400
            ),
          ]),
        ),
        const SizedBox(height: AppSpace.s20),
        OnbCta(
          key: const Key('onb_next_assistant'),
          label: 'Next: Meet Your AI Assistant',
          onPressed: _advance,
        ),
        const SizedBox(height: AppSpace.s16),
        OnbDots(step: _page, total: _names.length),
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
            (Icons.bolt_rounded, 'Text checks', 'Always free.', null),
            (Icons.notifications_none_rounded, 'Reminders', 'Asked for only when you add one.', null),
            (Icons.health_and_safety_outlined, 'Emergency', 'Never paywalled.', null),
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

/// One column of the `004` trust strip: art, title, two-line caption.
class _TrustColumn extends StatelessWidget {
  const _TrustColumn({
    required this.art,
    required this.title,
    required this.caption,
  });

  final Widget art;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          art,
          const SizedBox(height: 6),
          Text(title,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  height: 1.2,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(caption,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF97A2B2), fontSize: 11.5, height: 1.3)),
        ],
      );
}

class _TrustDivider extends StatelessWidget {
  const _TrustDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 104,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        color: Colors.white.withValues(alpha: 0.07),
      );
}

/// `002`'s hero stage: the pets whole and uncropped, the cyan ribbon sweeping
/// behind them, and a labelled glyph on each side.
///
/// The photo is deliberately NOT edge-faded here — the reference shows the
/// animals complete, sitting on their own dark ground, and a radial mask would
/// eat their paws.
class _ValueHeroStage extends StatelessWidget {
  const _ValueHeroStage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 356,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Faint watermarks, as the reference layers behind the subject.
          const Positioned(
            left: 6,
            top: 14,
            child: Icon(Icons.favorite_border_rounded,
                size: 44, color: Color(0x14FFFFFF)),
          ),
          const Positioned(
            right: 10,
            top: 74,
            child: Icon(Icons.add_rounded, size: 52, color: Color(0x12FFFFFF)),
          ),
          const Positioned(
            right: 18,
            bottom: 96,
            child: Icon(Icons.pets_rounded, size: 40, color: Color(0x12A3E635)),
          ),
          // The subject, uncropped, with its plate edges dissolved into the
          // canvas. The photo is opaque and rectangular; the reference has no
          // seam, so the top and sides fade while the BOTTOM is left intact —
          // a symmetric mask would eat the paws.
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  UiAssets.onbHeroPuppyKittenSeated,
                  height: 330,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const Icon(Icons.pets_rounded,
                      size: 120, color: AppColors.emerald400),
                ),
                const Positioned.fill(child: _PlateEdgeFade()),
              ],
            ),
          ),
          // The ribbon sweeps in FRONT of the subject, as the reference draws
          // it — behind the photo it would simply be hidden by an opaque plate.
          const Positioned.fill(child: IgnorePointer(child: OnbSwoosh())),
          const Positioned(
            left: 0,
            top: 96,
            child: _SideNote(
              icon: Icons.pets_rounded,
              tint: AppColors.emerald400,
              lines: ['Stronger bond,', 'healthier life.'],
            ),
          ),
          const Positioned(
            right: 0,
            top: 40,
            child: _SideNote(
              icon: Icons.monitor_heart_outlined,
              tint: AppColors.cyan300,
              lines: ['Build trust', 'with every', 'moment.'],
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// A circled glyph with a short caption beneath it, flanking the hero.
class _SideNote extends StatelessWidget {
  const _SideNote({
    required this.icon,
    required this.tint,
    required this.lines,
    this.alignEnd = false,
  });

  final IconData icon;
  final Color tint;
  final List<String> lines;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: Colors.white, height: 1.25, fontSize: 12.5);
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.03),
            border: Border.all(color: tint.withValues(alpha: 0.35)),
          ),
          child: Icon(icon, size: 26, color: tint),
        ),
        const SizedBox(height: 6),
        for (final l in lines)
          Text(l,
              textAlign: alignEnd ? TextAlign.right : TextAlign.left,
              style: style),
      ],
    );
  }
}

/// `002`'s social-proof card, with the shield badge straddling its top edge.
class _TrustCard extends StatelessWidget {
  const _TrustCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 26),
          child: OnbPanel(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.s12, AppSpace.s24, AppSpace.s12, AppSpace.s16),
            child: Column(children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: 'Join thousands of pet parents\nalready using ',
                      style: text.titleSmall
                          ?.copyWith(color: Colors.white, height: 1.35)),
                  TextSpan(
                      text: 'PawDoc.',
                      style: text.titleSmall?.copyWith(
                          color: AppColors.emerald400,
                          fontWeight: FontWeight.w700)),
                ]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.s16),
              const OnbTrustRow(items: [
                (Icons.verified_user_outlined, 'Trusted by pet parents', null, null),
                (Icons.lock_outline_rounded, 'Your data is private', null, null),
                (Icons.support_agent_rounded, 'We\'re here to help', null, null),
              ]),
            ]),
          ),
        ),
        // The badge overlaps the card's top edge in the reference.
        Container(
          width: 54,
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.emerald400.withValues(alpha: 0.45),
                AppColors.emerald500.withValues(alpha: 0.18),
              ],
            ),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12), bottom: Radius.circular(27)),
            border: Border.all(
                color: AppColors.emerald400.withValues(alpha: 0.85), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: AppColors.emerald500.withValues(alpha: 0.40),
                  blurRadius: 20,
                  spreadRadius: -4),
            ],
          ),
          child: const Icon(Icons.pets_rounded, size: 26, color: Colors.white),
        ),
      ],
    );
  }
}


/// Dissolves the top and side edges of an opaque photo plate into the canvas,
/// leaving the bottom untouched.
///
/// The onboarding heroes came back as rectangles on a rendered background
/// rather than as cut-outs. A radial mask would fade all four sides equally and
/// clip the animals' feet, so the fades are drawn as canvas-coloured overlays
/// on three edges only.
class _PlateEdgeFade extends StatelessWidget {
  const _PlateEdgeFade();

  static const _bg = AppColors.navy900;

  @override
  Widget build(BuildContext context) {
    Widget edge(Alignment begin, Alignment end, double extent) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: const [_bg, Color(0x00050B14)],
              stops: [0.0, extent],
            ),
          ),
        );
    return IgnorePointer(
      child: Stack(children: [
        Positioned.fill(child: edge(Alignment.centerLeft, Alignment.centerRight, 0.22)),
        Positioned.fill(child: edge(Alignment.centerRight, Alignment.centerLeft, 0.22)),
        Positioned.fill(child: edge(Alignment.topCenter, Alignment.bottomCenter, 0.16)),
      ]),
    );
  }
}

/// `003`'s stage: the scan ring and hologram art behind a real device mockup,
/// with orbiting capability glyphs — the reference's full composition.
class _AiStage extends StatelessWidget {
  const _AiStage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 430,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Scan ring bloom behind everything.
          Positioned(
            top: 22,
            child: Opacity(
              opacity: 0.55,
              child: BlendMask(
                blendMode: BlendMode.screen,
                child: Image.asset(UiAssets.aiLoadingScanRing,
                    height: 300,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink()),
              ),
            ),
          ),
          const Positioned(
            left: 4,
            top: 16,
            child: _OrbGlyph(icon: Icons.psychology_outlined, tint: AppColors.cyan300),
          ),
          const Positioned(
            right: 6,
            top: 60,
            child: _OrbGlyph(
                icon: Icons.monitor_heart_outlined, tint: AppColors.emerald400),
          ),
          const Positioned(
            left: 10,
            bottom: 92,
            child: _OrbGlyph(
                icon: Icons.photo_camera_outlined, tint: AppColors.emerald400),
          ),
          const Positioned(
            right: 4,
            bottom: 46,
            child: _OrbGlyph(
                icon: Icons.description_outlined, tint: AppColors.cyan400),
          ),
          // The device itself.
          const OnbPhoneMockup(height: 404, child: _AiResultScreen()),
        ],
      ),
    );
  }
}

/// A small circled glyph orbiting the device.
class _OrbGlyph extends StatelessWidget {
  const _OrbGlyph({required this.icon, required this.tint});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0A1120).withValues(alpha: 0.85),
          border: Border.all(color: tint.withValues(alpha: 0.40)),
          boxShadow: [
            BoxShadow(
                color: tint.withValues(alpha: 0.22),
                blurRadius: 16,
                spreadRadius: -3),
          ],
        ),
        child: Icon(icon, size: 23, color: tint),
      );
}

/// What the phone is showing on `003`.
///
/// The reference renders "Monitor at Home / Low urgency / No critical signs
/// detected" here — an all-clear that terminates with reassurance and no
/// action (review V-14). This is the compliant equivalent: an observation, a
/// next step, a timeframe, and the disclaimer.
class _AiResultScreen extends StatelessWidget {
  const _AiResultScreen();

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(
        color: AppColors.cyan300, fontSize: 8.5, fontWeight: FontWeight.w700);
    const body =
        TextStyle(color: Color(0xFFD3DBE6), fontSize: 9, height: 1.3);
    // The aperture is ~152x351. FittedBox lets the screen be authored at a
    // comfortable size and scaled down to fit, rather than tuning every font
    // against one device height — and it keeps the copy real text.
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 26, 10, 10),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 152,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.emerald500.withValues(alpha: 0.16),
                border: Border.all(
                    color: AppColors.emerald400.withValues(alpha: 0.6)),
              ),
              child: const Icon(Icons.pets_rounded,
                  size: 12, color: AppColors.emerald400),
            ),
            const SizedBox(width: 6),
            // Flexible: the screen aperture is ~150dp wide, so a fixed-width
            // title overflows the mockup before it ever reaches the device.
            const Expanded(
              child: Text('AI Health Check',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),
          // A thumbnail of what the owner submitted.
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(UiAssets.petBuddyAvatar,
                height: 66,
                width: double.infinity,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => Container(
                    height: 66, color: const Color(0xFF14203A))),
          ),
          const SizedBox(height: 9),
          const Text('What we observed', style: label),
          const Text('An occasional dry cough. Appetite and energy unchanged.',
              style: body),
          const SizedBox(height: 7),
          const Text('What to do', style: label),
          const Text('Keep them rested and watch breathing and appetite.',
              style: body),
          const SizedBox(height: 7),
          const Text('Timing', style: label),
          const Text('If it continues past 24–48 hours, or worsens, contact '
              'your vet.', style: body),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.emerald500.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                  color: AppColors.emerald500.withValues(alpha: 0.32)),
            ),
            child: const Row(children: [
              Icon(Icons.verified_user_outlined,
                  size: 10, color: AppColors.emerald400),
              SizedBox(width: 4),
              Expanded(
                child: Text('AI-generated guidance, not a diagnosis.',
                    style: TextStyle(
                        color: Color(0xFFBFE8CB), fontSize: 8, height: 1.25)),
              ),
            ]),
          ),
            ],
          ),
        ),
      ),
    );
  }
}
