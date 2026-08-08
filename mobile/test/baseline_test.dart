// Mockup `know_your_baseline` — the most contract-hostile reference in the set.
//
// It prints five vital signs the app has no sensor for, captions their
// TEXTBOOK REFERENCE RANGES as "Your Pet's Normal Range", grades the animal
// "Baseline Strength · 92/100 · Excellent", and closes with "Everything looks
// good! Buddy's vitals are stable and well within his normal range."
//
// Two of those numbers are the dangerous ones. 60–100 bpm and 38.0–39.2°C are
// real published ranges for a dog — printing them under a pet's name, captioned
// as *theirs*, is medical content this product has no standing to publish, and
// an owner who then counted 105 bpm at home would draw exactly the conclusion
// PawDoc exists to route to a vet instead.
//
// What ships is the owner's own filing: the range their records actually span,
// how long they have kept them, and where the gaps are. Only weight has
// numbers, because weight is the only thing the app records.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/account/user_profile.dart';
import 'package:pawdoc/src/health/baseline.dart';
import 'package:pawdoc/src/health/baseline_screen.dart';
import 'package:pawdoc/src/health/timeline.dart';
import 'package:pawdoc/src/health/weight_trend_card.dart';
import 'package:pawdoc/src/memories/media_url_cache.dart';
import 'package:pawdoc/src/pets/active_pet.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _buddy = Pet(
  id: 'p1',
  userId: 'u1',
  name: 'Buddy',
  species: 'dog',
  breed: 'Golden Retriever',
);

final _now = DateTime(2026, 8, 7);

WeightPoint _w(double kg, int daysAgo) =>
    WeightPoint(date: _now.subtract(Duration(days: daysAgo)), kg: kg);

TimelineItem _event(String type, int daysAgo) => TimelineItem(
      kind: TimelineKind.healthEvent,
      date: _now.subtract(Duration(days: daysAgo)),
      title: type,
      eventType: type,
    );

List<WeightPoint> _weights() => [_w(28.2, 2), _w(28.9, 20), _w(29.4, 55)];

List<TimelineItem> _timeline() => [
      _event('weight', 2),
      _event('vaccination', 9),
      _event('weight', 20),
      _event('vet_visit', 41),
      _event('weight', 55),
    ];

