import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics.dart';
import '../core/dates.dart';
import '../core/motion.dart';
import '../core/pet_display.dart';
import 'health_event.dart';
import 'health_events_repository.dart';
import 'timeline.dart';

/// Quick-add for a manual health event (vaccination, vet visit, medication,
/// weight, note). Inserts into `health_events` (RLS-scoped via the parent pet),
/// fires `health_event_logged`, then refreshes the timeline so the new entry
/// appears immediately.
class HealthEventFormScreen extends ConsumerStatefulWidget {
  const HealthEventFormScreen({super.key, required this.petId, required this.petName});

  final String petId;
  final String petName;

  @override
  ConsumerState<HealthEventFormScreen> createState() => _HealthEventFormScreenState();
}

class _HealthEventFormScreenState extends ConsumerState<HealthEventFormScreen> {
  String _type = kHealthEventTypes.first;
  DateTime _date = DateTime.now();
  final _notes = TextEditingController();
  final _weight = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    Map<String, dynamic>? metadata;
    if (_type == 'weight') {
      final kg = double.tryParse(_weight.text.trim());
      if (kg != null) metadata = {'weight_kg': kg};
    }
    final event = HealthEvent(
      petId: widget.petId,
      eventType: _type,
      eventDate: _date,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      metadata: metadata,
    );
    try {
      await ref.read(healthEventsRepositoryProvider).create(event);
      await Analytics.healthEventLogged(_type);
      ref.invalidate(healthTimelineProvider(widget.petId));
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the event. Please try again.')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Log event · ${petDisplayName(widget.petName)}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Type'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in kHealthEventTypes)
                ChoiceChip(
                  avatar: Icon(_eventIcon(t), size: 18),
                  label: Text(healthEventLabel(t)),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            subtitle: Text(shortDate(_date)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(now.year - 20),
                lastDate: now,
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          if (_type == 'weight') ...[
            const SizedBox(height: 8),
            TextField(
              key: const Key('event_weight_field'),
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            key: const Key('event_notes_field'),
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            key: const Key('event_save_button'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save event'),
          ),
        ],
      ),
    );
  }

  static IconData _eventIcon(String type) => switch (type) {
        'vaccination' => Icons.vaccines_outlined,
        'vet_visit' => Icons.local_hospital_outlined,
        'medication' => Icons.medication_outlined,
        'weight' => Icons.monitor_weight_outlined,
        _ => Icons.note_alt_outlined,
      };
}
