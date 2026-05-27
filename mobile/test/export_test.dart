import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/export/health_report.dart';
import 'package:pawdoc/src/health/health_event.dart';
import 'package:pawdoc/src/pets/pet.dart';

void main() {
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
        'triage_level': 'EMERGENCY',
        'primary_concern': 'Possible bloat',
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
    expect(report, contains('Result: EMERGENCY'));
    expect(report, contains('Possible bloat'));
    expect(report, contains('Go to a vet now'));
    expect(report, contains('Vaccination'));
    expect(report, contains('Rabies'));
    expect(report, contains('not a veterinary diagnosis'));
  });

  test('gracefully handles no analysis and no events', () {
    final report = buildHealthReport(pet: pet, latestAnalysis: null, events: const []);
    expect(report, contains('No AI analyses recorded yet.'));
    expect(report, contains('No logged events.'));
  });
}
