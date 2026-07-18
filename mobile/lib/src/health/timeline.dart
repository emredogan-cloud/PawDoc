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
    this.action,
    this.eventType,
  });

  final TimelineKind kind;
  final DateTime date;
  final String title;
  final String? subtitle;
  final String? action; // analyses only: the contract-v2 ladder value
  final String? eventType; // health events only

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
    );
  }

  static TimelineItem? fromHealthEventRow(Map<String, dynamic> r) {
    final d = DateTime.tryParse((r['event_date'] as String?) ?? '');
    if (d == null) return null;
    final type = (r['event_type'] as String?) ?? 'custom';
    return TimelineItem(
      kind: TimelineKind.healthEvent,
      date: d,
      title: healthEventLabel(type),
      subtitle: r['notes'] as String?,
      eventType: type,
    );
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

/// The combined health timeline for a pet (analyses + manual events), RLS-scoped
/// to the signed-in user. `family` on petId so switching the active pet yields a
/// fresh timeline.
final healthTimelineProvider =
    FutureProvider.autoDispose.family<List<TimelineItem>, String>((ref, petId) async {
  final client = ref.watch(supabaseClientProvider);
  final analyses = await client
      .from('analyses')
      .select('action, observation, input_type, created_at')
      .eq('pet_id', petId)
      .order('created_at', ascending: false);
  final events = await client
      .from('health_events')
      .select('event_type, event_date, notes, created_at')
      .eq('pet_id', petId)
      .order('event_date', ascending: false);
  return TimelineItem.merge(
    (analyses as List).cast<Map<String, dynamic>>(),
    (events as List).cast<Map<String, dynamic>>(),
  );
});
