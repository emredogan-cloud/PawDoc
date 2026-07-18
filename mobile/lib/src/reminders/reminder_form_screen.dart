import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics.dart';
import '../core/dates.dart';
import '../core/pet_display.dart';
import '../notifications/local_notifications.dart';
import 'reminder.dart';
import 'reminders_repository.dart';

/// Create or edit a health reminder for a pet (type/label + due date). Writes
/// to the `reminders` table (RLS-scoped); delivery is an ON-DEVICE local
/// notification scheduled at save (evolution H2 — no push vendor, no cron).
/// The notification permission is asked contextually on first save.
class ReminderFormScreen extends ConsumerStatefulWidget {
  const ReminderFormScreen(
      {super.key, required this.petId, required this.petName, this.existing});

  final String petId;
  final String petName;

  /// When set, the form edits this reminder instead of creating one (J6).
  final Reminder? existing;

  @override
  ConsumerState<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends ConsumerState<ReminderFormScreen> {
  late final TextEditingController _label =
      TextEditingController(text: widget.existing?.reminderType ?? '');
  late DateTime _dueDate = widget.existing?.dueDate ??
      DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final type = _label.text.trim();
    if (type.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name the reminder first.')));
      return;
    }
    setState(() => _saving = true);
    try {
      // Contextual permission ask (never upfront). A denial doesn't block the
      // save — the reminder still lists in-app; only the notification is lost.
      await ref.read(localNotificationsProvider).ensurePermission();
      final repo = ref.read(remindersRepositoryProvider);
      final draft =
          Reminder(petId: widget.petId, reminderType: type, dueDate: _dueDate);
      if (widget.existing?.id != null) {
        await repo.update(widget.existing!.id!, draft, petName: widget.petName);
      } else {
        await repo.create(draft, petName: widget.petName);
      }
      await Analytics.reminderSet(type);
      ref.invalidate(remindersForPetProvider(widget.petId));
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the reminder. Please try again.')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(
              '${widget.existing == null ? 'New' : 'Edit'} reminder · ${petDisplayName(widget.petName)}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('What should we remind you about?'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final preset in kReminderPresets)
                ActionChip(
                  label: Text(preset),
                  onPressed: () => setState(() => _label.text = preset),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('reminder_label_field'),
            controller: _label,
            decoration: const InputDecoration(labelText: 'Reminder', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Due date'),
            subtitle: Text(shortDate(_dueDate)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _dueDate,
                firstDate: now,
                lastDate: DateTime(now.year + 5),
              );
              if (picked != null) setState(() => _dueDate = picked);
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('reminder_save_button'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Set reminder'),
          ),
        ],
      ),
    );
  }
}
