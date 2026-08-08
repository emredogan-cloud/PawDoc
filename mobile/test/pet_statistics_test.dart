// Mockup `pet_statistics` — the most claim-heavy reference in the set.
//
// Almost every figure on it grades an animal, and one is a feature that does
// not exist anywhere in the product:
//
//   "Health Score 92/100 Excellent"        → the Care Score (D-2)
//   "Health Score Trend, 78 → 92"          → records logged per month. A line
//                                            that trended better or worse
//                                            would be a graded verdict drawn
//                                            from nothing — the rule the
//                                            result screen already settled
//   "All good! Keep it up"                 → gone (all-clear)
//   "Great Job! …improved 14 points"       → the most recent record, dated
//   "Consider dental check-up"             → gone. Recommending a procedure is
//                                            veterinary advice
//   "Expenses ₺2,450 Total Spent"          → the tile, marked *Soon*. There is
//                                            no money in this product at all
//
// The arithmetic is pure, so it is tested as functions as well as on screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/health/timeline.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pet_statistics_screen.dart';
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
);
const _milo =
    Pet(id: 'p2', userId: 'u1', name: 'Milo', species: 'cat');

DateTime _monthsAgo(int m) {
  final now = DateTime.now();
  return DateTime(now.year, now.month - m, 15);
}

TimelineItem _event(String id, String type, {int monthsAgo = 0}) =>
    TimelineItem(
      kind: TimelineKind.healthEvent,
      date: _monthsAgo(monthsAgo),
      title: type,
      eventType: type,
      id: id,
    );

TimelineItem _check(String id, {int monthsAgo = 0}) => TimelineItem(
      kind: TimelineKind.analysis,
      date: _monthsAgo(monthsAgo),
      title: 'Watch and re-check',
      action: 'WATCH_AND_RECHECK',
      id: id,
    );

List<TimelineItem> _sample() => [
      _event('e1', 'vet_visit'),
      _event('e2', 'vet_visit', monthsAgo: 2),
      _event('e3', 'medication', monthsAgo: 1),
      _event('e4', 'medication', monthsAgo: 1),
      _event('e5', 'vaccination', monthsAgo: 4),
      _event('e6', 'custom', monthsAgo: 6),
      _check('a1', monthsAgo: 3),
    ];

