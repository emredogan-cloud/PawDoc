import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../analytics/analytics.dart';
import '../core/app_image.dart';
import '../core/motion.dart';
import '../core/pet_display.dart';
import '../experiments/feature_flags.dart';
import '../monetization/paywall_screen.dart';
import '../notifications/onesignal_service.dart';
import '../pets/pet.dart';
import '../pets/pets_repository.dart';
import '../pets/species_chip.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';

/// The 5-screen onboarding wizard (roadmap §3.2 / §4.5):
/// Value Hook → Pet Setup → Trust Signal → Push Permission (UI only) → Activation.
/// Fires `onboarding_step_completed` per step and `onboarding_completed` at the end.
/// Push permission is UI only here — OneSignal is wired in Phase 2.1.
///
/// Phase D adds the OnboardingScaffold (progress dots + Skip), a hero
/// illustration slot, custom species chips, and per-step motion — all
/// reduce-motion-gated. The 5-step flow, analytics, pet creation, and routing
/// are unchanged.
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
    'value_hook', 'pet_setup', 'trust_signal', 'push_permission', 'activation',
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
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _submitPetSetup() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter your pet’s name.')));
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
      await _maybeShowOnboardingPaywall();
      await _advance();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not save your pet. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Onboarding Variant B (aggressive): show the paywall right after pet
  /// creation, before the camera. It is SKIPPABLE and appears BEFORE any
  /// analysis — so it can never block an analysis or an EMERGENCY result (the
  /// trust rule only governs the post-analysis paywall, which is unchanged).
  /// Fail-safe: Variant A (or any unknown flag) shows nothing here.
  Future<void> _maybeShowOnboardingPaywall() async {
    final variant = await ref.read(featureFlagsProvider).getVariant(
          FeatureFlagKeys.onboardingVariant,
          allowed: FeatureFlagKeys.onboardingVariants,
        );
    if (variant != 'B' || !mounted) return;
    await Analytics.onboardingPaywallShown();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );
  }

  Future<void> _finish() async {
    await Analytics.onboardingCompleted();
    if (mounted) context.go('/');
  }

  /// Top-right Skip → home. Routing/guard logic is unchanged: onboarding is an
  /// optional flow entered from the home empty state, so leaving simply returns
  /// to home (which re-shows the "set up your pet" prompt if none exists).
  void _skip() => context.go('/');

  // Hardened display name: capitalizes the first letter and falls back to
  // "your pet" for an empty/whitespace name, so personalized copy never reads
  // "check on ker" or "in 's health". The stored name is untouched.
  String get _petName => petDisplayName(_createdPet?.name);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _OnboardingHeader(step: _page, total: _names.length, onSkip: _skip),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _valueHook(),
                  _petSetup(),
                  _trustSignal(),
                  _pushPermission(),
                  _activation(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pad(List<Widget> children) => Padding(
        padding: const EdgeInsets.all(AppSpace.s24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );

  /// Staggered fade-up for entrance copy (reduce-motion → plain).
  Widget _fadeUp(Widget child, int index) {
    if (reduceMotion(context)) return child;
    return child
        .animate()
        .fadeIn(
            duration: AppMotion.standard,
            delay: Duration(milliseconds: 60 * index))
        .slideY(
            begin: 0.12,
            end: 0,
            duration: AppMotion.standard,
            curve: AppMotion.emphasized);
  }

  // ---- Step 1 · Value Hook ----
  Widget _valueHook() => _pad([
        const Spacer(),
        _onbHero(),
        const SizedBox(height: AppSpace.s32),
        _fadeUp(
          Text('Never wonder if your pet needs the vet again.',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center),
          0,
        ),
        const SizedBox(height: AppSpace.s12),
        _fadeUp(
          const Text('AI triage in seconds. 24/7. Less than \$0.33/day.',
              textAlign: TextAlign.center),
          1,
        ),
        const Spacer(),
        AppButton(
          key: const Key('onb_get_started'),
          onPressed: _advance,
          child: const Text('Get Started'),
        ),
      ]);

  Widget _onbHero() {
    final scheme = Theme.of(context).colorScheme;
    final hero = AppImage(
      AppAssets.onbHero,
      height: 200,
      fallback: Container(
        height: 200,
        width: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [scheme.primaryContainer, scheme.surface],
          ),
        ),
        child: Icon(Icons.pets_rounded, size: 88, color: scheme.primary),
      ),
    );
    if (reduceMotion(context)) return Center(child: hero);
    return Center(
      child: hero
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
              begin: 1.0,
              end: 1.03,
              duration: const Duration(seconds: 4),
              curve: Curves.easeInOut),
    );
  }

  // ---- Step 2 · Pet Setup ----
  Widget _petSetup() => ListView(
        padding: const EdgeInsets.all(AppSpace.s24),
        children: [
          Text('Tell us about your pet',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpace.s20),
          TextField(
            key: const Key('onb_pet_name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name', filled: true),
          ),
          const SizedBox(height: AppSpace.s20),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              for (final s in kSpecies)
                SpeciesChip(
                  species: s,
                  selected: _species == s,
                  onTap: () => setState(() => _species = s),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s20),
          TextField(
            controller: _breed,
            decoration:
                const InputDecoration(labelText: 'Breed (optional)', filled: true),
          ),
          const SizedBox(height: AppSpace.s24),
          AppButton(
            key: const Key('onb_pet_continue'),
            onPressed: _busy ? null : _submitPetSetup,
            child: Text(_busy ? 'Saving…' : 'Continue'),
          ),
          const SizedBox(height: AppSpace.s8),
          const Text('Add more pets later. Edit anytime.', textAlign: TextAlign.center),
        ],
      );

  // ---- Step 3 · Trust Signal (honesty rebuild from Phase B) ----
  // The fabricated "★ 4.8 — trusted by thousands" and the unsubstantiated
  // "Reviewed by veterinary experts" claims were replaced with truthful,
  // defensible trust pillars. Final wording is pending owner/legal sign-off.
  Widget _trustSignal() => _pad([
        const Spacer(),
        Center(child: _shieldHero()),
        const SizedBox(height: AppSpace.s16),
        Text('Built to keep pets safe',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.s20),
        _trustPillar('Vet-informed triage protocols'),
        _trustPillar('Errs on the safe side — flags emergencies first'),
        _trustPillar('Your photos are private & encrypted'),
        _trustPillar('We inform; your vet decides'),
        const Spacer(),
        AppButton(onPressed: _advance, child: const Text('Continue')),
      ]);

  Widget _shieldHero() {
    final scheme = Theme.of(context).colorScheme;
    final shield = AppImage(
      AppAssets.shieldCare,
      width: 88,
      height: 88,
      fallback: CircleAvatar(
        radius: 40,
        backgroundColor: scheme.primaryContainer,
        child: Icon(Icons.verified_user_rounded, size: 40, color: scheme.primary),
      ),
    );
    if (reduceMotion(context)) return shield;
    // Draw-in (scale + fade) then a soft "seal" shimmer.
    return shield
        .animate()
        .scaleXY(begin: 0.8, end: 1.0, duration: AppMotion.hero, curve: AppMotion.emphasized)
        .fadeIn(duration: AppMotion.hero)
        .then(delay: const Duration(milliseconds: 120))
        .shimmer(duration: const Duration(milliseconds: 800), color: scheme.primary);
  }

  Widget _trustPillar(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_rounded,
                size: 22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
            ),
          ],
        ),
      );

  // ---- Step 4 · Push Permission Priming ----
  Widget _pushPermission() => _pad([
        const Spacer(),
        Center(child: _bell()),
        const SizedBox(height: AppSpace.s16),
        Text('Stay ahead of health issues',
            style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.s8),
        Text('Get a heads-up when something about $_petName’s health needs attention.',
            textAlign: TextAlign.center),
        const Spacer(),
        // UI only — OneSignal permission request is wired in Phase 2.1.
        AppButton(
          key: const Key('onb_enable_alerts'),
          onPressed: () async {
            // Contextual OneSignal permission prompt (Phase 2.1); syncs player_id.
            await ref.read(oneSignalServiceProvider).requestPermissionAndSync();
            await _advance();
          },
          child: const Text('Enable alerts'),
        ),
        TextButton(onPressed: _advance, child: const Text('Maybe later')),
      ]);

  Widget _bell() {
    const bell = Icon(Icons.notifications_active_rounded, size: 56);
    if (reduceMotion(context)) return bell;
    // One-time gentle ring (~±8°).
    return bell.animate().shake(
        duration: const Duration(milliseconds: 700), hz: 4, rotation: 0.14);
  }

  // ---- Step 5 · Activation ----
  Widget _activation() => _pad([
        const Spacer(),
        Center(child: _petAvatar()),
        const SizedBox(height: AppSpace.s20),
        Text('Ready to check on $_petName?',
            style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.s12),
        const Text('Your first 3 analyses are free — no card needed.',
            textAlign: TextAlign.center),
        const Spacer(),
        AppButton(
          key: const Key('onb_finish'),
          onPressed: _finish,
          child: Text('Check $_petName now'),
        ),
      ]);

  Widget _petAvatar() {
    final scheme = Theme.of(context).colorScheme;
    final key = _createdPet?.species ?? 'other';
    final avatar = AppImage(
      AppAssets.avatar(key),
      width: 96,
      height: 96,
      fallback: CircleAvatar(
        radius: 44,
        backgroundColor: scheme.primaryContainer,
        child: Icon(Icons.pets_rounded, size: 44, color: scheme.primary),
      ),
    );
    if (reduceMotion(context)) return avatar;
    // Spring-in arrival + a single restrained sparkle (not confetti).
    return avatar
        .animate()
        .scaleXY(begin: 0.8, end: 1.0, duration: AppMotion.hero, curve: Curves.easeOutBack)
        .then(delay: const Duration(milliseconds: 80))
        .shimmer(duration: const Duration(milliseconds: 900), color: scheme.primary);
  }
}

/// Persistent onboarding header: a progress indicator (with "step n of total"
/// semantics) and a top-right Skip. The active segment grows + fills; the fill
/// animation collapses to instant under reduce-motion.
class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.step,
    required this.total,
    required this.onSkip,
  });

  final int step;
  final int total;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final animate = !reduceMotion(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.s24, AppSpace.s12, AppSpace.s8, 0),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              label: 'Step ${step + 1} of $total',
              child: Row(
                children: [
                  for (var i = 0; i < total; i++)
                    AnimatedContainer(
                      duration: animate ? AppMotion.standard : Duration.zero,
                      curve: AppMotion.standardCurve,
                      margin: const EdgeInsets.only(right: AppSpace.s8),
                      height: 8,
                      width: i == step ? 24 : 8,
                      decoration: BoxDecoration(
                        color: i <= step
                            ? scheme.primary
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                ],
              ),
            ),
          ),
          TextButton(
            key: const Key('onb_skip'),
            onPressed: onSkip,
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }
}

