// Mockup `vaccination_manager`.
//
// The reference states, in three places, that an animal is protected:
// "Protection Status · Excellent · Fully protected", "100% · On Schedule ·
// Great job!" and "Vaccine Record · Up to date". The app knows which records
// an owner has typed in. It does not know whether an animal is immune —
// records are partial, schedules are regional, and vaccines can fail. Every
// one of those readings ships as a statement about the *record*.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/health/health_sections.dart';
import 'package:pawdoc/src/health/timeline.dart';
import 'package:pawdoc/src/health/vaccination_manager_screen.dart';
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

DateTime _daysFromNow(int d) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).add(Duration(days: d));
}

TimelineItem _vax(
  String id,
  String name, {
  String? vaccineClass,
  int givenDaysAgo = 200,
  int? dueInDays,
  String? clinic,
}) =>
    TimelineItem(
      kind: TimelineKind.healthEvent,
      date: _daysFromNow(-givenDaysAgo),
      title: 'Vaccination',
      subtitle: name,
      eventType: 'vaccination',
      id: id,
      payload: {
        'vaccine_name': name,
        'vaccine_class': ?vaccineClass,
        'clinic': ?clinic,
        if (dueInDays != null)
          'next_due':
              _daysFromNow(dueInDays).toIso8601String().split('T').first,
      },
    );

List<TimelineItem> _sample() => [
      _vax('v1', 'Rabies',
          vaccineClass: 'Core',
          dueInDays: 112,
          clinic: 'PawCare Veterinary Clinic'),
      _vax('v2', 'Leptospirosis (L4)',
          vaccineClass: 'Non-core', dueInDays: 45),
      _vax('v3', 'Bordetella', vaccineClass: 'Lifestyle', dueInDays: -12),
      _vax('v4', 'DHPPi', vaccineClass: 'Core'),
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
    child: const MaterialApp(home: VaccinationManagerScreen()),
  );
}

void main() {
  group('the record model', () {
    test('reads the keys the form writes', () {
      final v = Vaccination.fromTimelineItem(
          _vax('v1', 'Rabies', vaccineClass: 'Core', dueInDays: 30))!;
      expect(v.name, 'Rabies');
      expect(v.vaccineClass, 'Core');
      expect(v.daysUntilDue, 30);
      expect(v.isOverdue, isFalse);
      expect(v.dueWithin(const Duration(days: 365)), isTrue);
    });

    test('a passed date is overdue, and counted in days', () {
      final v = Vaccination.fromTimelineItem(
          _vax('v1', 'Bordetella', dueInDays: -12))!;
      expect(v.isOverdue, isTrue);
      expect(v.daysUntilDue, -12);
    });

    test('no next date means nothing is claimed about when it is due', () {
      final v = Vaccination.fromTimelineItem(_vax('v1', 'DHPPi'))!;
      expect(v.nextDue, isNull);
      expect(v.isOverdue, isFalse);
      expect(v.dueWithin(const Duration(days: 365)), isFalse);
    });

    test('a class is never inferred from a name', () {
      final v = Vaccination.fromTimelineItem(_vax('v1', 'Rabies'))!;
      expect(v.vaccineClass, isNull,
          reason: 'which vaccines are core is a regional veterinary judgement');
    });
  });

  group('the mockup, drawn', () {
    testWidgets('every block the reference draws is present', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Vaccination Manager'), findsOneWidget);
      expect(find.byKey(const Key('module_pet_name')), findsOneWidget);
      expect(find.byKey(const Key('vaccination_status')), findsOneWidget);

      expect(find.text('Recorded'), findsOneWidget);
      expect(find.text('Past due'), findsOneWidget);
      expect(find.byKey(const Key('health_filter_all')), findsOneWidget);
      expect(find.byKey(const Key('health_filter_core')), findsOneWidget);

      expect(find.text('Coming Up'), findsOneWidget);
      expect(find.byKey(const Key('vaccination_row_v2')), findsWidgets);
      expect(find.byKey(const Key('vaccination_calendar_card')), findsOneWidget);
      expect(find.text('Vaccine History'), findsOneWidget);
      expect(find.byKey(const Key('vaccination_add_cta')), findsOneWidget);
      expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget);
    });

    testWidgets('the statistics are counted', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('4'), findsWidgets); // four records
      expect(find.text('1'), findsWidgets); // one overdue (Bordetella)
      expect(find.text('Ask your vet'), findsOneWidget);
    });

    testWidgets('a record with no next date never appears under Coming Up',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(items: [_vax('v4', 'DHPPi')]));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vaccination_none_upcoming')), findsOneWidget);
      // …but it is still on the record.
      expect(find.byKey(const Key('vaccination_row_v4')), findsOneWidget);
    });

    testWidgets('an empty record says what would fill it', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(items: const []));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vaccination_none_upcoming')), findsOneWidget);
      expect(find.byKey(const Key('vaccination_none_history')), findsOneWidget);
      expect(find.text('Nothing filed yet'), findsOneWidget);
    });
  });

  group('filtering by class', () {
    testWidgets('narrows to the owner\'s own classification', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('health_filter_core')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vaccination_row_v1')), findsWidgets);
      expect(find.byKey(const Key('vaccination_row_v2')), findsNothing);
    });

    testWidgets('unclassified records are reachable, not lost', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(items: [
        _vax('v1', 'Rabies', vaccineClass: 'Core'),
        _vax('v9', 'Something the owner did not classify'),
      ]));
      await tester.pumpAndSettle();
      // The rail scrolls; reach the last chip the way a user would.
      await tester.scrollUntilVisible(
        find.byKey(const Key('health_filter_unclassified')),
        130,
        scrollable: find.descendant(
          of: find.byType(HealthFilterChips),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('health_filter_unclassified')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vaccination_row_v9')), findsOneWidget);
      expect(find.byKey(const Key('vaccination_row_v1')), findsNothing);
    });
  });

  group('safety', () {
    testWidgets('nothing claims the animal is protected', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      for (final banned in [
        'Fully protected',
        'Protection Status',
        'Excellent',
        'Great job',
        'Up to date',
        'On Schedule',
        'protect Buddy',
      ]) {
        expect(find.textContaining(banned), findsNothing,
            reason: '"$banned" asserts an immunity the app cannot know');
      }
    });

    testWidgets('the summary describes the record, and says so',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Vaccine record'), findsOneWidget);
      expect(find.text('4 on file'), findsOneWidget);
      expect(find.text('1 without a next date'), findsOneWidget);
    });

    testWidgets('the educational card points at the vet, not at a schedule',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.textContaining('is your vet’s call'), findsOneWidget);
    });

    testWidgets('an overdue vaccine is never painted in a ladder hue',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(VaccinationManagerScreen));
      const ladder = [
        Color(0xFFFF5A52),
        Color(0xFFC62828),
        Color(0xFFFFC233),
        Color(0xFFFFB300),
        Color(0xFF1565C0),
        Color(0xFF455A64),
      ];
      for (final c in ['Core', 'Non-core', 'Lifestyle', null]) {
        expect(ladder.contains(vaccineTint(context, c)), isFalse,
            reason: 'the $c tint reads as a severity signal');
      }
    });
  });
}