void _surface(WidgetTester tester, {double height = 3600}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

Widget _app({
  List<Pet>? pets,
  List<TimelineItem>? items,
  List<Reminder>? reminders,
}) {
  SharedPreferences.setMockInitialValues(const {});
  return ProviderScope(
    overrides: [
      petsListProvider.overrideWith((ref) async => pets ?? const [_buddy]),
      healthTimelineProvider
          .overrideWith((ref, petId) async => items ?? _sample()),
      remindersForPetProvider
          .overrideWith((ref, petId) async => reminders ?? const []),
    ],
    child: const MaterialApp(home: PetStatisticsScreen()),
  );
}

void main() {
  group('the arithmetic', () {
    test('counts by type, and keeps AI checks separate', () {
      final s = PetStats.from(_sample(), range: StatsRange.twelveMonths);
      expect(s.byType['vet_visit'], 2);
      expect(s.byType['medication'], 2);
      expect(s.byType['vaccination'], 1);
      expect(s.byType['custom'], 1);
      expect(s.checks, 1,
          reason: 'an analysis is not a health event the owner filed');
      expect(s.total, 7);
    });

    test('the range genuinely excludes older records', () {
      final s = PetStats.from(_sample(), range: StatsRange.threeMonths);
      // Only the last three calendar months: e1, e3, e4, e2.
      expect(s.total, lessThan(7));
      expect(s.byType['vaccination'], isNull,
          reason: 'the vaccination is four months back');
    });

    test('the monthly buckets span the range, oldest first', () {
      final s = PetStats.from(_sample(), range: StatsRange.twelveMonths);
      expect(s.monthly.length, 12);
      expect(s.monthLabels.length, 12);
      expect(s.monthly.last, 1, reason: 'one record this month');
      expect(s.monthly.fold<int>(0, (a, b) => a + b), 7);
    });

    test('an empty record produces zeroes, never a crash', () {
      final s = PetStats.from(const [], range: StatsRange.twelveMonths);
      expect(s.total, 0);
      expect(s.newest, isNull);
      expect(s.thisMonth, 0);
      expect(s.busiestMonth, 0);
    });

    test('all-time caps the axis but never the count', () {
      final s = PetStats.from(
        [_event('old', 'custom', monthsAgo: 60), _event('new', 'custom')],
        range: StatsRange.allTime,
      );
      expect(s.monthly.length, lessThanOrEqualTo(24),
          reason: 'an unbounded axis is unreadable');
      expect(s.total, 2,
          reason: 'a three-year-old record still belongs to "all time"');
    });

    test('a bounded range does exclude what falls outside it', () {
      final s = PetStats.from(
        [_event('old', 'custom', monthsAgo: 10), _event('new', 'custom')],
        range: StatsRange.threeMonths,
      );
      expect(s.total, 1);
    });

    test('this month against last month', () {
      final s = PetStats.from([
        _event('a', 'custom'),
        _event('b', 'custom'),
        _event('c', 'custom', monthsAgo: 1),
      ], range: StatsRange.twelveMonths);
      expect(s.thisMonth, 2);
      expect(s.lastMonth, 1);
    });
  });

  group('normalising for the sparkline', () {
    test('scales against the busiest month', () {
      expect(normalise([0, 5, 10]), [0.0, 0.5, 1.0]);
    });

    test('an all-zero run sits off the floor rather than vanishing', () {
      final n = normalise([0, 0, 0]);
      expect(n.every((v) => v > 0), isTrue);
    });

    test('empty in, empty out', () {
      expect(normalise(const []), isEmpty);
    });
  });

  group('the mockup, drawn', () {
    testWidgets('every block the reference draws is present', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Pet Statistics'), findsOneWidget);
      expect(find.byKey(const Key('stats_range')), findsOneWidget);
      expect(find.byKey(const Key('stats_pet_rail')), findsOneWidget);
      expect(find.byKey(const Key('stats_add_pet')), findsOneWidget);

      expect(find.text('Overview'), findsOneWidget);
      expect(find.byKey(const Key('stats_tile_records')), findsOneWidget);
      expect(find.byKey(const Key('stats_tile_visits')), findsOneWidget);
      expect(find.byKey(const Key('stats_tile_meds')), findsOneWidget);
      expect(find.byKey(const Key('stats_tile_expenses')), findsOneWidget);

      expect(find.text('Records Over Time'), findsOneWidget);
      expect(find.byKey(const Key('stats_trend_chart')), findsOneWidget);
      expect(find.byKey(const Key('stats_score_dial')), findsOneWidget);
      expect(find.text('Records Breakdown'), findsOneWidget);
      expect(find.byKey(const Key('stats_donut')), findsOneWidget);
      expect(find.text('Top Health Categories'), findsOneWidget);
      expect(find.text('Highlights'), findsOneWidget);
      expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget);
    });

    testWidgets('the tiles show counted values', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('7'), findsWidgets); // total records
      expect(find.text('Vet visits'), findsWidgets);
      expect(find.text('Medications'), findsWidgets);
    });

    testWidgets('the range picker offers every window and narrows the count',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('stats_range')));
      await tester.pumpAndSettle();
      for (final r in StatsRange.values) {
        expect(find.byKey(Key('stats_range_${r.name}')), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('stats_range_threeMonths')));
      await tester.pumpAndSettle();
      expect(find.text('Last 3 months'), findsOneWidget);
    });

    testWidgets('an empty record says so rather than drawing a flat lie',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(items: const []));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('stats_breakdown_empty')), findsOneWidget);
      expect(find.textContaining('Nothing filed'), findsWidgets);
    });

    testWidgets('one pet has nothing to compare against', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Pet Comparison'), findsNothing);
    });

    testWidgets('a second pet brings the comparison table', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(pets: const [_buddy, _milo]));
      await tester.pumpAndSettle();
      expect(find.text('Pet Comparison'), findsOneWidget);
      expect(find.byKey(const Key('stats_compare_p1')), findsOneWidget);
      expect(find.byKey(const Key('stats_compare_p2')), findsOneWidget);
    });
  });

  group('safety', () {
    testWidgets('nothing on the page grades the animal', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(pets: const [_buddy, _milo]));
      await tester.pumpAndSettle();

      for (final banned in [
        'Health Score',
        'Excellent',
        'Very Good',
        'Great Job',
        'All good',
        'Keep it up',
        'Consider dental',
        'improves overall health',
        'Total Spent',
        '₺',
      ]) {
        expect(find.textContaining(banned), findsNothing,
            reason: '"$banned" is a grade, an instruction or invented money');
      }
    });

    testWidgets('the trend says what the line actually plots', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.textContaining('How much you logged each month'),
          findsOneWidget);
      expect(find.textContaining('not a score'), findsOneWidget);
    });

    testWidgets('the dial is the Care Score and disclaims itself',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Care Score'), findsWidgets);
      expect(find.textContaining('Not a health score'), findsOneWidget);
      expect(find.textContaining('has not examined'), findsWidgets);
    });

    testWidgets('the expenses tile keeps its slot and shows no money',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('stats_tile_expenses')), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Soon'), findsWidgets);
    });

    testWidgets('the highlights point at the vet, never prescribe',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('stats_highlight_latest')), findsOneWidget);
      expect(find.byKey(const Key('stats_highlight_next')), findsOneWidget);
      expect(find.textContaining('is your vet\'s call'), findsOneWidget);
    });

    testWidgets('no chart tint is one of the ladder\'s locked hues',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(PetStatisticsScreen));
      const ladder = [
        Color(0xFFFF5A52),
        Color(0xFFC62828),
        Color(0xFFFFC233),
        Color(0xFFFFB300),
        Color(0xFF1565C0),
        Color(0xFF455A64),
      ];
      for (final c in breakdownTints(context)) {
        expect(ladder.contains(c), isFalse,
            reason: 'a donut slice must not read as a severity signal');
      }
    });
  });
}
