import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/health/breed_insights.dart';
import 'package:pawdoc/src/health/health_event.dart';
import 'package:pawdoc/src/health/timeline.dart';

void main() {
  group('breed insights', () {
    test('exact breed match returns the breed-specific list', () {
      final list = insightsForPet(breed: 'Labrador Retriever', species: 'dog');
      expect(list, isNotEmpty);
      expect(list.any((i) => i.title.contains('waistline')), isTrue);
    });

    test('partial breed match still resolves', () {
      final list = insightsForPet(breed: 'lab', species: 'dog');
      expect(list.any((i) => i.title.contains('waistline')), isTrue);
    });

    test('unknown breed falls back to species', () {
      expect(insightsForPet(breed: 'Unobtainium Hound', species: 'cat'), isNotEmpty);
    });

    test('unknown species falls back to a generic list', () {
      expect(insightsForPet(breed: null, species: 'axolotl'), isNotEmpty);
    });

    test('rotates deterministically by day and advances with offset', () {
      final d = DateTime(2026, 1, 1);
      final a = rotatingInsight(species: 'dog', breed: 'Beagle', now: d, offset: 0);
      final aAgain = rotatingInsight(species: 'dog', breed: 'Beagle', now: d, offset: 0);
      final b = rotatingInsight(species: 'dog', breed: 'Beagle', now: d, offset: 1);
      expect(a.title, aAgain.title); // stable within a day
      expect(a.title, isNot(b.title)); // tapping advances (Beagle has 2 tips)
    });

    test('no diagnosis/diagnose language anywhere (safety posture)', () {
      void assertClean(BreedInsight i) {
        expect('${i.title} ${i.body}'.toLowerCase().contains('diagnos'), isFalse,
            reason: 'breed insight must never use diagnosis language: ${i.title}');
      }

      for (final species in const ['dog', 'cat', 'rabbit', 'bird', 'reptile', 'other']) {
        insightsForPet(breed: null, species: species).forEach(assertClean);
      }
      for (final breed in const [
        'Labrador Retriever', 'German Shepherd', 'Golden Retriever', 'French Bulldog',
        'Dachshund', 'Persian', 'Maine Coon', 'Siamese', 'Ragdoll', 'British Shorthair',
      ]) {
        insightsForPet(breed: breed, species: 'dog').forEach(assertClean);
      }
    });
  });

  group('timeline merge', () {
    test('interleaves analyses + events, newest first', () {
      final analyses = <Map<String, dynamic>>[
        {
          'triage_level': 'NORMAL', 'primary_concern': 'Mild limp',
          'input_type': 'photo', 'created_at': '2026-01-10T09:00:00Z',
        },
        {
          'triage_level': 'EMERGENCY', 'primary_concern': 'Bloat',
          'input_type': 'text', 'created_at': '2026-01-05T09:00:00Z',
        },
      ];
      final events = <Map<String, dynamic>>[
        {'event_type': 'vaccination', 'event_date': '2026-01-08', 'notes': 'Rabies'},
      ];
      final merged = TimelineItem.merge(analyses, events);
      expect(merged.length, 3);
      expect(merged[0].triageLevel, 'NORMAL'); // 2026-01-10
      expect(merged[1].kind, TimelineKind.healthEvent); // 2026-01-08
      expect(merged[2].triageLevel, 'EMERGENCY'); // 2026-01-05
      expect(merged[2].title, 'Emergency triage');
    });

    test('drops rows with invalid/missing dates', () {
      final merged = TimelineItem.merge(
        [
          {'triage_level': 'NORMAL', 'created_at': null},
        ],
        [
          {'event_type': 'weight', 'event_date': 'not-a-date'},
        ],
      );
      expect(merged, isEmpty);
    });
  });

  group('HealthEvent model', () {
    test('toColumns omits user_id; date is date-only', () {
      final e = HealthEvent(
        petId: 'p1', eventType: 'weight',
        eventDate: DateTime(2026, 2, 3, 14, 30), notes: 'x',
      );
      final cols = e.toColumns();
      expect(cols.containsKey('user_id'), isFalse); // health_events has no user_id
      expect(cols['pet_id'], 'p1');
      expect(cols['event_date'], '2026-02-03');
    });

    test('fromJson parses a row', () {
      final e = HealthEvent.fromJson(const {
        'id': 'e1', 'pet_id': 'p1', 'event_type': 'vet_visit',
        'event_date': '2026-02-03', 'notes': 'checkup',
        'metadata': {'k': 'v'}, 'created_at': '2026-02-03T10:00:00Z',
      });
      expect(e.eventType, 'vet_visit');
      expect(e.eventDate, DateTime(2026, 2, 3));
      expect(e.metadata!['k'], 'v');
    });

    test('healthEventLabel maps types', () {
      expect(healthEventLabel('vaccination'), 'Vaccination');
      expect(healthEventLabel('vet_visit'), 'Vet visit');
      expect(healthEventLabel('custom'), 'Note');
    });
  });
}
