import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/dates.dart';
import '../pets/pet.dart';
import 'health_event.dart';
import 'health_events_repository.dart';
import 'health_sections.dart';
import 'history_timeline_screen.dart';
import 'timeline.dart';

/// What "View Details" / "Visit Summary" on a timeline card opens: everything
/// the record actually holds, plus the two things you can do to it.
///
/// The mockup hangs those pills off every card without saying where they go.
/// A pill that opens nothing is a false affordance, and a record the owner
/// filed is exactly the kind of thing they should be able to read back in
/// full — including the fields the timeline row had to truncate.
Future<void> showHealthRecordDetail(
  BuildContext context,
  WidgetRef ref, {
  required TimelineItem item,
  required Pet pet,
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => _RecordDetailSheet(
      item: item,
      pet: pet,
      onChanged: onChanged,
    ),
  );
}

class _RecordDetailSheet extends ConsumerStatefulWidget {
  const _RecordDetailSheet({
    required this.item,
    required this.pet,
    required this.onChanged,
  });

  final TimelineItem item;
  final Pet pet;
  final VoidCallback onChanged;

  @override
  ConsumerState<_RecordDetailSheet> createState() => _RecordDetailSheetState();
}

class _RecordDetailSheetState extends ConsumerState<_RecordDetailSheet> {
  bool _deleting = false;

  /// Metadata keys the record screens write, in the order they read best.
  static const _fields = <String, (String, IconData)>{
    'clinic': ('Clinic', LucideIcons.building2),
    'veterinarian': ('Veterinarian', LucideIcons.userRound),
    'reason': ('Reason', LucideIcons.clipboardList),
    'vaccine_name': ('Vaccine', LucideIcons.syringe),
    'vaccine_class': ('Class', LucideIcons.shieldCheck),
    'next_due': ('Next due', LucideIcons.calendarClock),
    'medication_name': ('Medication', LucideIcons.pill),
    'dosage': ('Dose', LucideIcons.beaker),
    'form': ('Form', LucideIcons.tablets),
    'schedule': ('Schedule', LucideIcons.repeat2),
    'purpose': ('Purpose', LucideIcons.target),
    'ends_on': ('Ends', LucideIcons.calendarX),
    'weight_kg': ('Weight', LucideIcons.scale),
  };

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this record?'),
        content: const Text(
            'It will be removed from the health record and from any report '
            'you export. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            key: const Key('record_delete_confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Delete',
                style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || widget.item.id == null || !mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _deleting = true);
    try {
      await ref.read(healthEventsRepositoryProvider).delete(widget.item.id!);
      widget.onChanged();
      navigator.pop();
      messenger
          .showSnackBar(const SnackBar(content: Text('Record deleted.')));
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        messenger.showSnackBar(const SnackBar(
            content: Text('Could not delete the record. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final meta = item.payload ?? const <String, dynamic>{};
    final rows = <Widget>[
      HealthDetailRow(
        label: 'Date',
        value: shortDate(item.date),
        icon: LucideIcons.calendar,
      ),
      for (final entry in _fields.entries)
        if (_present(meta[entry.key]))
          HealthDetailRow(
            label: entry.value.$1,
            value: _format(entry.key, meta[entry.key]),
            icon: entry.value.$2,
          ),
      if (_present(item.detail) && item.detail != item.subtitle)
        HealthDetailRow(
          label: 'Notes',
          value: item.detail!,
          icon: LucideIcons.notebookPen,
        )
      else if (_present(item.subtitle) && meta.isEmpty)
        HealthDetailRow(
          label: 'Notes',
          value: item.subtitle!,
          icon: LucideIcons.notebookPen,
        ),
    ];

    return HealthSheet(
      scrollable: true,
      children: [
        Row(children: [
          HealthGlyphDisc(
            icon: timelineIcon(item),
            tint: timelineTint(context, item),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(healthEventLabel(item.eventType ?? 'custom'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                Text('Filed for ${widget.pet.name}',
                    style: const TextStyle(
                        color: HealthTone.muted, fontSize: 11.5)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: HealthTone.raised,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: rows),
        ),
        // Owner-entered, and labelled as such — the same provenance rule the
        // exported report carries (V-22). A vet reading this must be able to
        // tell what the app concluded from what the owner typed.
        Row(children: [
          const Icon(LucideIcons.userPen, size: 12, color: HealthTone.faint),
          const SizedBox(width: 6),
          const Expanded(
            child: Text('Entered by the owner. PawDoc did not review it.',
                style: TextStyle(color: HealthTone.faint, fontSize: 10.5)),
          ),
        ]),
        if (item.id != null)
          HealthRecordRow(
            key: const Key('record_delete'),
            leading: Icon(LucideIcons.trash2,
                size: 20, color: Theme.of(context).colorScheme.error),
            title: _deleting ? 'Deleting…' : 'Delete this record',
            subtitle: 'Removes it from the record and from exports',
            chevron: false,
            onTap: _deleting ? null : _delete,
          ),
      ],
    );
  }

  static bool _present(Object? v) =>
      v != null && v.toString().trim().isNotEmpty;

  static String _format(String key, Object? v) {
    if (key == 'weight_kg') {
      final kg = (v as num).toDouble();
      return '${kg.toStringAsFixed(1)} kg';
    }
    if (key == 'next_due' || key == 'ends_on') {
      final d = DateTime.tryParse(v.toString());
      return d == null ? v.toString() : shortDate(d);
    }
    return v.toString();
  }
}
