import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dates.dart';
import '../export/health_report_service.dart';
import '../pets/active_pet.dart';
import '../reminders/reminders_screen.dart';
import 'health_event_form_screen.dart';
import 'timeline.dart';

/// The combined health-history timeline for the **active** pet (analyses +
/// manual events, newest first). Watches [activePetProvider], so switching the
/// active pet re-points the whole screen reactively.
class HealthHistoryScreen extends ConsumerWidget {
  const HealthHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pet = ref.watch(activePetProvider);

    if (pet == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Health history')),
        body: const Center(child: Text('Add a pet to start a health history.')),
      );
    }

    final timeline = ref.watch(healthTimelineProvider(pet.id!));

    return Scaffold(
      appBar: AppBar(
        title: Text('${pet.name}’s history'),
        actions: [
          IconButton(
            key: const Key('export_health_report'),
            tooltip: 'Export health report',
            icon: const Icon(Icons.ios_share),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref.read(healthReportServiceProvider).exportForPet(pet);
              } catch (_) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Could not prepare the report. Please try again.')),
                );
              }
            },
          ),
          IconButton(
            key: const Key('open_reminders'),
            tooltip: 'Reminders',
            icon: const Icon(Icons.alarm),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RemindersScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('log_event_fab'),
        onPressed: () async {
          await Navigator.of(context).push<bool>(MaterialPageRoute(
            builder: (_) => HealthEventFormScreen(petId: pet.id!, petName: pet.name),
          ));
          ref.invalidate(healthTimelineProvider(pet.id!));
        },
        icon: const Icon(Icons.add),
        label: const Text('Log event'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(healthTimelineProvider(pet.id!)),
        child: timeline.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [Padding(padding: const EdgeInsets.all(24), child: Text('Could not load history:\n$e'))],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No history yet.\nRun a check or log an event to get started.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _TimelineTile(item: items[i]),
            );
          },
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.item});

  final TimelineItem item;

  @override
  Widget build(BuildContext context) {
    final emergency = item.triageLevel == 'EMERGENCY';
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: emergency ? scheme.errorContainer : scheme.secondaryContainer,
        child: Icon(
          _iconFor(item),
          color: emergency ? scheme.onErrorContainer : scheme.onSecondaryContainer,
        ),
      ),
      title: Text(item.title),
      subtitle: item.subtitle == null ? null : Text(item.subtitle!),
      trailing: Text(shortDate(item.date), style: Theme.of(context).textTheme.bodySmall),
    );
  }

  static IconData _iconFor(TimelineItem item) {
    if (item.kind == TimelineKind.analysis) {
      return switch (item.triageLevel) {
        'EMERGENCY' => Icons.warning_amber_rounded,
        'MONITOR' => Icons.visibility_outlined,
        _ => Icons.health_and_safety_outlined,
      };
    }
    return switch (item.eventType) {
      'vaccination' => Icons.vaccines_outlined,
      'vet_visit' => Icons.local_hospital_outlined,
      'medication' => Icons.medication_outlined,
      'weight' => Icons.monitor_weight_outlined,
      _ => Icons.note_alt_outlined,
    };
  }
}
