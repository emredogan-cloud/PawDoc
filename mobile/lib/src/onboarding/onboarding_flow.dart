import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../analytics/analytics.dart';
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
  bool _busy = false;
  int _page = 0;

  /// One page per mockup, `002`–`009` — which is also the `Step N of 8` the
  /// later mockups print in their own footers.
  static const _names = [
    'value_hook',
    'ai_insights',
    'emergency_guidance',
    'health_diary',
    'assistant_intro',
    'assistant_chat',
    'pet_setup',
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
      await ref.read(petsRepositoryProvider).create(
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
                    _assistantIntro(),
                    _assistantChat(),
                    _petSetup(),
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
  // 5 · Meet the assistant (mockup 006)
  // -------------------------------------------------------------------------
  //
  // The mockup's sample answer opens "Sneezing can be caused by mild irritants,
  // allergies, or infections" — three conditions named as causes (review V-13).
  // The reply here checks observations instead and closes on a timeframe.
  Widget _assistantIntro() => OnbPage(children: [
        const SizedBox(height: AppSpace.s4),
        Center(
          child: Image.asset(
            UiAssets.aiRobotMascotNeon,
            height: 104,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const OnbNeonGlyph(LucideIcons.bot,
                tint: AppColors.cyan400, size: 74),
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        const OnbHeadline('Meet your', 'AI Pet Assistant.'),
        const SizedBox(height: AppSpace.s12),
        const OnbSubtitle(
            'Your personal AI guide that remembers your pets, answers '
            'questions, and helps you make smarter decisions every day.'),
        const SizedBox(height: AppSpace.s16),
        const AssistantStage(
          phoneHeight: 322,
          left: [
            OnbSideCard(
                icon: LucideIcons.brain,
                title: 'Pet-Aware Conversations',
                caption: 'AI remembers your pets and context.',
                tint: AppColors.cyan400,
                width: 90),
            OnbSideCard(
                icon: LucideIcons.messageCircle,
                title: 'Instant Answers',
                caption: 'Get clear guidance in seconds.',
                tint: AppColors.cyan400,
                width: 90),
          ],
          right: [
            OnbSideCard(
                icon: LucideIcons.history,
                title: 'Chat History',
                caption: 'All conversations saved and easy to revisit.',
                tint: AppColors.cyan400,
                width: 90),
            OnbSideCard(
                icon: LucideIcons.shieldCheck,
                title: 'Safe & Responsible',
                caption: 'Always educational, never a substitute for a vet.',
                tint: AppColors.emerald400,
                width: 90),
          ],
          screen: ChatScreen(
            title: 'PawDoc AI',
            subtitle: 'Your Pet Assistant',
            question:
                'My cat has been sneezing for two days. Should I be worried?',
            time: '9:40 AM',
            opening: 'Thanks for sharing — I can help you think this through.',
            leadIn: 'Here’s what I’d check:',
            checks: [
              'Any other changes (appetite, energy, breathing)',
              'Keep their space clean and dust-free',
              'If it continues beyond 2–3 days, or worsens, contact your vet',
            ],
            closing: null,
            disclaimer: 'This is not a diagnosis. For serious or worsening '
                'symptoms, contact your veterinarian.',
            avatar: UiAssets.petMiloTabbyAvatar,
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        OnbPanel(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s16, vertical: AppSpace.s12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const OnbNeonGlyph(LucideIcons.lockKeyhole,
                tint: AppColors.emerald400, size: 18),
            const SizedBox(width: AppSpace.s8),
            Flexible(
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Your chats are '),
                  _accent('private'),
                  const TextSpan(text: ' and securely stored.'),
                ]),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFFC3CCD9), fontSize: 13, height: 1.3),
              ),
            ),
          ]),
        ),
        const SizedBox(height: AppSpace.s12),
        // The pair sit behind the CTA, as the mockup overlaps them.
        Transform.translate(
          offset: const Offset(0, 24),
          child: const HeroWithHearts(
              asset: UiAssets.onbHeroPuppyKittenBlanket,
              height: 150,
              tint: AppColors.cyan400),
        ),
        OnbCta(
          key: const Key('onb_next_chat'),
          label: 'Next: Add Your First Pet',
          onPressed: _advance,
        ),
        const SizedBox(height: AppSpace.s12),
        OnbStepLabel(step: _page, total: _names.length),
      ]);

  // -------------------------------------------------------------------------
  // 6 · One assistant, all paws covered (mockup 007)
  // -------------------------------------------------------------------------
  //
  // The safety review names this mockup's sample answer the compliant
  // reference — no condition named, no cause asserted, an action and a
  // timeframe — so it is reproduced as drawn.
  Widget _assistantChat() => OnbPage(children: [
        const SizedBox(height: AppSpace.s4),
        const Center(child: PawPlusCrest(tint: AppColors.emerald400, size: 60)),
        const SizedBox(height: AppSpace.s8),
        const OnbHeadline('One assistant.', 'All paws covered.'),
        const SizedBox(height: AppSpace.s12),
        const OnbSubtitle(
            'Chat with PawDoc AI about anything related to your pet. Get '
            'helpful answers, guidance, and peace of mind — any time, day or '
            'night.'),
        const SizedBox(height: AppSpace.s16),
        const AssistantStage(
          phoneHeight: 322,
          left: [
            OnbSideCard(
                icon: LucideIcons.messageCircle,
                title: 'Pet-Aware Conversations',
                caption: 'Understands your pet’s details and history.',
                tint: AppColors.emerald400,
                width: 90),
            OnbSideCard(
                icon: LucideIcons.brain,
                title: 'Smart Guidance',
                caption: 'Clear, reliable answers in seconds.',
                tint: AppColors.emerald400,
                width: 90),
            OnbSideCard(
                icon: LucideIcons.history,
                title: 'Chat History',
                caption: 'Pick up where you left off, anytime.',
                tint: AppColors.emerald400,
                width: 90),
          ],
          right: [
            OnbSideCard(
                icon: LucideIcons.shieldCheck,
                title: 'Safe & Responsible',
                caption: 'Always educational, never a substitute for a vet.',
                tint: AppColors.emerald400,
                width: 90),
            OnbSideCard(
                icon: LucideIcons.lockKeyhole,
                title: 'Private by Design',
                caption: 'Your conversations are encrypted and secure.',
                tint: AppColors.emerald400,
                width: 90),
            OnbSideCard(
                icon: LucideIcons.heart,
                title: 'Here for You',
                caption: 'Day or night, PawDoc is always ready.',
                tint: AppColors.emerald400,
                width: 90),
          ],
          screen: ChatScreen(
            title: 'PawDoc AI',
            subtitle: 'AI Pet Assistant',
            question: 'My dog is eating less than usual. Should I be worried?',
            time: '09:41 AM',
            opening: 'It depends on a few factors. A mild loss of appetite can '
                'happen for many reasons.',
            leadIn: 'Here are some things to check first:',
            checks: [
              'Any other symptoms (vomiting, lethargy, diarrhea)',
              'Recent diet or environment changes',
              'Hydration and energy levels',
            ],
            closing: 'If it continues for more than 24–48 hours or worsens, '
                'please consult your veterinarian.',
            disclaimer: 'This is AI-generated guidance, not a diagnosis. '
                'Always consult your veterinarian.',
            avatar: UiAssets.petBuddyAvatar,
            sendIcon: LucideIcons.mic,
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        OnbPanel(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s12, vertical: AppSpace.s12),
          child: Row(children: [
            Image.asset(
              UiAssets.onbShieldPawTeal3d,
              height: 46,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const OnbNeonGlyph(
                  LucideIcons.shieldCheck,
                  tint: AppColors.emerald400,
                  size: 26),
            ),
            const SizedBox(width: AppSpace.s8),
            Flexible(
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'PawDoc AI is built with '),
                  _accent('safety'),
                  const TextSpan(text: ', '),
                  _accent('transparency'),
                  const TextSpan(text: ', and your pet’s '),
                  _accent('wellbeing'),
                  const TextSpan(text: ' at the core.'),
                ]),
                style: const TextStyle(
                    color: Color(0xFFC3CCD9), fontSize: 13, height: 1.34),
              ),
            ),
          ]),
        ),
        const SizedBox(height: AppSpace.s12),
        Transform.translate(
          offset: const Offset(0, 28),
          child: const HeroWithHearts(
              asset: UiAssets.onbHeroDogCatHalo,
              height: 176,
              tint: AppColors.emerald400),
        ),
        OnbCta(
          key: const Key('onb_next_pet'),
          label: 'Next: Personalize Your Experience',
          onPressed: _advance,
        ),
        const SizedBox(height: AppSpace.s12),
        OnbStepLabel(step: _page, total: _names.length),
      ]);

  /// An emerald clause inside a run of deck copy — the mockups' inline accent.
  static TextSpan _accent(String text) => TextSpan(
      text: text,
      style: const TextStyle(
          color: AppColors.emerald400, fontWeight: FontWeight.w700));

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
}

// ---------------------------------------------------------------------------
// Page-local building blocks
// ---------------------------------------------------------------------------

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
