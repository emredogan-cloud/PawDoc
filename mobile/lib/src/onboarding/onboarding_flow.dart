import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../analytics/analytics.dart';
import '../experiments/feature_flags.dart';
import '../monetization/paywall_screen.dart';
import '../notifications/onesignal_service.dart';
import '../pets/pet.dart';
import '../pets/pets_repository.dart';

/// The 5-screen onboarding wizard (roadmap §6):
/// Value Hook → Pet Setup → Trust Signal → Push Permission (UI only) → Activation.
/// Fires `onboarding_step_completed` per step and `onboarding_completed` at the end.
/// Push permission is UI only here — OneSignal is wired in Phase 2.1.
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

  String get _petName => _createdPet?.name ?? 'your pet';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
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
    );
  }

  Widget _pad(List<Widget> children) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );

  Widget _valueHook() => _pad([
        const Spacer(),
        Text('Never wonder if your pet needs the vet again.',
            style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        const Text('AI triage in seconds. 24/7. Less than \$0.33/day.',
            textAlign: TextAlign.center),
        const Spacer(),
        FilledButton(
          key: const Key('onb_get_started'),
          onPressed: _advance,
          child: const Text('Get Started'),
        ),
      ]);

  Widget _petSetup() => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Tell us about your pet', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          TextField(
            key: const Key('onb_pet_name'),
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: [
            for (final s in kSpecies)
              ChoiceChip(
                label: Text(speciesLabel(s)),
                selected: _species == s,
                onSelected: (_) => setState(() => _species = s),
              ),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _breed,
            decoration: const InputDecoration(labelText: 'Breed (optional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('onb_pet_continue'),
            onPressed: _busy ? null : _submitPetSetup,
            child: Text(_busy ? 'Saving…' : 'Continue'),
          ),
          const Text('Add more pets later. Edit anytime.', textAlign: TextAlign.center),
        ],
      );

  Widget _trustSignal() => _pad([
        const Spacer(),
        const CircleAvatar(radius: 40, child: Icon(Icons.verified_user, size: 40)),
        const SizedBox(height: 16),
        Text('Reviewed by veterinary experts',
            style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text('★ 4.8 — trusted by thousands of pet parents.', textAlign: TextAlign.center),
        const Spacer(),
        FilledButton(onPressed: _advance, child: const Text('Continue')),
      ]);

  Widget _pushPermission() => _pad([
        const Spacer(),
        const Icon(Icons.notifications_active, size: 56),
        const SizedBox(height: 16),
        Text('Stay ahead of health issues',
            style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Get alerts when we notice concerning trends in $_petName’s health.',
            textAlign: TextAlign.center),
        const Spacer(),
        // UI only — OneSignal permission request is wired in Phase 2.1.
        FilledButton(
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

  Widget _activation() => _pad([
        const Spacer(),
        Text('Ready to check on $_petName?',
            style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        const Text('Your first 3 analyses are free — no card needed.',
            textAlign: TextAlign.center),
        const Spacer(),
        FilledButton(
          key: const Key('onb_finish'),
          onPressed: _finish,
          child: Text('Check $_petName now'),
        ),
      ]);
}
