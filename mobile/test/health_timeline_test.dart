// Mockup `health_timeline` — the pet's health record.
//
// The reference is one of the more contract-hostile screens in the set: it
// grades the animal ("Health Score · 92 · Excellent"), names what the model
// looked at ("AI Skin Analysis"), grades the finding ("Low Risk"), asserts a
// cause ("Likely caused by licking") and closes a lab entry with an all-clear
// ("All parameters normal"). Every one of those is replaced; the layout is not.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/health/health_sections.dart';
import 'package:pawdoc/src/health/history_timeline_screen.dart';
import 'package:pawdoc/src/health/timeline.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';
import 'package:pawdoc/src/reminders/reminder.dart';
import 'package:pawdoc/src/reminders/reminders_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pet = Pet(
  id: 'p1',
  userId: 'u1',
  name: 'Buddy',
  species: 'dog',
  breed: 'Golden Retriever',
  weightKg: 28,
);

DateTime _daysAgo(int d) => DateTime.now().subtract(Duration(days: d));

List<TimelineItem> _sample() => [
      TimelineItem(
        kind: TimelineKind.analysis,
        date: _daysAgo(0),
        title: 'Call your vet today',
        subtitle: 'The owner reports visible redness on a front paw.',
        action: 'CALL_TODAY',
        id: 'a1',
        payload: const {
          'action': 'CALL_TODAY',
          'confidence': 0.8,
          'observation': 'The owner reports visible redness on a front paw.',
          'visible_symptoms': <String>[],
          'vets_look_for': <String>[],
          'watch_for': <String>[],
          'recommended_actions': <String>[],
          'urgency_timeframe': 'today',
          'disclaimer_required': true,
        },
      ),
      TimelineItem(
        kind: TimelineKind.healthEvent,
        date: _daysAgo(3),
        title: 'Vet Visit',
        subtitle: 'Routine check-up',
        detail: 'Seen at PawCare',
        eventType: 'vet_visit',
        id: 'e1',
        payload: const {'clinic': 'PawCare', 'reason': 'Routine check-up'},
      ),
      TimelineItem(
        kind: TimelineKind.healthEvent,
        date: _daysAgo(9),
        title: 'Medication',
        subtitle: 'NexGard Spectra · 11–22 kg',
        eventType: 'medication',
        id: 'e2',
        payload: const {
          'medication_name': 'NexGard Spectra',
          'dosage': '11–22 kg',
        },
      ),
      TimelineItem(
        kind: TimelineKind.healthEvent,
        date: _daysAgo(20),
        title: 'Vaccination',
        subtitle: 'DHPPi + Leptospirosis',
        eventType: 'vaccination',
        id: 'e3',
        payload: const {'vaccine_name': 'DHPPi + Leptospirosis'},
      ),
    ];

