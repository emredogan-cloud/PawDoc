import '../core/dates.dart';
import '../health/health_event.dart';
import '../pets/pet.dart';

/// Build a clean, shareable Markdown health report for a pet — pet basics + the
/// most recent AI triage + recent manually-logged events — to hand to a real
/// veterinarian. Pure + unit-tested. (Markdown/text is shared via the OS sheet;
/// no PDF dependency — see the sub-PR report for the rationale.)
String buildHealthReport({
  required Pet pet,
  Map<String, dynamic>? latestAnalysis,
  required List<HealthEvent> events,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final b = StringBuffer();

  b.writeln('# PawDoc Health Report — ${pet.name}');
  b.writeln();
  b.writeln('Generated ${shortDate(today)} · share with your veterinarian.');
  b.writeln();

  b.writeln('## Pet');
  b.writeln('- Name: ${pet.name}');
  b.writeln('- Species: ${pet.species}');
  if (pet.breed != null && pet.breed!.trim().isNotEmpty) b.writeln('- Breed: ${pet.breed}');
  b.writeln('- Age: ${_ageLabel(pet.birthDate, today)}');
  if (pet.sex != null && pet.sex!.trim().isNotEmpty) b.writeln('- Sex: ${pet.sex}');
  if (pet.weightKg != null) b.writeln('- Weight: ${pet.weightKg} kg');
  b.writeln();

  b.writeln('## Most recent AI triage');
  if (latestAnalysis == null) {
    b.writeln('No AI analyses recorded yet.');
  } else {
    final created = DateTime.tryParse((latestAnalysis['created_at'] as String?) ?? '');
    final level = (latestAnalysis['action'] as String?) ?? 'UNKNOWN';
    final concern = (latestAnalysis['observation'] as String?) ?? '';
    if (created != null) b.writeln('- Date: ${shortDate(created)}');
    b.writeln('- Result: $level');
    if (concern.isNotEmpty) b.writeln('- Primary concern: $concern');
    final full = latestAnalysis['full_response'];
    if (full is Map) {
      final urgency = full['urgency_timeframe'] as String?;
      if (urgency != null && urgency.isNotEmpty) b.writeln('- Suggested urgency: $urgency');
      final actions = full['recommended_actions'];
      if (actions is List && actions.isNotEmpty) {
        b.writeln('- Suggested next steps:');
        for (final a in actions) {
          b.writeln('  - $a');
        }
      }
    }
  }
  b.writeln();

  b.writeln('## Recent health events');
  if (events.isEmpty) {
    b.writeln('No logged events.');
  } else {
    for (final e in events) {
      final note = (e.notes != null && e.notes!.trim().isNotEmpty) ? ' — ${e.notes}' : '';
      b.writeln('- ${shortDate(e.eventDate)} · ${healthEventLabel(e.eventType)}$note');
    }
  }
  b.writeln();

  b.writeln('---');
  b.writeln('This report is AI-assisted information from PawDoc, not a veterinary '
      'diagnosis. Please review with a licensed veterinarian.');

  return b.toString();
}

String _ageLabel(DateTime? birth, DateTime now) {
  if (birth == null) return 'Unknown';
  final days = now.difference(birth).inDays;
  if (days < 0) return 'Unknown';
  final years = days ~/ 365;
  final months = (days % 365) ~/ 30;
  if (years > 0) return '$years yr${years == 1 ? '' : 's'}${months > 0 ? ' $months mo' : ''}';
  if (months > 0) return '$months mo';
  return '$days days';
}
