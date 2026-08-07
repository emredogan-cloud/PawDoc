// Mockups `smart_walks` and `weather_walk_advisor`.
//
// These two are the most claim-heavy references outside the result screens,
// and every claim on them is about an animal the app has never examined:
//
//  * "AI Suggestion: up to 60 minutes a day is ideal for heart health and
//    weight control" — an exercise prescription, branded as a model that does
//    not exist. `scoreWalkHour` is a pure function.
//  * "Estimated duration 30–45 min" / "Ideal distance 3–5 km" — the same
//    prescription, in a four-row advice block.
//  * "Give a water break every 15–20 minutes" — a dosing schedule.
//  * "215 kcal burned" — a number that needs weight, gait and metabolism.
//  * "A great day for Buddy!" — the forecast is about the sky.
//
// What ships instead is weather, counted and scored on the device: the kindest
// hours, the ground, the water, the sun — and one sentence saying how far and
// how long is the vet's call.
//
// There is also no walk tracking at all. The live-walk card, the weekly
// totals, the history and the badges keep their place and say *Soon*.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/pets/active_pet.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';
import 'package:pawdoc/src/theme/design_tokens.dart';
import 'package:pawdoc/src/walks/places_service.dart';
import 'package:pawdoc/src/walks/walk_scorer.dart';
import 'package:pawdoc/src/walks/walk_sections.dart';
import 'package:pawdoc/src/walks/walks_controller.dart';
import 'package:pawdoc/src/walks/walks_screen.dart';
import 'package:pawdoc/src/walks/weather_service.dart';
import 'package:pawdoc/src/walks/weather_walk_advisor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _buddy = Pet(
  id: 'p1',
  userId: 'u1',
  name: 'Buddy',
  species: 'dog',
  breed: 'Golden Retriever',
);

HourlyWeather _hour(
  DateTime at, {
  double temp = 18,
  double wind = 2,
  double precip = 0,
  double? uv,
  String symbol = 'clearsky_day',
}) =>
    HourlyWeather(
      time: at,
      tempC: temp,
      windMs: wind,
      precipMm: precip,
      uvIndex: uv,
      symbol: symbol,
    );

/// Two comfortable days followed by a hot one.
List<HourlyWeather> _forecast() {
  final start = DateTime(2026, 8, 7, 8);
  return [
    for (var h = 0; h < 12; h++)
      _hour(start.add(Duration(hours: h)), temp: 18 + h * 0.2),
    for (var h = 0; h < 12; h++)
      _hour(start.add(Duration(days: 1, hours: h)), temp: 16 + h * 0.3),
    for (var h = 0; h < 12; h++)
      _hour(start.add(Duration(days: 2, hours: h)),
          temp: 35, uv: 9, symbol: 'clearsky_day'),
  ];
}

WalksReady _ready({List<HourlyWeather>? hours, List<WalkPlace>? places}) {
  final list = hours ?? _forecast();
  return WalksReady(
    hours: list,
    now: scoreWalkHour(list.first),
    todayWindows: bestWalkWindows(list),
    places: places ??
        const [
          WalkPlace(
              name: 'Kent Park',
              lat: 39.7,
              lon: 30.5,
              kind: 'park',
              distanceMeters: 420),
          WalkPlace(
              name: 'Sazova Dog Run',
              lat: 39.8,
              lon: 30.4,
              kind: 'dog_park',
              distanceMeters: 1900),
        ],
    lat: 39.7,
    lon: 30.5,
  );
}

class _FakeWalks extends WalksController {
  _FakeWalks(this._state);

  final WalksState _state;

  @override
  WalksState build() => _state;

  @override
  Future<void> refresh({String species = 'dog'}) async {}

  @override
  Future<void> enable({String species = 'dog'}) async {}
}

