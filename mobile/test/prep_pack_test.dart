// Evolution Phase 5 — the Vet Visit Prep Pack builder (pure, unit-tested).
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/export/health_report.dart';
import 'package:pawdoc/src/health/health_event.dart';
import 'package:pawdoc/src/pets/pet.dart';

void main() {
  final pet = Pet(
    id: 'p1',
    userId: 'u1',
    name: 'Rex',
    species: 'dog',
    breed: 'Labrador',
    birthDate: DateTime(2022, 1, 1),
    sex: 'male',
    weightKg: 30,
    medicalNotes: 'Allergic to chicken',
  );

  test('the prep pack assembles every record section', () {
    final pack = buildVetVisitPrepPack(
      pet: pet,
      recentAnalyses: const [
        {
          'action': 'WATCH_AND_RECHECK',
          'observation': 'a raised, dark spot on the left flank',
          'created_at': '2026-07-10T10:00:00Z',
        },
      ],
      events: [
        HealthEvent(
            petId: 'p1',
            eventType: 'vaccination',
            eventDate: DateTime(2026, 5, 1),
            metadata: const {'vaccine_name': 'Rabies', 'next_due': '2027-05-01'}),
        HealthEvent(
            petId: 'p1',
            eventType: 'medication',
            eventDate: DateTime(2026, 6, 1),
            notes: 'Flea & tick tablet'),
        HealthEvent(
            petId: 'p1',
            eventType: 'weight',
            eventDate: DateTime(2026, 6, 1),
            metadata: const {'weight_kg': 29.5}),
        HealthEvent(
            petId: 'p1',
            eventType: 'weight',
            eventDate: DateTime(2026, 7, 1),
            metadata: const {'weight_kg': 30.0}),
      ],
      ownerQuestions: const ['Is his weight still healthy?'],
      now: DateTime(2026, 7, 17),
    );

    expect(pack, contains('# Vet Visit Prep — Rex'));
    expect(pack, contains('Medical notes: Allergic to chicken'));
    expect(pack, contains('WATCH_AND_RECHECK — a raised, dark spot'));
    expect(pack, contains('Rabies (next due 2027-05-01)'));
    expect(pack, contains('Flea & tick tablet'));
    expect(pack, contains('## Weight history'));
    expect(pack, contains('29.5 kg'));
    expect(pack, contains('Is his weight still healthy?'));
    expect(pack, contains('not a veterinary diagnosis'));
  });

  test('the pack never renders a verdict or condition vocabulary', () {
    final pack = buildVetVisitPrepPack(
        pet: pet, recentAnalyses: const [], events: const []);
    final lower = pack.toLowerCase();
    expect(lower.contains('likely normal'), isFalse);
    expect(lower.contains('diagnos'), isTrue,
        reason: 'only inside the NOT-a-diagnosis disclaimer');
    expect(lower.contains('not a veterinary diagnosis'), isTrue);
  });
}
