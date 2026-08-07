// Mockup `medication_tracker`.
//
// The reference prints "Medication Adherence · 96% · Excellent" and "100% ·
// This Week · On track" over nothing at all. Both figures here are counted
// from doses the owner actually ticked, both are null — not zero — when
// nothing was scheduled, and neither is banded with a value judgement.
//
// The schedule parser is the other half: it turns the sentence an owner typed
// ("Every 12 hours") into slots, and **fails to nothing** rather than guessing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/health/medication_plan.dart';
import 'package:pawdoc/src/health/medication_tracker_screen.dart';
import 'package:pawdoc/src/health/timeline.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';
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

TimelineItem _med(
  String id,
  String name, {
  required String schedule,
  String? dosage,
  String? form,
  String? purpose,
  DateTime? started,
  DateTime? endsOn,
}) =>
    TimelineItem(
      kind: TimelineKind.healthEvent,
      date: started ?? _daysAgo(10),
      title: 'Medication',
      subtitle: name,
      eventType: 'medication',
      id: id,
      payload: {
        'medication_name': name,
        'schedule': schedule,
        'dosage': ?dosage,
        'form': ?form,
        'purpose': ?purpose,
        if (endsOn != null)
          'ends_on': endsOn.toIso8601String().split('T').first,
      },
    );

List<TimelineItem> _sample() => [
      _med('m1', 'Amoxicillin',
          schedule: 'Every 12 hours',
          dosage: '250 mg',
          form: 'Tablet',
          purpose: 'Bacterial infection'),
      _med('m2', 'NexGard Spectra',
          schedule: 'Every 30 days',
          dosage: '11–22 kg',
          form: 'Chewable',
          purpose: 'Flea & tick prevention'),
      _med('m3', 'Metronidazole',
          schedule: 'Every 12 hours',
          form: 'Tablet',
          started: _daysAgo(40),
          endsOn: _daysAgo(20)),
    ];

