import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../account/user_profile.dart';
import '../analysis/analysis_runner.dart';
import '../analysis/analysis_service.dart';
import '../auth/auth_controller.dart';
import '../capture/camera_screen.dart';
import '../pets/pet.dart';
import '../pets/pets_repository.dart';
import '../referral/referral_screen.dart';
import '../text_input/symptom_text_screen.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pets = ref.watch(petsListProvider);
    final profile = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PawDoc'),
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
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(petsListProvider);
          ref.invalidate(userProfileProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
            pets.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
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
                return Column(
                  children: [
                    for (final pet in list) _PetCard(pet: pet, onCheck: () => _check(context, ref, pet, isPremium)),
                    TextButton.icon(
                      onPressed: () => context.push('/pets'),
                      icon: const Icon(Icons.pets),
                      label: const Text('Manage pets'),
                    ),
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
                      Text(pet.name, style: Theme.of(context).textTheme.titleLarge),
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
              child: FilledButton.icon(
                key: Key('check_${pet.id}'),
                onPressed: onCheck,
                icon: const Icon(Icons.health_and_safety),
                label: Text('Check ${pet.name}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
