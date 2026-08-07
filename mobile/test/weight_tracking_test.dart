// Mockup `weight_tracking`.
//
// The reference grades the animal three times over — a dashed "Ideal Range
// (26.0 – 30.0 kg)" band, an "Ideal" badge on every record, and "Great job!
// Buddy is within the ideal weight range." An ideal weight is a body-condition
// judgement a vet assigns by hand; inventing one and then scoring an animal
// against it is the same class of claim as a fabricated health score. The band
// exists and its numbers come from the owner; the badge states the change; the
// card states what the record shows and whose call the rest is.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/health/weight_target.dart';
import 'package:pawdoc/src/health/weight_tracking_screen.dart';
import 'package:pawdoc/src/health/weight_trend_card.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pet = Pet(
  id: 'p1',
  userId: 'u1',
  name: 'Buddy',
  species: 'dog',
  breed: 'Golden Retriever',
  weightKg: 28.2,
);

DateTime _daysAgo(int d) => DateTime.now().subtract(Duration(days: d));

List<WeightPoint> _sample() => [
      WeightPoint(date: _daysAgo(40), kg: 27.2, id: 'w1', note: 'Good appetite'),
      WeightPoint(date: _daysAgo(20), kg: 27.6, id: 'w2'),
      WeightPoint(date: _daysAgo(5), kg: 28.2, id: 'w3', note: 'Active'),
    ];

void _surface(WidgetTester tester, {double height = 2400}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

Widget _app({List<WeightPoint>? points, WeightTarget? target}) {
  SharedPreferences.setMockInitialValues(const {});
  return ProviderScope(
    overrides: [
      petsListProvider.overrideWith((ref) async => const [_pet]),
      weightPointsProvider
          .overrideWith((ref, petId) async => points ?? _sample()),
      weightTargetProvider.overrideWith((ref, petId) async => target),
    ],
    child: const MaterialApp(home: WeightTrackingScreen()),
  );
}

void main() {
  group('the mockup, drawn', () {
    testWidgets('every block the reference draws is present', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Weight Tracking'), findsOneWidget);
      expect(find.byKey(const Key('module_pet_name')), findsOneWidget);
      expect(find.text('Current Weight'), findsOneWidget);
      expect(find.byKey(const Key('weight_current')), findsOneWidget);

      // Statistics strip.
      expect(find.text('Current weight'), findsOneWidget);
      expect(find.text('vs last month'), findsOneWidget);
      expect(find.text('Logged range (kg)'), findsOneWidget);

      // Chart, summary, records, add card, education.
      expect(find.text('Weight Trend'), findsOneWidget);
      expect(find.byKey(const Key('weight_chart')), findsOneWidget);
      expect(find.byKey(const Key('weight_summary')), findsOneWidget);
      expect(find.text('Weight Records'), findsOneWidget);
      expect(find.byKey(const Key('weight_row_w3')), findsOneWidget);
      expect(find.byKey(const Key('weight_add_card')), findsOneWidget);
      expect(find.text('Why weight tracking matters'), findsOneWidget);
      expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget);
    });

    testWidgets('the hero shows the newest entry, not the oldest',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      // 28.2 is the most recent of the three.
      expect(
          tester.widget<Text>(find.byKey(const Key('weight_current'))).data,
          '28.2');
    });

    testWidgets('one entry is not yet a line, and the screen says so',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(points: [
        WeightPoint(date: _daysAgo(1), kg: 28.0, id: 'w1'),
      ]));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('weight_chart')), findsNothing);
      expect(find.textContaining('becomes a line'), findsOneWidget);
      expect(find.textContaining('One entry so far'), findsOneWidget);
    });

    testWidgets('an empty record invites the first weigh-in', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(points: const []));
      await tester.pumpAndSettle();
      expect(find.text('No weights logged yet'), findsOneWidget);
      expect(find.byKey(const Key('weight_add_card')), findsOneWidget);
    });
  });

  group('safety', () {
    testWidgets('nothing grades the animal', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(target: const WeightTarget(26.5, 29.0)));
      await tester.pumpAndSettle();

      for (final banned in [
        'Ideal',
        'Great job',
        'ideal weight',
        'Keep up the good work',
        'healthy weight range',
        'detect health issues',
      ]) {
        expect(find.textContaining(banned), findsNothing,
            reason: '"$banned" grades an animal the app has not examined');
      }
    });

    testWidgets('the range is the owner\'s, and labelled as theirs',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(target: const WeightTarget(26.5, 29.0)));
      await tester.pumpAndSettle();
      expect(find.text('26.5–29.0 kg'), findsOneWidget);
      expect(find.text('Target range (yours)'), findsOneWidget);
      expect(find.textContaining('your vet’s call'), findsOneWidget);
    });

    testWidgets('with no target set there is no band and no verdict',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Not set'), findsOneWidget);
      expect(find.textContaining('tap to set'), findsOneWidget);
    });

    testWidgets('each record states its change, never a grade', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(target: const WeightTarget(26.5, 29.0)));
      await tester.pumpAndSettle();
      expect(find.text('+0.6 kg'), findsWidgets); // 27.6 → 28.2
      expect(find.text('+0.4 kg'), findsWidgets); // 27.2 → 27.6
      expect(find.text('First entry'), findsOneWidget);
    });
  });

  group('the summary states the record', () {
    testWidgets('it counts the entries and the movement', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final summary =
          tester.widget<Text>(find.byKey(const Key('weight_summary'))).data!;
      expect(summary, contains('3 entries'));
      expect(summary, contains('+1.0 kg'));
    });

    testWidgets('a flat record reads as steady, not as good news',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(points: [
        WeightPoint(date: _daysAgo(30), kg: 28.0, id: 'w1'),
        WeightPoint(date: _daysAgo(2), kg: 28.0, id: 'w2'),
      ]));
      await tester.pumpAndSettle();
      final summary =
          tester.widget<Text>(find.byKey(const Key('weight_summary'))).data!;
      expect(summary, contains('held steady'));
    });
  });

  group('the target store', () {
    test('round-trips, and rejects a nonsense range', () async {
      SharedPreferences.setMockInitialValues(const {});
      expect(await WeightTarget.load('p1'), isNull);

      await WeightTarget.save('p1', const WeightTarget(26.5, 29.0));
      final loaded = await WeightTarget.load('p1');
      expect(loaded!.minKg, 26.5);
      expect(loaded.maxKg, 29.0);
      expect(loaded.label, '26.5–29.0 kg');
      expect(loaded.contains(28.0), isTrue);
      expect(loaded.contains(31.0), isFalse);

      await WeightTarget.clear('p1');
      expect(await WeightTarget.load('p1'), isNull);
    });

    test('is scoped per pet', () async {
      SharedPreferences.setMockInitialValues(const {});
      await WeightTarget.save('p1', const WeightTarget(26.0, 30.0));
      expect(await WeightTarget.load('p2'), isNull);
    });
  });
}