void _surface(WidgetTester tester, {double height = 3400}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

Widget _app(Widget home, {WalksState? state}) {
  SharedPreferences.setMockInitialValues(const {});
  return ProviderScope(
    overrides: [
      walksControllerProvider
          .overrideWith(() => _FakeWalks(state ?? _ready())),
      petsListProvider.overrideWith((ref) async => const [_buddy]),
      activePetProvider.overrideWithValue(_buddy),
    ],
    child: MaterialApp(home: home),
  );
}

void main() {
  group('the comfort band is never the action ladder', () {
    test('no band tone is one of the six safety-locked hues', () {
      const ladder = [
        AppColors.emergencyDark,
        AppColors.emergencyLight,
        AppColors.monitorDark,
        AppColors.monitorLight,
        AppColors.actionBookVisit,
        AppColors.actionWatch,
      ];
      for (final tone in WalkBand.allTones) {
        expect(ladder, isNot(contains(tone)),
            reason: 'a walk band must never wear a triage colour');
      }
    });

    test('bands agree with the scorer’s own thresholds', () {
      expect(walkBand(95), WalkBand.ideal);
      expect(walkBand(72), WalkBand.good);
      expect(walkBand(50), WalkBand.fair);
      expect(walkBand(10), WalkBand.poor);
      // isGood is >= 70, and everything at or above it reads as walkable.
      expect(walkBand(70).tone, walkBand(85).tone);
    });

    test('every band talks about the weather, never the pet', () {
      for (final band in WalkBand.values) {
        expect(band.blurb.toLowerCase(), isNot(contains('your pet')));
        expect(band.blurb.toLowerCase(), isNot(contains('healthy')));
      }
    });
  });

  group('the daily outlook', () {
    test('reports each day’s range and its best walkable hour', () {
      final days = dailyWalkOutlook(_forecast(), days: 5);
      expect(days, hasLength(3));
      expect(days.first.day, DateTime(2026, 8, 7));
      // Day three is 35°C under a hard sun — its best hour is still poor.
      expect(days.last.band, WalkBand.poor);
      expect(days.first.band, WalkBand.ideal);
      expect(days.first.maxC, greaterThan(days.first.minC));
    });

    test('the day score is the best hour, and the tile can say which', () {
      final mixed = [
        _hour(DateTime(2026, 8, 7, 7), temp: 17), // lovely
        _hour(DateTime(2026, 8, 7, 15), temp: 34), // brutal
      ];
      final day = dailyWalkOutlook(mixed).single;
      expect(day.score, scoreWalkHour(mixed.first).score);
      // Without the hour, an "Ideal" chip over "34° / 17°" invites a walk at
      // noon on a day whose only kind hour is at seven.
      expect(day.bestHour, 7);
      expect(day.bestHourLabel, '07:00');
      expect(day.maxC, 34);
    });

    test('an empty forecast produces no days', () {
      expect(dailyWalkOutlook(const []), isEmpty);
    });

    test('labels today and tomorrow by name', () {
      final now = DateTime(2026, 8, 7);
      expect(outlookDayLabel(now, now: now), 'Today');
      expect(
          outlookDayLabel(now.add(const Duration(days: 1)), now: now),
          'Tomorrow');
      expect(outlookDayLabel(DateTime(2026, 8, 12), now: now), 'Wed');
    });
  });

  group('the hints replace a prescription with the weather', () {
    test('never name a duration or a distance', () {
      for (final temp in const [-5.0, 5.0, 18.0, 24.0, 30.0]) {
        final hints = walkHints(
            _hour(DateTime(2026, 8, 7, 9), temp: temp), const []);
        for (final h in hints) {
          final text = '${h.label} ${h.body}'.toLowerCase();
          for (final banned in const [
            'minute',
            'km',
            'kilometre',
            'calorie',
            'kcal',
          ]) {
            expect(text, isNot(contains(banned)),
                reason: '"$banned" at $temp°C');
          }
        }
      }
    });

    test('heat moves the ground advice, cold moves it back', () {
      final hot = walkHints(_hour(DateTime(2026, 8, 7, 14), temp: 30), const []);
      expect(hot.map((h) => h.body).join(), contains('Pavement holds heat'));

      final cold =
          walkHints(_hour(DateTime(2026, 1, 7, 8), temp: -3), const []);
      expect(cold.map((h) => h.body).join(), contains('Grit and ice'));
    });

    test('the best window is quoted when there is one, and said to be absent '
        'when there is not', () {
      final withWindow = walkHints(
        _hour(DateTime(2026, 8, 7, 9)),
        [
          WalkWindow(
              start: DateTime(2026, 8, 7, 10),
              end: DateTime(2026, 8, 7, 12),
              score: 88)
        ],
      );
      expect(withWindow.first.body, contains('10:00 – 12:00'));

      final none = walkHints(_hour(DateTime(2026, 8, 7, 9)), const []);
      expect(none.first.body, contains('No comfortable stretch'));
    });
  });

  group('smart_walks, drawn', () {
    testWidgets('every block the reference draws is present', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const WalksScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Smart Walks'), findsOneWidget);
      expect(find.byKey(const Key('module_pet_name')), findsOneWidget);
      expect(find.byKey(const Key('walks_stats')), findsOneWidget);
      expect(find.byKey(const Key('walks_track_card')), findsOneWidget);
      expect(find.byKey(const Key('walks_conditions_card')), findsOneWidget);
      expect(find.byKey(const Key('walks_places_card')), findsOneWidget);
      expect(find.byKey(const Key('walks_log_card')), findsOneWidget);
      expect(find.byKey(const Key('walks_badges_card')), findsOneWidget);
      expect(find.byKey(const Key('walk_reminder_card')), findsOneWidget);
      expect(find.byKey(const Key('walks_tips_card')), findsOneWidget);
      expect(find.byKey(const Key('walks_attribution')), findsOneWidget);
      expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget);
    });

    testWidgets('the four tiles count today’s conditions, not tracked walks',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const WalksScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Kind hours left'), findsOneWidget);
      expect(find.text('Best window'), findsOneWidget);
      expect(find.text('Comfort now'), findsOneWidget);
      expect(find.text('Parks nearby'), findsOneWidget);
      // Two parks were supplied, and two is what the tile says.
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('the nearby places are real rows that go to directions',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const WalksScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Kent Park'), findsOneWidget);
      expect(find.text('Sazova Dog Run'), findsOneWidget);
      expect(find.textContaining('dog park'), findsOneWidget);
    });

    testWidgets('tracking, the log and the badges keep their place and say Soon',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const WalksScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Current Walk'), findsOneWidget);
      expect(find.byKey(const Key('walks_start')), findsOneWidget);
      expect(find.text('Start a Walk · Soon'), findsOneWidget);
      expect(find.byKey(const Key('walks_hold')), findsOneWidget);
      expect(find.byKey(const Key('walks_finish')), findsOneWidget);
      expect(find.text('Recent Walks'), findsOneWidget);
      expect(find.byKey(const Key('walks_log_empty')), findsOneWidget);
      expect(find.byKey(const Key('walks_badges_rail')), findsOneWidget);
    });

    testWidgets('tapping a Soon control explains rather than doing nothing',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const WalksScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('walks_track_panel')));
      await tester.pumpAndSettle();
      expect(find.textContaining('does not follow a walk yet'), findsOneWidget);
      expect(find.textContaining('What tracking would need'), findsOneWidget);
    });

    testWidgets('without location it still draws the page and offers the ask',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(
          _app(const WalksScreen(), state: const WalksInitial()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('walks_conditions_placeholder')),
          findsOneWidget);
      expect(find.byKey(const Key('walks_enable')), findsOneWidget);
      // The rest of the page is still there — no dead-end centred message.
      expect(find.byKey(const Key('walks_track_card')), findsOneWidget);
      expect(find.byKey(const Key('walks_badges_card')), findsOneWidget);
    });
  });

  group('weather_walk_advisor, drawn', () {
    testWidgets('every block the reference draws is present', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const WeatherWalkAdvisorScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Weather Walk Advisor'), findsOneWidget);
      expect(find.byKey(const Key('advisor_now_card')), findsOneWidget);
      expect(find.byKey(const Key('advisor_hourly_card')), findsOneWidget);
      expect(find.byKey(const Key('walks_hourly')), findsOneWidget);
      expect(find.byKey(const Key('advisor_guidance_card')), findsOneWidget);
      expect(find.byKey(const Key('advisor_outlook_card')), findsOneWidget);
      expect(find.byKey(const Key('advisor_outlook_rail')), findsOneWidget);
      expect(find.byKey(const Key('advisor_tips_card')), findsOneWidget);
      expect(find.byKey(const Key('advisor_attribution')), findsOneWidget);
    });

    testWidgets('the dial and the hour chips carry the scorer’s own numbers',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const WeatherWalkAdvisorScreen()));
      await tester.pumpAndSettle();

      final expected = scoreWalkHour(_forecast().first).score;
      expect(find.text('$expected'), findsWidgets);
      expect(find.text('Walk comfort'), findsOneWidget);
      expect(find.text('Now'), findsOneWidget);
    });

    testWidgets('the guidance says whose call the distance is', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const WeatherWalkAdvisorScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('advisor_duration_note')), findsOneWidget);
      expect(find.textContaining('that is your vet’s call'), findsOneWidget);
    });
  });

  group('safety', () {
    testWidgets('neither screen prescribes exercise, brands itself AI, or '
        'counts calories', (tester) async {
      _surface(tester);
      for (final screen in <Widget>[
        const WalksScreen(),
        const WeatherWalkAdvisorScreen(),
      ]) {
        await tester.pumpWidget(_app(screen));
        await tester.pumpAndSettle();

        for (final banned in const [
          'AI Suggestion',
          'AI Walk',
          'kcal',
          'Calories',
          'calories burned',
          '60 minutes',
          'Ideal distance',
          'Estimated duration',
          'heart health',
          'weight control',
          'Health Score',
        ]) {
          expect(find.textContaining(banned), findsNothing,
              reason: '"$banned" on ${screen.runtimeType}');
        }
      }
    });

    testWidgets('the badges are about the habit, never about how far the '
        'animal went', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const WalksScreen()));
      await tester.pumpAndSettle();

      for (final badge in kWalkBadges) {
        final text = '${badge.title} ${badge.goal}'.toLowerCase();
        for (final banned in const ['km', 'kcal', 'calorie', 'burn']) {
          expect(text, isNot(contains(banned)), reason: badge.title);
        }
      }
      // Only the first badges are laid out — the rail is horizontal and lazy.
      expect(find.text('First Ten'), findsOneWidget);
    });

    testWidgets('the walking notes point at the vet rather than prescribing',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const WalksScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('All notes'));
      await tester.pumpAndSettle();
      expect(find.textContaining('that is your vet’s call'), findsOneWidget);
    });

    test('the tips never dose, diagnose or prescribe', () {
      for (final tip in kWalkTips) {
        final t = tip.toLowerCase();
        for (final banned in const [
          'minutes a day',
          'ideal distance',
          'should walk',
          'diagnos',
          'treat',
        ]) {
          expect(t, isNot(contains(banned)), reason: tip);
        }
      }
    });
  });
}
