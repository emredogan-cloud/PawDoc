// Mockup `manage_multiple_pets`.
//
// The reference grades a household: "Family Health · Excellent" over three
// animals at once, and a per-pet "Health Score · 92 · Excellent". The app has
// examined none of them. Both ship as counted facts about the record.
//
// It also prints "Blood Type: DEA 1.1 +" on one card and "N/A" on the next —
// which reads as a *measured* absence rather than a column that does not
// exist — and tags each pet with personality traits there is nowhere to store.
//
// Search, sort and the two layouts are real and pure, so they are unit-tested
// as functions as well as through the screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/analysis/analysis_service.dart';
import 'package:pawdoc/src/health/timeline.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_list_screen.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';
import 'package:pawdoc/src/reminders/reminder.dart';
import 'package:pawdoc/src/reminders/reminders_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _buddy = Pet(
  id: 'p1',
  userId: 'u1',
  name: 'Buddy',
  species: 'dog',
  breed: 'Golden Retriever',
  sex: 'male',
  weightKg: 28,
);
const _milo = Pet(
  id: 'p2',
  userId: 'u1',
  name: 'Milo',
  species: 'cat',
  breed: 'British Shorthair',
  sex: 'male',
  weightKg: 5.2,
);
const _coco = Pet(
  id: 'p3',
  userId: 'u1',
  name: 'Coco',
  species: 'rabbit',
  breed: 'Holland Lop',
  sex: 'female',
);

TimelineItem _event(String id) => TimelineItem(
      kind: TimelineKind.healthEvent,
      date: DateTime.now(),
      title: 'Vet Visit',
      eventType: 'vet_visit',
      id: id,
    );

