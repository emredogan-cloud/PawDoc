import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dates.dart';
import 'journal_repository.dart';
import 'journals_screen.dart';

/// Latest weekly health journal card for the active pet. Self-hides quietly
/// while loading; shows a friendly placeholder when no journal exists yet
/// (cron generates them on Sundays for Premium/Family opt-in pets).
class JournalCard extends ConsumerWidget {
  const JournalCard({super.key, required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestJournalProvider(petId));
    return latest.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (j) => Card(
        key: const Key('journal_card'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu_book_outlined),
                  const SizedBox(width: 8),
                  Text('Health journal', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const JournalsScreen()),
                    ),
                    child: const Text('All journals'),
                  ),
                ],
              ),
              if (j == null) ...[
                const Text('No journal yet.'),
                const SizedBox(height: 4),
                const Text(
                  'Weekly AI summaries arrive Sundays for Premium / Family pets with the journal opt-in.',
                  style: TextStyle(fontSize: 12),
                ),
              ] else ...[
                Text('Week of ${shortDate(j.weekStartDate)}',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Text(j.narrativeText),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
