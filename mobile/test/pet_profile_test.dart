// Mockup `pet_profile`.
//
// The most contract-hostile reference since the result screens. It grades the
// animal four times:
//
//   "Health Score · 92 · Excellent"          → the Care Score (D-2)
//   "Vaccinations · 12/12 · Up to date"      → what is on file
//   "Allergies · 2 · Known"                  → the owner's own notes, marked
//   "Conditions · 0 · None · Great!"         → gone; `safety_copy_test` bans
//                                              the literal string
//
// It also prints a blood type, a microchip number, a coat colour and a
// neutered flag. `pets` has no column for any of them, so the row keeps its
// place and says *Soon* rather than showing an invented value.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/health/timeline.dart';
import 'package:pawdoc/src/home/home_sections.dart';
import 'package:pawdoc/src/memories/memories_repository.dart';
import 'package:pawdoc/src/memories/memory.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pet_profile_screen.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';
import 'package:pawdoc/src/reminders/reminder.dart';
import 'package:pawdoc/src/reminders/reminders_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _pet = Pet(
  id: 'p1',
  userId: 'u1',
  name: 'Buddy',
  species: 'dog',
  breed: 'Golden Retriever',
  sex: 'male',
  weightKg: 28,
  birthDate: DateTime(2022, 5, 19),
  medicalNotes: 'Sensitive to chicken. Nervous at the clinic.',
);

DateTime _daysAgo(int d) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).subtract(Duration(days: d));
}

TimelineItem _event(String id, String type, {int daysAgo = 10}) => TimelineItem(
      kind: TimelineKind.healthEvent,
      date: _daysAgo(daysAgo),
      title: type,
      eventType: type,
      id: id,
    );

List<TimelineItem> _sample() => [
      _event('e1', 'vaccination'),
      _event('e2', 'vaccination', daysAgo: 200),
      _event('e3', 'medication', daysAgo: 5),
      _event('e4', 'vet_visit', daysAgo: 30),
      _event('e5', 'note', daysAgo: 40),
      TimelineItem(
        kind: TimelineKind.analysis,
        date: _daysAgo(2),
        title: 'Watch and re-check',
        action: 'WATCH_AND_RECHECK',
        id: 'a1',
      ),
    ];

