/// Home — shows the user's pet(s) and the primary "Check" action.
///
/// 1C ships a single-pet UX (no pet switcher); roadmap §10 Phase 3 adds
/// multi-pet management.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/pet.dart';
import '../pets/pets_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(petsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PawDoc'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (state) {
          PetsLoading() => const Center(child: CircularProgressIndicator()),
          PetsError(message: final m) => _ErrorBody(
            message: m,
            onRetry: () => ref.read(petsControllerProvider.notifier).refresh(),
          ),
          PetsReady(pets: final pets) when pets.isEmpty => _EmptyBody(
            onAddPet: () => context.go('/onboarding/pet'),
          ),
          PetsReady(pets: final pets) => _PetsBody(
            pets: pets,
            onCheck: (p) => context.go('/analysis/new', extra: p),
          ),
        },
      ),
    );
  }
}

class _PetsBody extends StatelessWidget {
  const _PetsBody({required this.pets, required this.onCheck});

  final List<Pet> pets;
  final void Function(Pet) onCheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ListView.separated(
        itemCount: pets.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final pet = pets[i];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        child: Text(
                          pet.species.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pet.name, style: theme.textTheme.titleLarge),
                            Text(
                              [
                                pet.species.displayName,
                                if (pet.breed != null) pet.breed,
                                if (pet.ageYears != null) '${pet.ageYears} yr',
                              ].join(' · '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => onCheck(pet),
                      icon: const Icon(Icons.health_and_safety_outlined),
                      label: Text('Check ${pet.name}'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.onAddPet});
  final VoidCallback onAddPet;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets_rounded, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Add your first pet to get started.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAddPet, child: const Text('Add a pet')),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 64),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
