import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../account/delete_account_screen.dart';
import '../account/user_profile.dart';
import '../analysis/analysis_runner.dart';
import '../analysis/analysis_service.dart';
import '../auth/auth_controller.dart';
import '../capture/camera_screen.dart';
import '../capture/video_capture_screen.dart';
import '../core/connectivity.dart';
import '../core/motion.dart';
import '../core/pet_display.dart';
import '../feedback/followup_banner.dart';
import '../health/breed_insight_card.dart';
import '../health/health_event_form_screen.dart';
import '../health/timeline.dart';
import '../monetization/telehealth_button.dart';
import '../pets/active_pet.dart';
import '../pets/add_pet_flow.dart';
import '../pets/pet.dart';
import '../pets/pets_repository.dart';
import '../referral/referral_screen.dart';
import '../text_input/symptom_text_screen.dart';
import '../theme/design_tokens.dart';

/// Sentinel value for the "Add pet" entry in the pet switcher menu.
const _addPetSentinel = '__add_pet__';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _check(BuildContext context, WidgetRef ref, Pet pet, bool isPremium) async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Record a video'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Describe symptoms'),
              onTap: () => Navigator.pop(context, 'text'),
            ),
          ],
        ),
      ),
    );
    if (mode == null || !context.mounted) return;

    if (mode == 'photo') {
      final key = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      );
      if (key != null && context.mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AnalysisRunnerScreen(
            petId: pet.id!, petName: pet.name, inputType: 'photo',
            imageStorageKey: key, isPremium: isPremium,
          ),
        ));
        ref.invalidate(userProfileProvider);
      }
    } else if (mode == 'video') {
      final frameKeys = await Navigator.of(context).push<List<String>>(
        MaterialPageRoute(builder: (_) => const VideoCaptureScreen()),
      );
      if (frameKeys != null && frameKeys.isNotEmpty && context.mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AnalysisRunnerScreen(
            petId: pet.id!, petName: pet.name, inputType: 'video',
            frameStorageKeys: frameKeys, isPremium: isPremium,
          ),
        ));
        ref.invalidate(userProfileProvider);
      }
    } else {
      final text = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => SymptomTextScreen(petName: pet.name)),
      );
      if (text != null && context.mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AnalysisRunnerScreen(
            petId: pet.id!, petName: pet.name, inputType: 'text',
            textDescription: text, isPremium: isPremium,
          ),
        ));
        ref.invalidate(userProfileProvider);
      }
    }
  }

  Future<void> _logEvent(BuildContext context, WidgetRef ref, Pet pet) async {
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => HealthEventFormScreen(petId: pet.id!, petName: pet.name),
    ));
    ref.invalidate(healthTimelineProvider(pet.id!));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petsAsync = ref.watch(petsListProvider);
    final profile = ref.watch(userProfileProvider);
    final activePet = ref.watch(activePetProvider);

    return Scaffold(
      appBar: AppBar(
        title: petsAsync.maybeWhen(
          data: (list) =>
              list.isEmpty ? const Text('PawDoc') : _PetSwitcher(pets: list, active: activePet),
          orElse: () => const Text('PawDoc'),
        ),
        actions: [
          IconButton(
            tooltip: 'Refer a friend',
            icon: const Icon(Icons.card_giftcard),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReferralScreen()),
            ),
          ),
          IconButton(
            key: const Key('sign_out_button'),
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider).signOut(),
          ),
          PopupMenuButton<String>(
            key: const Key('home_overflow_menu'),
            onSelected: (v) {
              if (v == 'family') {
                context.push('/family');
              } else if (v == 'delete') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
                );
              }
            },
            itemBuilder: (_) => const [
              // Phase 6.3.1 — Family Sharing entry-point.
              PopupMenuItem(value: 'family', child: Text('Family sharing')),
              PopupMenuItem(value: 'delete', child: Text('Delete account')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(petsListProvider);
          ref.invalidate(userProfileProvider);
          final id = activePet?.id;
          if (id != null) ref.invalidate(healthTimelineProvider(id));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const OfflineBanner(),
            // 72h "was this helpful?" follow-up (self-hides when nothing pending).
            const FollowUpBanner(),
            // Query counter.
            profile.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (p) => Card(
                child: ListTile(
                  leading: const Icon(Icons.bolt),
                  title: Text(p.isPremium ? 'Premium — unlimited checks' : 'Free checks left this month'),
                  trailing: p.isPremium ? null : Text('${p.freeRemaining}/3', style: Theme.of(context).textTheme.titleLarge),
                ),
              ),
            ),
            const SizedBox(height: 8),
            petsAsync.when(
              // Pilot skeletons (§4.3) — shimmer placeholders matching the final
              // layout (insight + pet hero + actions). Static under reduce-motion.
              loading: () => const Column(
                children: [
                  SkeletonCard(height: 72),
                  SizedBox(height: AppSpace.s8),
                  SkeletonCard(height: 120),
                  SizedBox(height: AppSpace.s8),
                  SkeletonCard(height: 44),
                ],
              ),
              error: (e, _) => Text('Could not load pets: $e'),
              data: (list) {
                if (list.isEmpty) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.add_circle_outline),
                      title: const Text('Set up your first pet'),
                      onTap: () => context.push('/onboarding'),
                    ),
                  );
                }
                final isPremium = profile.maybeWhen(data: (p) => p.isPremium, orElse: () => false);
                final pet = activePet ?? list.first;
                return Column(
                  children: [
                    BreedInsightCard(
                      key: ValueKey('breed_${pet.id}'),
                      species: pet.species,
                      breed: pet.breed,
                    ),
                    const SizedBox(height: 8),
                    _PetCard(pet: pet, onCheck: () => _check(context, ref, pet, isPremium)),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('home_view_history'),
                            onPressed: () => context.push('/history'),
                            icon: const Icon(Icons.history),
                            label: const Text('History'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('home_log_event'),
                            onPressed: () => _logEvent(context, ref, pet),
                            icon: const Icon(Icons.add_chart),
                            label: const Text('Log event'),
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => context.push('/pets'),
                      icon: const Icon(Icons.pets),
                      label: const Text('Manage pets'),
                    ),
                    // Phase 5.4 — embedded telehealth (Airvet-style affiliate).
                    // Self-hides when AIRVET_AFFILIATE_URL isn't configured.
                    const SizedBox(height: 4),
                    const TelehealthButton(source: 'home'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// App-bar pet switcher. Selecting a pet updates [activePetIdProvider], which
/// reactively re-points the breed card, the "Check" target, and the history
/// timeline. The trailing "Add pet" item runs the tier-gated add flow.
class _PetSwitcher extends ConsumerWidget {
  const _PetSwitcher({required this.pets, required this.active});

  final List<Pet> pets;
  final Pet? active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      key: const Key('pet_switcher'),
      tooltip: 'Switch pet',
      onSelected: (value) {
        if (value == _addPetSentinel) {
          startAddPetFlow(context, ref);
          return;
        }
        ref.read(activePetIdProvider.notifier).select(value);
      },
      itemBuilder: (_) => [
        for (final p in pets)
          CheckedPopupMenuItem<String>(
            value: p.id!,
            checked: p.id == active?.id,
            child: Text(petDisplayName(p.name)),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: _addPetSentinel,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.add),
            title: Text('Add pet'),
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              active == null ? 'PawDoc' : petDisplayName(active!.name),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}

class _PetCard extends ConsumerWidget {
  const _PetCard({required this.pet, required this.onCheck});
  final Pet pet;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastTriage = ref.watch(latestTriageProvider(pet.id!));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(radius: 28, child: Icon(Icons.pets, size: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(petDisplayName(pet.name), style: Theme.of(context).textTheme.titleLarge),
                      lastTriage.when(
                        loading: () => const Text('…'),
                        error: (_, _) => Text(pet.species),
                        data: (t) => Text(t == null ? 'No checks yet' : 'Last check: $t'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              // Phase C pilot: primary CTA uses AppButton (press-scale + haptic,
              // reduce-motion aware). Name uses the Phase B display helper.
              child: AppButton(
                key: Key('check_${pet.id}'),
                onPressed: onCheck,
                icon: const Icon(Icons.health_and_safety),
                child: Text('Check ${petDisplayName(pet.name)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
