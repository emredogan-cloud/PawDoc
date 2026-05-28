import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics.dart';
import '../core/dates.dart';
import '../pets/active_pet.dart';
import 'journal_repository.dart';

/// Full list of weekly health journals for the active pet (newest first).
class JournalsScreen extends ConsumerStatefulWidget {
  const JournalsScreen({super.key});

  @override
  ConsumerState<JournalsScreen> createState() => _JournalsScreenState();
}

class _JournalsScreenState extends ConsumerState<JournalsScreen> {
  @override
  void initState() {
    super.initState();
    Analytics.journalViewed();
  }

  @override
  Widget build(BuildContext context) {
    final pet = ref.watch(activePetProvider);
    if (pet == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Health journal')),
        body: const Center(child: Text('Add a pet to start a health journal.')),
      );
    }
    final journals = ref.watch(journalsForPetProvider(pet.id!));
    return Scaffold(
      appBar: AppBar(title: Text('${pet.name}’s journal')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(journalsForPetProvider(pet.id!)),
        child: journals.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [Padding(padding: const EdgeInsets.all(24), child: Text('Could not load journals:\n$e'))],
          ),
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No journals yet.\nThe first weekly summary arrives on Sunday for Premium / Family pets with the journal opt-in.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final j = list[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Week of ${shortDate(j.weekStartDate)}',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Text(j.narrativeText),
                      ],
                    ),
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