void _surface(WidgetTester tester, {double height = 2800}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

Widget _app({
  Pet? pet,
  List<TimelineItem>? items,
  List<Reminder>? reminders,
  List<Memory>? memories,
}) {
  SharedPreferences.setMockInitialValues(const {});
  final p = pet ?? _pet;
  return ProviderScope(
    overrides: [
      petsListProvider.overrideWith((ref) async => [p]),
      healthTimelineProvider.overrideWith((ref, petId) async => items ?? []),
      remindersForPetProvider
          .overrideWith((ref, petId) async => reminders ?? const []),
      memoriesListProvider
          .overrideWith((ref, petId) async => memories ?? const []),
    ],
    child: MaterialApp(home: PetProfileScreen(pet: p)),
  );
}

void main() {
  group('the Care Score band is about the record', () {
    test('never grades the animal or the owner', () {
      for (final score in [0, 30, 50, 80, 100]) {
        final band = careBand(score);
        for (final banned in [
          'Excellent',
          'Great',
          'Good',
          'Poor',
          'Bad',
          'Healthy',
        ]) {
          expect(band.toLowerCase(), isNot(contains(banned.toLowerCase())),
              reason: '"$band" reads as a verdict, not a record state');
        }
      }
    });

    test('bands ascend and describe completeness', () {
      expect(careBand(100), 'Complete');
      expect(careBand(80), 'Well kept');
      expect(careBand(50), 'Filling in');
      expect(careBand(10), 'Just started');
    });
  });

  group('the mockup, drawn', () {
    testWidgets('every block the reference draws is present', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Pet Profile'), findsOneWidget);
      expect(find.byKey(const Key('profile_name')), findsOneWidget);
      expect(find.byKey(const Key('profile_photo')), findsOneWidget);
      expect(find.byKey(const Key('profile_care_score')), findsOneWidget);
      expect(find.byKey(const Key('profile_traits')), findsOneWidget);
      expect(find.byKey(const Key('profile_edit')), findsOneWidget);

      for (final tab in ['overview', 'health', 'records', 'reminders', 'files']) {
        expect(find.byKey(Key('profile_tab_$tab')), findsOneWidget);
      }

      expect(find.text('Basic Information'), findsOneWidget);
      expect(find.byKey(const Key('profile_basic_info')), findsOneWidget);
      expect(find.byKey(const Key('profile_show_more')), findsOneWidget);
      expect(find.byKey(const Key('profile_card_vaccines')), findsOneWidget);
      expect(find.byKey(const Key('profile_card_meds')), findsOneWidget);
      expect(find.text('About Buddy'), findsOneWidget);
      expect(find.byKey(const Key('profile_add_photo')), findsOneWidget);
      expect(find.byKey(const Key('profile_find_vet')), findsOneWidget);
      expect(find.byKey(const Key('profile_family')), findsOneWidget);
      expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget);
    });

    testWidgets('Basic Information reads the row', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Golden Retriever'), findsWidgets);
      expect(find.text('Male'), findsWidgets);
      expect(find.text('May 19, 2022'), findsOneWidget);
      // Twice on purpose: the hero states it and Basic Information lists it,
      // exactly as the reference does.
      expect(find.text('28 kg'), findsNWidgets(2));
    });

    testWidgets('an empty row says "Not set", never a guess', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(
        pet: const Pet(id: 'p1', userId: 'u1', name: 'Rex', species: 'cat'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Not set'), findsWidgets);
    });

    testWidgets('Show more reveals the rest and the not-yet slot',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(items: _sample()));
      await tester.pumpAndSettle();

      expect(find.text('Microchip & colour'), findsNothing);
      await tester.tap(find.byKey(const Key('profile_show_more')));
      await tester.pumpAndSettle();

      expect(find.text('Records on file'), findsOneWidget);
      expect(find.text('Microchip & colour'), findsOneWidget);
      expect(find.text('Blood type'), findsOneWidget);
      expect(find.text('Show less'), findsOneWidget);
    });

    testWidgets('the four cards are counted off the timeline', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(items: _sample()));
      await tester.pumpAndSettle();
      expect(find.text('Vaccinations'), findsOneWidget);
      expect(find.text('Medications'), findsOneWidget);
      expect(find.text('Vet visits'), findsOneWidget);
      expect(find.text('Notes & labs'), findsOneWidget);
      expect(find.text('2'), findsWidgets); // two vaccinations
    });
  });

  group('the tabs go somewhere', () {
    testWidgets('each one switches the body', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(items: _sample()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profile_tab_health')));
      await tester.pumpAndSettle();
      expect(find.text('Vaccination Manager'), findsOneWidget);
      expect(find.text('Medication Tracker'), findsOneWidget);

      await tester.tap(find.byKey(const Key('profile_tab_records')));
      await tester.pumpAndSettle();
      expect(find.text('Recent Records'), findsOneWidget);
      expect(find.byKey(const Key('profile_record_0')), findsOneWidget);

      await tester.tap(find.byKey(const Key('profile_tab_reminders')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile_reminders_empty')), findsOneWidget);

      await tester.tap(find.byKey(const Key('profile_tab_files')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile_files_empty')), findsOneWidget);
    });

    testWidgets('a reminder on the profile opens its own page', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(reminders: [
        Reminder(
          id: 'r1',
          petId: 'p1',
          reminderType: 'Vaccine',
          dueDate: DateTime.now().add(const Duration(days: 20)),
        ),
      ]));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile_tab_reminders')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile_reminder_0')), findsOneWidget);
    });

    testWidgets('an empty record does not pretend otherwise', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile_tab_records')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile_records_empty')), findsOneWidget);
    });
  });

  group('safety', () {
    testWidgets('nothing on the page grades the animal', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(items: _sample()));
      await tester.pumpAndSettle();

      for (final banned in [
        'Health Score',
        'Excellent',
        'Great!',
        'Up to date',
        'Completed',
        'Fully protected',
        'Allergies',
        'Conditions',
        'Blood Type: DEA',
      ]) {
        expect(find.textContaining(banned), findsNothing,
            reason: '"$banned" is a clinical claim the app cannot make');
      }
    });

    testWidgets('the score is the Care Score and says what it measures',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Care Score'), findsOneWidget);

      await tester.tap(find.byKey(const Key('profile_care_score')));
      await tester.pumpAndSettle();
      expect(find.textContaining('not a health score'), findsOneWidget);
      expect(find.textContaining('has not examined'), findsOneWidget);
    });

    testWidgets('the owner\'s notes carry V-22 provenance', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Sensitive to chicken. Nervous at the clinic.'),
          findsOneWidget);
      expect(find.text('Entered by the owner. PawDoc did not review it.'),
          findsOneWidget);
    });

    testWidgets('no provenance line when there is nothing to attribute',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(
        pet: const Pet(id: 'p1', userId: 'u1', name: 'Rex', species: 'cat'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Entered by the owner. PawDoc did not review it.'),
          findsNothing);
    });

    testWidgets('the vet card offers a real clinic, never a made-up one',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Your veterinarian'), findsOneWidget);
      // The mockup's invented practice must not appear.
      expect(find.textContaining('PawCare'), findsNothing);
      expect(find.textContaining('Dr.'), findsNothing);
    });

    testWidgets('the three unbacked features keep their slot and say Soon',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      // Personality traits, family sharing, and (once expanded) microchip.
      expect(find.textContaining('Soon'), findsWidgets);
      expect(find.byKey(const Key('profile_traits')), findsOneWidget);
      expect(find.byKey(const Key('profile_family')), findsOneWidget);
    });
  });
}