/// A handset surface. The default 800x600 test window is far shorter than any
/// phone, so on a tall scrolling screen everything below the fold is never
/// built and the assertions pass vacuously.
void _surface(WidgetTester tester, {double height = 2000}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

Widget _app({List<TimelineItem>? items, Object? error}) {
  SharedPreferences.setMockInitialValues(const {});
  return ProviderScope(
    overrides: [
      petsListProvider.overrideWith((ref) async => const [_pet]),
      remindersForPetProvider
          .overrideWith((ref, petId) async => const <Reminder>[]),
      healthTimelineProvider.overrideWith((ref, petId) async {
        if (error != null) throw error;
        return items ?? _sample();
      }),
    ],
    child: const MaterialApp(home: HealthHistoryScreen()),
  );
}

void main() {
  group('the mockup, drawn', () {
    testWidgets('every block the reference draws is present', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Health Timeline'), findsOneWidget);
      expect(find.byKey(const Key('module_pet_name')), findsOneWidget);
      expect(find.byKey(const Key('module_view_profile')), findsOneWidget);
      expect(find.byKey(const Key('timeline_care_score')), findsOneWidget);

      // Type rail + counted statistics.
      expect(find.byKey(const Key('health_filter_all')), findsOneWidget);
      expect(find.text('Events'), findsOneWidget);
      expect(find.text('4'), findsOneWidget); // four records
      expect(find.text('Vet visits'), findsOneWidget);

      // The rail's cards.
      expect(find.text('AI Health Check'), findsOneWidget);
      expect(find.text('Vet Visit'), findsOneWidget);
      expect(find.text('Medication'), findsOneWidget);
      expect(find.text('Vaccination'), findsOneWidget);

      // Per-card actions and the footers.
      expect(find.text('View Result'), findsOneWidget);
      expect(find.text('Visit Summary'), findsOneWidget);
      expect(find.text('View Details'), findsNWidgets(2));
      expect(find.byKey(const Key('timeline_add_card')), findsOneWidget);
      expect(find.byKey(const Key('log_event_fab')), findsOneWidget);
    });

    testWidgets('records group by day', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('an empty record invites the first entry', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(items: const []));
      await tester.pumpAndSettle();
      expect(find.textContaining('health story starts here'), findsOneWidget);
      expect(find.byKey(const Key('log_event_fab')), findsOneWidget);
    });

    testWidgets('a failed load says so and keeps the page usable',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(error: Exception('offline')));
      await tester.pumpAndSettle();
      expect(find.text('Could not load the record'), findsOneWidget);
      expect(find.byKey(const Key('log_event_fab')), findsOneWidget);
    });
  });

  group('filtering', () {
    testWidgets('the rail narrows the record to one type', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('health_filter_vet_visit')),
        120,
        scrollable: find.descendant(
          of: find.byType(HealthFilterChips),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('health_filter_vet_visit')));
      await tester.pumpAndSettle();

      expect(find.text('Vet Visit'), findsOneWidget);
      expect(find.text('AI Health Check'), findsNothing);
      expect(find.text('Vaccination'), findsNothing);
    });

    testWidgets('an empty filter explains itself instead of going blank',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('health_filter_weight')),
        140,
        scrollable: find.descendant(
          of: find.byType(HealthFilterChips),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('health_filter_weight')));
      await tester.pumpAndSettle();
      expect(find.text('Nothing filed here yet'), findsOneWidget);
    });
  });

  group('safety', () {
    testWidgets('the mockup\'s graded claims never render', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      for (final banned in [
        'Health Score',
        'Low Risk',
        'AI Skin Analysis',
        'Likely caused by',
        'All parameters normal',
        'Excellent',
      ]) {
        expect(find.textContaining(banned), findsNothing,
            reason: '"$banned" is a claim the product cannot make');
      }
    });

    testWidgets('the dial is the Care Score, and reads as record completeness',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Care Score'), findsOneWidget);
      // Banded in words about the record, never about the animal.
      expect(
          find.byWidgetPredicate((w) =>
              w is Text &&
              const ['Complete', 'Well kept', 'Filling in', 'Just started']
                  .contains(w.data)),
          findsOneWidget);
    });

    testWidgets('an AI check is chipped with the ladder, not a risk level',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Call today'), findsOneWidget);
    });
  });

  group('the record row model', () {
    test('a medication leads with its name and dose, note second', () {
      final item = TimelineItem.fromHealthEventRow({
        'id': 'e1',
        'event_type': 'medication',
        'event_date': '2026-05-17',
        'notes': 'Flea & tick prevention',
        'metadata': {'medication_name': 'NexGard Spectra', 'dosage': '11–22 kg'},
      })!;
      expect(item.subtitle, 'NexGard Spectra · 11–22 kg');
      expect(item.detail, 'Flea & tick prevention');
    });

    test('a weight record leads with the weight', () {
      final item = TimelineItem.fromHealthEventRow({
        'id': 'e2',
        'event_type': 'weight',
        'event_date': '2026-05-19',
        'notes': 'Feeling active',
        'metadata': {'weight_kg': 28.0},
      })!;
      expect(item.subtitle, '28.0 kg');
    });

    test('a record with no metadata falls back to its note', () {
      final item = TimelineItem.fromHealthEventRow({
        'id': 'e3',
        'event_type': 'custom',
        'event_date': '2026-05-19',
        'notes': 'Trimmed nails',
      })!;
      expect(item.subtitle, 'Trimmed nails');
      expect(item.detail, isNull);
    });

    test('an analysis carries what it needs to be reopened', () {
      final item = TimelineItem.fromAnalysisRow({
        'id': 'a1',
        'action': 'BOOK_VISIT',
        'observation': 'Observed limping.',
        'input_type': 'photo',
        'input_storage_key': 'checks/u1/x.jpg',
        'full_response': {'action': 'BOOK_VISIT'},
        'created_at': '2026-05-19T10:24:00Z',
      })!;
      expect(item.id, 'a1');
      expect(item.imageKey, 'checks/u1/x.jpg');
      expect(item.payload, isNotNull);
      expect(item.title, 'Book a routine visit');
    });
  });
}
