import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add_pet_flow.dart';
import 'pet.dart';
import 'pet_form_screen.dart';
import 'pets_repository.dart';

class PetsListScreen extends ConsumerWidget {
  const PetsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pets = ref.watch(petsListProvider);

    Future<void> openForm({Pet? pet}) async {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PetFormScreen(pet: pet)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My pets')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_pet_fab'),
        // Tier-gated (Free/Premium = 2, Family = unlimited) + fires multi_pet_added.
        onPressed: () => startAddPetFlow(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add pet'),
      ),
      body: pets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load pets:\n$e', textAlign: TextAlign.center)),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No pets yet. Tap “Add pet”.'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final pet = list[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.pets)),
                title: Text(pet.name),
                subtitle: Text(pet.breed == null ? pet.species : '${pet.species} · ${pet.breed}'),
                onTap: () => openForm(pet: pet),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('Delete ${pet.name}?'),
                        content: const Text('This hides the pet. Past analyses are kept.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(petsRepositoryProvider).softDelete(pet.id!);
                      ref.invalidate(petsListProvider);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
