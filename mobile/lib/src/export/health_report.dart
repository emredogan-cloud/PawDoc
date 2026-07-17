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

/// The Vet Visit Prep Pack (evolution Phase 5 / E1) — the record product's
/// centerpiece. Extends the health report with medical notes, medications &
/// vaccinations pulled out of the event stream, weight history, MULTIPLE
/// recent checks, and the owner's own questions. Pure + unit-tested.
String buildVetVisitPrepPack({
  required Pet pet,
  required List<Map<String, dynamic>> recentAnalyses,
  required List<HealthEvent> events,
  List<String> ownerQuestions = const [],
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final b = StringBuffer();

  b.writeln('# Vet Visit Prep — ${pet.name}');
  b.writeln();
  b.writeln('Prepared ${shortDate(today)} with PawDoc · for your veterinarian.');
  b.writeln();

  b.writeln('## Pet');
  b.writeln('- Name: ${pet.name}');
  b.writeln('- Species: ${pet.species}');
  if (pet.breed != null && pet.breed!.trim().isNotEmpty) {
    b.writeln('- Breed: ${pet.breed}');
  }
  b.writeln('- Age: ${_ageLabel(pet.birthDate, today)}');
  if (pet.sex != null && pet.sex!.trim().isNotEmpty) b.writeln('- Sex: ${pet.sex}');
  if (pet.weightKg != null) b.writeln('- Weight: ${pet.weightKg} kg');
  if (pet.medicalNotes != null && pet.medicalNotes!.trim().isNotEmpty) {
    b.writeln('- Medical notes: ${pet.medicalNotes}');
  }
  b.writeln();

  b.writeln('## Recent checks (what the owner recorded)');
  if (recentAnalyses.isEmpty) {
    b.writeln('No checks recorded.');
  } else {
    for (final a in recentAnalyses) {
      final created = DateTime.tryParse((a['created_at'] as String?) ?? '');
      final action = (a['action'] as String?) ?? '';
      final observation = (a['observation'] as String?) ?? '';
      b.writeln(
          '- ${created != null ? shortDate(created) : 'earlier'} · $action — $observation');
    }
  }
  b.writeln();

  final vaccines =
      events.where((e) => e.eventType == 'vaccination').toList(growable: false);
  final meds =
      events.where((e) => e.eventType == 'medication').toList(growable: false);
  final weights = events
      .where((e) =>
          e.eventType == 'weight' && (e.metadata?['weight_kg'] as num?) != null)
      .toList(growable: false);

  b.writeln('## Vaccinations');
  if (vaccines.isEmpty) {
    b.writeln('None logged.');
  } else {
    for (final v in vaccines) {
      final name = (v.metadata?['vaccine_name'] as String?) ?? v.notes ?? 'Vaccination';
      final nextDue = v.metadata?['next_due'] as String?;
      b.writeln('- ${shortDate(v.eventDate)} · $name'
          '${nextDue != null ? ' (next due $nextDue)' : ''}');
    }
  }
  b.writeln();

  b.writeln('## Medications');
  if (meds.isEmpty) {
    b.writeln('None logged.');
  } else {
    for (final m in meds) {
      b.writeln('- ${shortDate(m.eventDate)} · ${m.notes ?? 'Medication'}');
    }
  }
  b.writeln();

  if (weights.length >= 2) {
    b.writeln('## Weight history');
    for (final w in weights) {
      b.writeln('- ${shortDate(w.eventDate)} · ${(w.metadata!['weight_kg'] as num).toDouble()} kg');
    }
    b.writeln();
  }

  b.writeln('## Other recent events');
  final other = events
      .where((e) =>
          e.eventType != 'vaccination' &&
          e.eventType != 'medication' &&
          e.eventType != 'weight')
      .toList(growable: false);
  if (other.isEmpty) {
    b.writeln('None logged.');
  } else {
    for (final e in other) {
      final note =
          (e.notes != null && e.notes!.trim().isNotEmpty) ? ' — ${e.notes}' : '';
      b.writeln('- ${shortDate(e.eventDate)} · ${healthEventLabel(e.eventType)}$note');
    }
  }
  b.writeln();

  if (ownerQuestions.isNotEmpty) {
    b.writeln('## Questions from the owner');
    for (final q in ownerQuestions) {
      final t = q.trim();
      if (t.isNotEmpty) b.writeln('- $t');
    }
    b.writeln();
  }

  b.writeln('---');
  b.writeln('This summary is owner-recorded information organized by PawDoc, '
      'not a veterinary diagnosis. Please review with a licensed veterinarian.');

  return b.toString();
}
