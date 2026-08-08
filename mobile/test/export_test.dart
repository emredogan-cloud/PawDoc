import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/export/health_report.dart';
import 'package:pawdoc/src/health/health_event.dart';
import 'package:pawdoc/src/pets/pet.dart';

void main() {
  _queryContract();

  final pet = Pet(
    userId: '',
    name: 'Rex',
    species: 'dog',
    breed: 'Labrador',
    birthDate: DateTime(2022, 1, 1),
    sex: 'M',
    weightKg: 30,
  );

  test('full report includes pet info, latest triage, events, and the disclaimer', () {
    final report = buildHealthReport(
      pet: pet,
      latestAnalysis: const {
        'action': 'GET_HELP_NOW',
        'observation': 'Possible bloat',
        'created_at': '2026-05-20T10:00:00Z',
        'full_response': {
          'urgency_timeframe': 'immediately',
          'recommended_actions': ['Go to a vet now'],
        },
      },
      events: [
        HealthEvent(petId: 'p1', eventType: 'vaccination', eventDate: DateTime(2026, 5, 1), notes: 'Rabies'),
      ],
      now: DateTime(2026, 5, 27),
    );

    expect(report, contains('# PawDoc Health Report — Rex'));
    expect(report, contains('Species: dog'));
    expect(report, contains('Breed: Labrador'));
    expect(report, contains('Result: GET_HELP_NOW'));
    expect(report, contains('Possible bloat'));
    expect(report, contains('Go to a vet now'));
    expect(report, contains('Vaccination'));
    expect(report, contains('Rabies'));
    expect(report, contains('not a veterinary diagnosis'));
  });

  test('gracefully handles no analysis and no events', () {
    final report = buildHealthReport(pet: pet, latestAnalysis: null, events: const []);
    expect(report, contains('No AI checks recorded yet.'));
    // V-22 / review §4.2: a vet must be able to tell, line by line, what the
    // model produced from what the owner recorded. Both markers are required
    // even in the empty case, because that is when the sections look most alike.
    expect(report, contains('Source: PawDoc AI'));
    expect(report, contains('Not examined by a veterinarian'));
    expect(report, contains('Source: entered by the owner'));
    expect(report, contains('No logged events.'));
  });
}

// ---------------------------------------------------------------------------
// The query that feeds the builder.
// ---------------------------------------------------------------------------
//
// The two tests above hand `buildHealthReport` a map with the right keys, so
// they pass whatever the database is actually asked for. That gap hid a real
// bug for three weeks: the contract-v2 migration (20260717130000) renamed
// `triage_level` -> `action` and `primary_concern` -> `observation`, the
// builder was updated with it, and `health_report_service.dart` was not. The
// select 400ed, and "Share the record as text" — a capability
// `entitlements.dart` lists as included on BOTH plans — threw for every user.
//
// Device-found while walking the new Privacy & Security screen. This closes
// the gap: every key the builder reads out of `latestAnalysis` must be a
// column the service actually selects.
void _queryContract() {
  group('the export query matches what the builder reads', () {
    final builder =
        File('lib/src/export/health_report.dart').readAsStringSync();
    final service =
        File('lib/src/export/health_report_service.dart').readAsStringSync();

    final selected = RegExp(r"\.select\('([^']+)'\)")
        .allMatches(service)
        .expand((m) => m.group(1)!.split(','))
        .map((c) => c.trim())
        .toSet();

    final read = RegExp(r"latestAnalysis\['(\w+)'\]")
        .allMatches(builder)
        .map((m) => m.group(1)!)
        .toSet();

    test('the builder reads at least the four documented fields', () {
      expect(read, containsAll(['action', 'observation', 'created_at']));
    });

    for (final column in const [
      'action',
      'observation',
      'created_at',
      'full_response',
    ]) {
      test('the service selects `$column`', () {
        expect(selected, contains(column),
            reason: 'buildHealthReport reads $column out of the analysis row; '
                'if the query does not ask for it the export is silently '
                'wrong, and if the column was renamed the query 400s and the '
                'export throws');
      });
    }

    test('the pre-contract-v2 column names are gone', () {
      // Comments stripped: the fix's own note names both old columns in order
      // to explain why they are wrong, exactly as `safety_copy_test` does.
      final code = service
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(code.contains('triage_level'), isFalse);
      expect(code.contains('primary_concern'), isFalse);
    });

    test('every key the builder reads is selected', () {
      expect(read.difference(selected), isEmpty,
          reason: 'the builder reads a field the query never asked for');
    });
  });
}