void _surface(WidgetTester tester, {double height = 2600}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

Widget _app({List<TimelineItem>? items}) {
  SharedPreferences.setMockInitialValues(const {});
  return ProviderScope(
    overrides: [
      petsListProvider.overrideWith((ref) async => const [_pet]),
      healthTimelineProvider
          .overrideWith((ref, petId) async => items ?? _sample()),
    ],
    child: const MaterialApp(home: MedicationTrackerScreen()),
  );
}

void main() {
  group('the schedule parser', () {
    test('reads the shapes a label is written in', () {
      expect(MedicationSchedule.parse('Every 12 hours').dosesPerDay, 2);
      expect(MedicationSchedule.parse('every 8 hrs').dosesPerDay, 3);
      expect(MedicationSchedule.parse('Twice daily').dosesPerDay, 2);
      expect(MedicationSchedule.parse('3 times a day').dosesPerDay, 3);
      expect(MedicationSchedule.parse('Once daily').dosesPerDay, 1);
      expect(MedicationSchedule.parse('Every 30 days').intervalDays, 30);
      expect(MedicationSchedule.parse('Weekly').intervalDays, 7);
      expect(MedicationSchedule.parse('Monthly').intervalDays, 30);
    });

    test('fails to nothing rather than guessing', () {
      for (final text in [null, '', 'when the moon is full', 'ask the vet']) {
        final parsed = MedicationSchedule.parse(text);
        expect(parsed.isScheduled, isFalse, reason: 'parsed "$text"');
        expect(parsed.slotsOn(DateTime(2026, 8, 7), DateTime(2026, 8, 1)),
            isEmpty);
      }
    });

    test('as-needed is a schedule with no slots, not an unknown one', () {
      final parsed = MedicationSchedule.parse('As needed');
      expect(parsed.frequency, MedFrequency.asNeeded);
      expect(parsed.isScheduled, isFalse);
    });

    test('a twice-daily course puts its doses 12 hours apart', () {
      final parsed = MedicationSchedule.parse('Every 12 hours');
      final slots =
          parsed.slotsOn(DateTime(2026, 8, 7), DateTime(2026, 8, 1));
      expect(slots.length, 2);
      expect(slots.first.hour, MedicationSchedule.firstDoseHour);
      expect(slots.last.hour, MedicationSchedule.firstDoseHour + 12);
    });

    test('an every-N-days course only lands on its own days', () {
      final parsed = MedicationSchedule.parse('Every 30 days');
      final start = DateTime(2026, 5, 15);
      expect(parsed.slotsOn(DateTime(2026, 5, 15), start), hasLength(1));
      expect(parsed.slotsOn(DateTime(2026, 5, 16), start), isEmpty);
      expect(parsed.slotsOn(DateTime(2026, 6, 14), start), hasLength(1));
    });

    test('nothing is due before the course starts', () {
      final parsed = MedicationSchedule.parse('Every 12 hours');
      expect(
          parsed.slotsOn(DateTime(2026, 8, 1), DateTime(2026, 8, 5)), isEmpty);
    });
  });

  group('adherence', () {
    test('is null, not zero, when nothing was scheduled', () {
      final none = Adherence.over(const [], const {},
          from: _daysAgo(7), to: DateTime.now());
      expect(none.percent, isNull);
      expect(none.band, 'No doses scheduled');
      expect(none.tileBand, 'None due');
    });

    test('counts only doses whose time has passed', () {
      final med = Medication.fromTimelineItem(
          _med('m1', 'Amoxicillin', schedule: 'Every 12 hours'))!;
      // Midnight "now" means neither of the day's 08:00/20:00 doses is due yet.
      final midnight = DateTime(2026, 8, 7);
      final a = Adherence.over([med], const {},
          from: midnight, to: midnight);
      expect(a.expected, 0);
    });

    test('never bands the owner "Excellent"', () {
      for (final pair in [(10, 10), (8, 10), (5, 10), (1, 10)]) {
        final band = Adherence(taken: pair.$1, expected: pair.$2).band;
        expect(band, isNot(contains('Excellent')));
        expect(band, isNot(contains('Poor')));
      }
    });
  });

  group('the mockup, drawn', () {
    testWidgets('every block the reference draws is present', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Medication Tracker'), findsOneWidget);
      expect(find.byKey(const Key('module_pet_name')), findsOneWidget);
      expect(find.byKey(const Key('medication_adherence')), findsOneWidget);

      expect(find.text('Active medicines'), findsOneWidget);
      expect(find.text('Doses today'), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);

      expect(find.text('Current Medications'), findsOneWidget);
      expect(find.byKey(const Key('medication_row_m1')), findsOneWidget);
      expect(find.byKey(const Key('medication_row_m2')), findsOneWidget);
      expect(find.text('Today’s Schedule'), findsOneWidget);
      expect(find.text('Medication History'), findsOneWidget);
      expect(find.byKey(const Key('medication_add_card')), findsOneWidget);
      expect(find.text('Tips for success'), findsOneWidget);
      expect(find.byKey(const Key('medication_add_cta')), findsOneWidget);
      expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget);
    });

    testWidgets('a finished course moves to history, not the plan',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      // m3 ended twenty days ago.
      expect(find.byKey(const Key('medication_row_m3')), findsOneWidget);
      expect(find.byKey(const Key('medication_none_finished')), findsNothing);
    });

    testWidgets('an empty plan explains what would fill it', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(items: const []));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('medication_none_active')), findsOneWidget);
      expect(find.byKey(const Key('medication_none_today')), findsOneWidget);
      expect(find.byKey(const Key('medication_add_cta')), findsOneWidget);
    });

    testWidgets('a medicine with an unreadable schedule is still listed',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(items: [
        _med('m9', 'Joint supplement', schedule: 'ask the vet'),
      ]));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('medication_row_m9')), findsOneWidget);
      expect(find.text('ask the vet'), findsOneWidget);
      // …with nothing to tick.
      expect(find.byKey(const Key('medication_none_today')), findsOneWidget);
    });
  });

  group('ticking a dose', () {
    testWidgets('marks it taken, and un-marks it', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(items: [
        _med('m1', 'Amoxicillin',
            schedule: 'Every 12 hours', form: 'Tablet', dosage: '250 mg'),
      ]));
      await tester.pumpAndSettle();

      final mark = find.text('Mark as taken');
      if (mark.evaluate().isEmpty) {
        // Before 08:00 every dose is still upcoming — nothing to tick, which
        // is itself correct behaviour.
        expect(find.text('Upcoming'), findsWidgets);
        return;
      }
      await tester.tap(mark.first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Taken '), findsOneWidget);

      await tester.tap(find.textContaining('Taken ').first);
      await tester.pumpAndSettle();
      expect(find.text('Mark as taken'), findsWidgets);
    });

    testWidgets('the surface says where the ticks are kept', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.textContaining('kept on this device'), findsOneWidget);
    });
  });

  group('safety', () {
    testWidgets('nothing grades the owner or the animal', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      // The mockup's tips card *instructs* ("Give medications with food if
      // recommended"). Dosing guidance is not the app's to give; the shipped
      // card points at the label and the vet instead.
      for (final banned in [
        'Excellent',
        'Great job',
        'Give medications',
        'praise',
        'Adherence',
      ]) {
        expect(find.textContaining(banned), findsNothing,
            reason: '"$banned" is a claim or a judgement the app must not make');
      }
    });

    testWidgets('form tints never borrow an action-ladder hue', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(MedicationTrackerScreen));
      const ladder = [
        Color(0xFFFF5A52), // emergencyDark
        Color(0xFFC62828), // emergencyLight
        Color(0xFFFFC233), // monitorDark
        Color(0xFFFFB300), // monitorLight
        Color(0xFF1565C0), // actionBookVisit
        Color(0xFF455A64), // actionWatch
      ];
      for (final form in [
        'Tablet',
        'Chewable',
        'Liquid',
        'Topical',
        'Injection',
        null,
      ]) {
        expect(ladder.contains(medicationTint(context, form)), isFalse,
            reason: 'the $form tint reads as a severity signal');
      }
    });
  });
}
