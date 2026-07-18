import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../analytics/analytics.dart';
import '../core/app_image.dart';
import '../core/app_motion_asset.dart';
import '../core/living_pet_avatar.dart';
import '../core/motion.dart';
import '../core/pet_display.dart';
import '../pets/pet.dart';
import '../pets/pets_repository.dart';
import '../pets/species_chip.dart';
import '../theme/app_assets.dart';
import '../theme/app_theme.dart';
import '../theme/paw_ui.dart';

/// The 3-screen onboarding wizard (J2):
/// Value Hook (with the honesty pillars) → Pet Setup → Activation.
/// Fires `onboarding_step_completed` per step and `onboarding_completed` at the
/// end. Notification permission is asked contextually at reminder creation —
/// never as an upfront onboarding step.
///
/// NEW-UI translation (003–007): the flow now lives in the dark teal-green world
/// — cuddle-duo hero art, mint→teal pill CTAs, value pills and dark feature
/// rows. The 5-step flow, analytics, pet creation, the M1 hero motion, the M2
/// living Paw Pal avatar, routing, and ALL widget keys are unchanged.
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
    'value_hook', 'pet_setup', 'activation',
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
    return PawScaffold(
      variant: PawSurface.dark,
      body: Column(
        children: [
          _OnboardingHeader(step: _page, total: _names.length, onSkip: _skip),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _valueHook(),
                _petSetup(),
                _activation(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A page that flexes with [Spacer]s on tall screens but scrolls (instead of
  /// overflowing) on short ones — so a CTA is always reachable.
  Widget _scrollPage(List<Widget> children) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
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

  // ---- Step 1 · Value Hook (003) ----
  Widget _valueHook() => _scrollPage([
        const Spacer(),
        _onbHero(),
        const SizedBox(height: AppSpace.s20),
        _fadeUp(
          Text('A calm, clear read on your pet\'s symptoms — in seconds.',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.ink50, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          0,
        ),
        const SizedBox(height: AppSpace.s16),
        _fadeUp(
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _ValuePill(icon: Icons.bolt_rounded, label: 'Guidance\nin seconds'),
              _ValuePill(icon: Icons.nightlight_round, label: 'Always here,\nday or night'),
              _ValuePill(icon: Icons.emergency_rounded, label: 'Emergency help,\nalways free'),
            ],
          ),
          1,
        ),
        const SizedBox(height: AppSpace.s16),
        _fadeUp(
          PawCard(
            padding: const EdgeInsets.all(AppSpace.s12),
            child: Column(
              children: [
                _trustPillar(Icons.health_and_safety_rounded,
                    'Errs on the safe side — flags emergencies first'),
                const SizedBox(height: AppSpace.s8),
                _trustPillar(Icons.medical_services_rounded,
                    'We inform; your vet decides'),
              ],
            ),
          ),
          2,
        ),
        const Spacer(),
        const SizedBox(height: AppSpace.s8),
        PawPrimaryButton(
          key: const Key('onb_get_started'),
          icon: Icons.pets_rounded,
          onPressed: _advance,
          child: const Text('Get Started'),
        ),
      ]);

  Widget _onbHero() {
    final scheme = Theme.of(context).colorScheme;
    // M1 (A1): the cuddle-duo Lottie owns the motion (breath, sparkles, glow);
    // reduce-motion / load failure falls back to the new static duo PNG.
    return Center(
      child: AppMotionAsset(
        AppMotionAssets.onbHeroLoop,
        fallbackAsset: AppAssets.onbDuoContent,
        height: 168,
        fallback: Container(
          height: 168,
          width: 168,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [scheme.primaryContainer, scheme.surface],
            ),
          ),
          child: Icon(Icons.pets_rounded, size: 80, color: scheme.primary),
        ),
      ),
    );
  }

  // ---- Step 2 · Pet Setup (004) ----
  Widget _petSetup() => ListView(
        padding: const EdgeInsets.all(AppSpace.s24),
        children: [
          Center(
            child: AppImage(
              AppAssets.onbDuoHug,
              height: 120,
              fallback: const Icon(Icons.pets_rounded,
                  size: 88, color: PawPalette.mint),
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          Text('Tell us about your pet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.ink50, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpace.s20),
          TextField(
            key: const Key('onb_pet_name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name', filled: true),
          ),
          const SizedBox(height: AppSpace.s20),
          Text('What kind of pet are they?',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: AppColors.ink300)),
          const SizedBox(height: AppSpace.s12),
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
          PawPrimaryButton(
            key: const Key('onb_pet_continue'),
            icon: Icons.pets_rounded,
            onPressed: _busy ? null : _submitPetSetup,
            child: Text(_busy ? 'Saving…' : 'Continue'),
          ),
          const SizedBox(height: AppSpace.s8),
          Text('Add more pets later. Edit anytime.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.ink300)),
        ],
      );

  // ---- Step 3 · Trust Signal (005) — honesty rebuild from Phase B ----
  // Truthful, defensible trust pillars (no fabricated ratings/expert claims).
  Widget _trustPillar(IconData icon, String text) =>
      PawFeatureRow(icon: icon, title: text, trailing: const PawCheck());

  // ---- Step 4 · Activation (007) ----
  Widget _activation() => _scrollPage([
        const Spacer(),
        Center(child: _petAvatar()),
        const SizedBox(height: AppSpace.s20),
        Text('Ready to check on $_petName?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.ink50, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.s12),
        Text('Symptom checks are free — no card, no limit.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.ink300)),
        const Spacer(),
        const SizedBox(height: AppSpace.s8),
        PawPrimaryButton(
          key: const Key('onb_finish'),
          icon: Icons.pets_rounded,
          onPressed: _finish,
          child: Text('Check $_petName now'),
        ),
      ]);

  Widget _petAvatar() {
    final scheme = Theme.of(context).colorScheme;
    final key = _createdPet?.species ?? 'other';
    // M2 (#10): the first emotional moment — the species Paw Pal arrives
    // (existing spring + shimmer preserved), does ONE happy beat, then idles
    // with its blink loop. Reduce-motion renders the static species PNG.
    final avatar = LivingPetAvatar(
      species: key,
      size: 96,
      seed: _createdPet?.id,
      mountBeat: PalBeat.happy,
    );
    if (reduceMotion(context)) return avatar;
    return avatar
        .animate()
        .scaleXY(begin: 0.8, end: 1.0, duration: AppMotion.hero, curve: Curves.easeOutBack)
        .then(delay: const Duration(milliseconds: 80))
        .shimmer(duration: const Duration(milliseconds: 900), color: scheme.primary);
  }
}

/// A compact value pill (icon disc + 2-line label) for the value-hook row.
class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PawPalette.teal.withValues(alpha: 0.16),
              border: Border.all(color: PawPalette.mint.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: PawPalette.mint, size: 24),
          ),
          const SizedBox(height: AppSpace.s8),
          Text(label,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.ink300)),
        ],
      ),
    );
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
                            ? PawPalette.mint
                            : Colors.white.withValues(alpha: 0.16),
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