void _surface(WidgetTester tester, {double height = 3400}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

Widget _app({
  List<Pet>? pets,
  Map<String, List<TimelineItem>> events = const {},
  Map<String, List<Reminder>> reminders = const {},
}) {
  SharedPreferences.setMockInitialValues(const {});
  return ProviderScope(
    overrides: [
      petsListProvider
          .overrideWith((ref) async => pets ?? const [_buddy, _milo, _coco]),
      healthTimelineProvider
          .overrideWith((ref, petId) async => events[petId] ?? const []),
      remindersForPetProvider
          .overrideWith((ref, petId) async => reminders[petId] ?? const []),
      latestTriageProvider.overrideWith((ref, petId) => null),
    ],
    child: const MaterialApp(home: PetsListScreen()),
  );
}

void main() {
  group('search is pure and matches what an owner would type', () {
    const all = [_buddy, _milo, _coco];

    test('by name', () {
      expect(filterPets(all, 'mil').map((p) => p.id), ['p2']);
      expect(filterPets(all, 'BUDDY').map((p) => p.id), ['p1']);
    });

    test('by breed', () {
      expect(filterPets(all, 'holland').map((p) => p.id), ['p3']);
    });

    test('by species, using the word the app shows', () {
      expect(filterPets(all, 'rabbit').map((p) => p.id), ['p3']);
      expect(filterPets(all, 'cat').map((p) => p.id), ['p2']);
    });

    test('an empty query is every pet, not none', () {
      expect(filterPets(all, '   ').length, 3);
    });

    test('no match returns nothing rather than everything', () {
      expect(filterPets(all, 'zzz'), isEmpty);
    });
  });

  group('sorting', () {
    const all = [_buddy, _milo, _coco];

    test('by name, case-insensitively', () {
      expect(sortPets(all, PetSort.name).map((p) => p.name),
          ['Buddy', 'Coco', 'Milo']);
    });

    test('recently added reverses the repository order', () {
      expect(sortPets(all, PetSort.added).map((p) => p.id),
          ['p3', 'p2', 'p1']);
    });

    test('by species, then by name', () {
      expect(sortPets(all, PetSort.species).map((p) => p.species),
          ['cat', 'dog', 'rabbit']);
    });

    test('by record count, most first', () {
      final sorted = sortPets(all, PetSort.records,
          recordCounts: {'p1': 2, 'p2': 9, 'p3': 0});
      expect(sorted.map((p) => p.id), ['p2', 'p1', 'p3']);
    });

    test('sorting never drops or duplicates a pet', () {
      for (final s in PetSort.values) {
        expect(sortPets(all, s).map((p) => p.id).toSet(),
            {'p1', 'p2', 'p3'});
      }
    });
  });

  group('the mockup, drawn', () {
    testWidgets('every block the reference draws is present', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('My Pets'), findsOneWidget);
      expect(find.byKey(const Key('pets_add')), findsOneWidget);
      expect(find.byKey(const Key('pets_search_field')), findsOneWidget);
      expect(find.byKey(const Key('pets_sort')), findsOneWidget);
      expect(find.byKey(const Key('pets_grid')), findsOneWidget);
      expect(find.byKey(const Key('pets_list')), findsOneWidget);

      expect(find.text('Total pets'), findsOneWidget);
      expect(find.text('Records on file'), findsOneWidget);
      // The stat tile plus one per pet-card action row.
      expect(find.text('Reminders'), findsWidgets);

      // One card per pet, each with the five actions.
      expect(find.byKey(const Key('pet_name_p1')), findsOneWidget);
      expect(find.byKey(const Key('pet_name_p2')), findsOneWidget);
      expect(find.byKey(const Key('pet_name_p3')), findsOneWidget);
      expect(find.byKey(const Key('pet_action_profile_p1')), findsOneWidget);
      expect(find.byKey(const Key('pet_action_records_p1')), findsOneWidget);
      expect(find.byKey(const Key('pet_action_reminders_p1')), findsOneWidget);
      expect(find.byKey(const Key('pet_action_health_p1')), findsOneWidget);
      expect(find.byKey(const Key('pet_action_more_p1')), findsOneWidget);

      expect(find.byKey(const Key('pets_invite_family')), findsOneWidget);
      expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget);
    });

    testWidgets('the statistics are counted, not asserted', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(
        events: {
          'p1': [_event('e1'), _event('e2')],
          'p2': [_event('e3')],
        },
        reminders: {
          'p1': [
            Reminder(
              id: 'r1',
              petId: 'p1',
              reminderType: 'Vaccine',
              dueDate: DateTime.now().add(const Duration(days: 10)),
            ),
          ],
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsWidgets); // three pets, three records
      expect(find.text('1'), findsWidgets); // one reminder, one due soon
    });

    testWidgets('exactly one pet is marked active', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pet_active_chip')), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });
  });

  group('search, sort and layout on the screen', () {
    testWidgets('typing narrows the list', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('pets_search_field')), 'coco');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pet_name_p3')), findsOneWidget);
      expect(find.byKey(const Key('pet_name_p1')), findsNothing);
    });

    testWidgets('a query that matches nothing says so', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('pets_search_field')), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pets_no_match')), findsOneWidget);
    });

    testWidgets('the sort sheet offers every order', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pets_sort')));
      await tester.pumpAndSettle();
      for (final s in PetSort.values) {
        expect(find.byKey(Key('pet_sort_${s.name}')), findsOneWidget);
      }
    });

    testWidgets('the grid toggle swaps the layout', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pets_grid_view')), findsNothing);
      await tester.tap(find.byKey(const Key('pets_grid')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pets_grid_view')), findsOneWidget);
      expect(find.byKey(const Key('pet_tile_p1')), findsOneWidget);
      // The five-action row belongs to the list card only.
      expect(find.byKey(const Key('pet_action_profile_p1')), findsNothing);
    });
  });

  group('the more sheet', () {
    testWidgets('offers activation only for a pet that is not active',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // p1 is active (first in the list, nothing selected).
      await tester.tap(find.byKey(const Key('pet_more_p2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pet_more_activate')), findsOneWidget);
      expect(find.byKey(const Key('pet_more_edit')), findsOneWidget);
      expect(find.byKey(const Key('pet_more_delete')), findsOneWidget);
    });

    testWidgets('removing a pet confirms, and says the record survives',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pet_more_p2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pet_more_delete')));
      await tester.pumpAndSettle();

      expect(find.text('Remove Milo?'), findsOneWidget);
      expect(find.textContaining('Past health records and AI checks are kept'),
          findsOneWidget);
    });
  });

  group('safety', () {
    testWidgets('nothing grades the household or any animal in it',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      for (final banned in [
        'Family Health',
        'Health Score',
        'Excellent',
        'Very Good',
        'Blood Type',
        'DEA 1.1',
        'N/A',
      ]) {
        expect(find.textContaining(banned), findsNothing,
            reason: '"$banned" is a claim the app has no basis for');
      }
    });

    testWidgets('the per-pet score is the Care Score, in record words',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(pets: const [_buddy]));
      await tester.pumpAndSettle();
      expect(find.text('Care Score'), findsOneWidget);
      expect(find.textContaining('Just started'), findsWidgets);
    });

    testWidgets('the F-4 last-check chip survives the rebuild', (tester) async {
      _surface(tester);
      SharedPreferences.setMockInitialValues(const {});
      await tester.pumpWidget(ProviderScope(
        overrides: [
          petsListProvider.overrideWith((ref) async => const [_buddy]),
          healthTimelineProvider.overrideWith((ref, petId) async => const []),
          remindersForPetProvider
              .overrideWith((ref, petId) async => const []),
          latestTriageProvider.overrideWith((ref, petId) =>
              LatestTriage(level: 'CALL_TODAY', checkedAt: DateTime.now())),
        ],
        child: const MaterialApp(home: PetsListScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('last_check_chip_p1')), findsOneWidget);
      // The friendly ladder label, never the raw wire token.
      expect(find.text('Call today'), findsOneWidget);
      expect(find.textContaining('CALL_TODAY'), findsNothing);
    });

    testWidgets('the traits row keeps its place and says Soon',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(pets: const [_buddy]));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pet_traits_p1')), findsOneWidget);
      expect(find.textContaining('Soon'), findsWidgets);
    });
  });

  group('an empty account', () {
    testWidgets('invites the first pet rather than showing a bare list',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(pets: const []));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pets_empty')), findsOneWidget);
      expect(find.textContaining('No pets yet'), findsOneWidget);
    });
  });
}
