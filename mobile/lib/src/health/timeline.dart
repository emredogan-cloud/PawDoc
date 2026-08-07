import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/supabase_providers.dart';
import 'health_event.dart';

/// What a timeline row represents.
enum TimelineKind { analysis, healthEvent }

/// A single chronological entry combining past AI analyses and manual health
/// events. Built by [TimelineItem.merge] (a pure function, unit-tested).
class TimelineItem {
  const TimelineItem({
    required this.kind,
    required this.date,
    required this.title,
    this.subtitle,
    this.detail,
    this.action,
    this.eventType,
    this.id,
    this.imageKey,
    this.payload,
  });

  final TimelineKind kind;
  final DateTime date;
  final String title;
  final String? subtitle;

  /// The second body line `health_timeline` draws under the subtitle — a
  /// medication's purpose, a vaccine's schedule, the vet's name.
  final String? detail;

  final String? action; // analyses only: the contract-v2 ladder value
  final String? eventType; // health events only

  /// The row's own id, so a card can open the thing it describes.
  final String? id;

  /// Analyses only: the R2 key of the photo that was checked.
  final String? imageKey;

  /// Analyses: `full_response`, so a past result can be reopened without a
  /// second round trip. Health events: `metadata`.
  final Map<String, dynamic>? payload;

  static String _actionTitle(String? action) => switch (action) {
        'GET_HELP_NOW' => 'Urgent — get help now',
        'CALL_TODAY' => 'Call your vet today',
        'BOOK_VISIT' => 'Book a routine visit',
        'WATCH_AND_RECHECK' => 'Watch and re-check',
        _ => 'AI check',
      };

  static TimelineItem? fromAnalysisRow(Map<String, dynamic> r) {
    final created = DateTime.tryParse((r['created_at'] as String?) ?? '');
    if (created == null) return null;
    final level = r['action'] as String?;
    return TimelineItem(
      kind: TimelineKind.analysis,
      date: created,
      title: _actionTitle(level),
      subtitle: (r['observation'] as String?) ?? (r['input_type'] as String?),
      action: level,
      id: r['id'] as String?,
      imageKey: r['input_storage_key'] as String?,
      payload: (r['full_response'] as Map?)?.cast<String, dynamic>(),
    );
  }

  static TimelineItem? fromHealthEventRow(Map<String, dynamic> r) {
    final d = DateTime.tryParse((r['event_date'] as String?) ?? '');
    if (d == null) return null;
    final type = (r['event_type'] as String?) ?? 'custom';
    final meta = (r['metadata'] as Map?)?.cast<String, dynamic>();
    final notes = r['notes'] as String?;
    return TimelineItem(
      kind: TimelineKind.healthEvent,
      date: d,
      title: healthEventLabel(type),
      subtitle: _headline(type, meta) ?? notes,
      detail: _headline(type, meta) == null ? null : notes,
      eventType: type,
      id: r['id'] as String?,
      payload: meta,
    );
  }

  /// The line a record leads with when its metadata says more than its note:
  /// the vaccine's name, the medicine's name and dose, the weight itself.
  static String? _headline(String type, Map<String, dynamic>? meta) {
    if (meta == null) return null;
    switch (type) {
      case 'vaccination':
        return (meta['vaccine_name'] as String?)?.trim().nullIfEmpty;
      case 'medication':
        final name = (meta['medication_name'] as String?)?.trim();
        final dose = (meta['dosage'] as String?)?.trim();
        if (name == null || name.isEmpty) return null;
        return (dose == null || dose.isEmpty) ? name : '$name · $dose';
      case 'weight':
        final kg = (meta['weight_kg'] as num?)?.toDouble();
        return kg == null ? null : '${kg.toStringAsFixed(1)} kg';
      case 'vet_visit':
      case 'lab_result':
        return (meta['reason'] as String?)?.trim().nullIfEmpty ??
            (meta['clinic'] as String?)?.trim().nullIfEmpty;
      default:
        return null;
    }
  }

  /// Merge analyses + health-event rows into one list, newest first.
  static List<TimelineItem> merge(
    List<Map<String, dynamic>> analyses,
    List<Map<String, dynamic>> events,
  ) {
    final items = <TimelineItem>[
      for (final a in analyses) ?fromAnalysisRow(a),
      for (final e in events) ?fromHealthEventRow(e),
    ];
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

/// The combined health timeline for a pet (analyses + manual events), RLS-scoped
/// to the signed-in user. `family` on petId so switching the active pet yields a
/// fresh timeline.
final healthTimelineProvider =
    FutureProvider.autoDispose.family<List<TimelineItem>, String>((ref, petId) async {
  final client = ref.watch(supabaseClientProvider);
  final analyses = await client
      .from('analyses')
      .select(
          'id, action, observation, input_type, input_storage_key, full_response, created_at')
      .eq('pet_id', petId)
      .order('created_at', ascending: false);
  final events = await client
      .from('health_events')
      .select('id, event_type, event_date, notes, metadata, created_at')
      .eq('pet_id', petId)
      .order('event_date', ascending: false);
  return TimelineItem.merge(
    (analyses as List).cast<Map<String, dynamic>>(),
    (events as List).cast<Map<String, dynamic>>(),
  );
});