void _surface(WidgetTester tester, {double height = 3600}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

Widget _app({
  List<WeightPoint>? weights,
  List<TimelineItem>? items,
  Map<String, Object> prefs = const {},
}) {
  SharedPreferences.setMockInitialValues(prefs);
  return ProviderScope(
    overrides: [
      petsListProvider.overrideWith((ref) async => const [_buddy]),
      activePetProvider.overrideWithValue(_buddy),
      weightPointsProvider
          .overrideWith((ref, id) async => weights ?? _weights()),
      healthTimelineProvider
          .overrideWith((ref, id) async => items ?? _timeline()),
      userProfileProvider.overrideWith((ref) async =>
          const UserProfile(subscriptionStatus: 'free', photoLogsUsedThisMonth: 0)),
      mediaUrlServiceProvider.overrideWithValue(
        MediaUrlService(signer: (keys) async => (const <String, String>{}, 0)),
      ),
    ],
    child: const MaterialApp(home: BaselineScreen(pet: _buddy)),
  );
}

void main() {
  group('a baseline is the owner’s own span, never a published range', () {
    test('weight reports min, max, latest and the count', () {
      final b = weightBaseline(_weights());
      expect(b.count, 3);
      expect(b.min, 28.2);
      expect(b.max, 29.4);
      expect(b.latest, 28.2); // newest by date, not by list order
      expect(b.rangeLabel, '28.2 – 29.4');
      expect(b.hasRange, isTrue);
    });

    test('one entry is a reading, not a range', () {
      final b = weightBaseline([_w(28.2, 1)]);
      expect(b.hasAny, isTrue);
      expect(b.hasRange, isFalse);
      // It shows the reading, and the screen captions it "One entry so far" —
      // drawing a single point as a band is the first step towards a normal.
      expect(b.rangeLabel, '28.2');
      expect(b.spanDays, isNull);
    });

    test('no entries means no numbers at all', () {
      final b = weightBaseline(const []);
      expect(b.hasAny, isFalse);
      expect(b.rangeLabel, isNull);
      expect(b.latestLabel, isNull);
      expect(b.normalisedSeries, isEmpty);
    });

    test('the window trims, and can empty the range', () {
      final recent =
          weightBaseline(_weights(), since: _now.subtract(const Duration(days: 30)));
      expect(recent.count, 2);
      expect(recent.max, 28.9);

      final none =
          weightBaseline(_weights(), since: _now.subtract(const Duration(days: 1)));
      expect(none.hasAny, isFalse);
    });

    test('a flat run normalises to mid-height, not to the floor', () {
      final flat = weightBaseline([_w(28, 3), _w(28, 2), _w(28, 1)]);
      expect(flat.normalisedSeries, [0.5, 0.5, 0.5]);
    });

    test('only weight is tracked, and the rest say why', () {
      for (final m in BaselineMeasure.values) {
        if (m == BaselineMeasure.weight) {
          expect(m.tracked, isTrue);
          continue;
        }
        expect(m.tracked, isFalse, reason: m.label);
        expect(m.untrackedReason, isNotEmpty, reason: m.label);
      }
      // And the reason for the two dangerous ones names the actual hazard.
      expect(BaselineMeasure.heartRate.untrackedReason,
          contains('textbook range'));
      expect(BaselineMeasure.temperature.untrackedReason,
          contains('thermometer'));
    });
  });

  group('the record baseline counts, and never grades', () {
    test('totals, types, span and the longest gap', () {
      final r = RecordBaseline.from(_timeline());
      expect(r.total, 5);
      expect(r.typesCovered, 3);
      expect(r.byType['weight'], 3);
      expect(r.first, _now.subtract(const Duration(days: 55)));
      expect(r.last, _now.subtract(const Duration(days: 2)));
      expect(r.spanDays, 53);
      // 55 → 41 is 14 days, 41 → 20 is 21, 20 → 9 is 11, 9 → 2 is 7.
      expect(r.longestGapDays, 21);
      expect(r.commonestType, 'weight');
    });

    test('days since the last entry is measured from a supplied now', () {
      final r = RecordBaseline.from(_timeline());
      expect(r.daysSinceLast(now: _now), 2);
    });

    test('an empty record has no dates and no gap, rather than a zero', () {
      final r = RecordBaseline.from(const []);
      expect(r.total, 0);
      expect(r.first, isNull);
      expect(r.longestGapDays, isNull);
      expect(r.spanDays, isNull);
      expect(r.commonestType, isNull);
    });
  });

  group('observations are arithmetic, never praise', () {
    test('an empty record says so without scolding', () {
      final notes =
          baselineNotes(RecordBaseline.from(const []), weightBaseline(const []));
      expect(notes, hasLength(1));
      expect(notes.single.title, 'Nothing on file yet');
    });

    test('every note is about the record, not the animal', () {
      final notes = baselineNotes(
        RecordBaseline.from(_timeline()),
        weightBaseline(_weights()),
        now: _now,
      );
      expect(notes, isNotEmpty);
      for (final note in notes) {
        final text = '${note.title} ${note.body}'.toLowerCase();
        for (final banned in const [
          'great',
          'good work',
          'excellent',
          'healthy',
          'normal',
          'keep it up',
          'stable',
        ]) {
          expect(text, isNot(contains(banned)), reason: note.title);
        }
      }
    });

    test('the factors explain why a vet asks, and never prescribe', () {
      for (final (_, title, body) in kBaselineFactors) {
        final text = body.toLowerCase();
        for (final banned in const [
          'keep a healthy',
          'can improve',
          'should',
          'you must',
        ]) {
          expect(text, isNot(contains(banned)), reason: title);
        }
      }
    });
  });

  group('the mockup, drawn', () {
    testWidgets('every block the reference draws is present', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Know Your Baseline'), findsOneWidget);
      expect(find.byKey(const Key('baseline_history')), findsOneWidget);
      expect(find.byKey(const Key('baseline_care')), findsOneWidget);
      expect(find.byKey(const Key('baseline_why_card')), findsOneWidget);
      expect(find.byKey(const Key('baseline_measures_card')), findsOneWidget);
      expect(find.byKey(const Key('baseline_trend_card')), findsOneWidget);
      expect(find.byKey(const Key('baseline_summary_card')), findsOneWidget);
      expect(find.byKey(const Key('baseline_factors_card')), findsOneWidget);
      expect(find.byKey(const Key('baseline_notes_card')), findsOneWidget);
      expect(find.byKey(const Key('baseline_concern_card')), findsOneWidget);
      expect(find.byKey(const Key('baseline_add')), findsOneWidget);
      expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget);
    });

    testWidgets('the weight tile carries the owner’s own span', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // The window defaults to 30 days, which holds two of the three weights.
      expect(find.text('28.2 – 28.9'), findsOneWidget);
      expect(find.textContaining('Latest 28.2'), findsOneWidget);
    });

    testWidgets('the untracked tiles hold no numbers and offer a reason',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('baseline_measure_heartRate')),
          findsOneWidget);
      expect(find.text('Not tracked'), findsWidgets);

      await tester.tap(find.byKey(const Key('baseline_measure_heartRate')));
      await tester.pumpAndSettle();
      expect(find.textContaining('no way to measure a heartbeat'),
          findsOneWidget);
    });

    testWidgets('the summary counts rather than reassuring', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Records'), findsOneWidget);
      expect(find.text('Longest gap'), findsOneWidget);
      expect(find.byKey(const Key('baseline_summary_line')), findsOneWidget);
      expect(find.byKey(const Key('baseline_share')), findsOneWidget);
    });

    testWidgets('with no records the page still draws, and says nothing is on '
        'file', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(weights: const [], items: const []));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('baseline_trend_empty')), findsOneWidget);
      expect(find.text('Nothing on file yet'), findsOneWidget);
      expect(find.byKey(const Key('baseline_measures_card')), findsOneWidget);
    });
  });

  group('safety', () {
    testWidgets('no vital-sign reference range reaches the screen',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      for (final banned in const [
        '60 – 100',
        '60-100',
        'bpm',
        '15 – 30',
        '38.0',
        '39.2',
        'breaths/min',
        'Normal Range',
        'Baseline Strength',
      ]) {
        expect(find.textContaining(banned), findsNothing, reason: banned);
      }
    });

    testWidgets('no grade, no all-clear, and no claim of monitoring',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      for (final banned in const [
        'Excellent',
        'Everything looks good',
        'Health Score',
        'Within baseline',
        'Alerts Triggered',
        'Consistency',
        'Keep up the good work',
        'Most active time',
      ]) {
        expect(find.textContaining(banned), findsNothing, reason: banned);
      }
      // And it states the negative outright.
      expect(find.textContaining('does not watch these records'),
          findsOneWidget);
    });

    testWidgets('the trend draws no band until the owner sets a target',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(prefs: const {}));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('baseline_trend_note')), findsOneWidget);
      expect(find.textContaining('PawDoc draws no target band'), findsOneWidget);
    });

    testWidgets('a set target is named as the owner’s own', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(prefs: const {
        'pawdoc.weight_target.p1': '27.0:29.0',
      }));
      await tester.pumpAndSettle();

      expect(find.textContaining('the target you entered'), findsOneWidget);
      expect(find.textContaining('PawDoc does not set one'), findsOneWidget);
    });

    testWidgets('a worry routes into the Check flow, never a symptom list',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('baseline_check')), findsOneWidget);
      expect(find.text('Start a health check'), findsOneWidget);
      expect(find.textContaining('Warning Signs'), findsNothing);
    });
  });
}
