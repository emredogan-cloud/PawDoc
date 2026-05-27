import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dates.dart';
import '../pets/active_pet.dart';
import 'reminder_form_screen.dart';
import 'reminders_repository.dart';

/// Manage health reminders for the active pet. Reached from the Health History
/// screen. Reactive to the active pet (Phase 3.1 switcher).
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pet = ref.watch(activePetProvider);
    if (pet == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reminders')),
        body: const Center(child: Text('Add a pet to set reminders.')),
      );
    }
    final reminders = ref.watch(remindersForPetProvider(pet.id!));

    return Scaffold(
      appBar: AppBar(title: Text('${pet.name} · reminders')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_reminder_fab'),
        onPressed: () async {
          await Navigator.of(context).push<bool>(MaterialPageRoute(
            builder: (_) => ReminderFormScreen(petId: pet.id!, petName: pet.name),
          ));
          ref.invalidate(remindersForPetProvider(pet.id!));
        },
        icon: const Icon(Icons.add_alert),
        label: const Text('New reminder'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(remindersForPetProvider(pet.id!)),
        child: reminders.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [Padding(padding: const EdgeInsets.all(24), child: Text('Could not load reminders:\n$e'))],
          ),
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('No reminders yet.\nTap "New reminder" to add one.',
                          textAlign: TextAlign.center),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = list[i];
                return ListTile(
                  leading: Icon(r.isSent ? Icons.notifications_off_outlined : Icons.alarm),
                  title: Text(r.reminderType),
                  subtitle: Text(r.isSent ? 'Sent' : 'Due ${shortDate(r.dueDate)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await ref.read(remindersRepositoryProvider).delete(r.id!);
                      ref.invalidate(remindersForPetProvider(pet.id!));
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
