// Next Evolution Phase 5 — deterministic walk scoring.
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/walks/walk_scorer.dart';
import 'package:pawdoc/src/walks/weather_service.dart';

HourlyWeather hour({
  DateTime? time,
  double temp = 15,
  double wind = 2,
  double precip = 0,
  double? uv,
}) =>
    HourlyWeather(
      time: time ?? DateTime(2026, 7, 24, 12),
      tempC: temp,
      windMs: wind,
      precipMm: precip,
      uvIndex: uv,
    );

void main() {
  group('scoreWalkHour', () {
    test('mild dry weather is a great walk', () {
      final a = scoreWalkHour(hour(temp: 15));
      expect(a.score, greaterThanOrEqualTo(80));
      expect(a.isGood, isTrue);
      expect(a.reasons, ['Clear and comfortable']);
    });

    test('heat penalizes harder than equivalent cold', () {
      final hot = scoreWalkHour(hour(temp: 30));
      final cold = scoreWalkHour(hour(temp: -6));
      expect(hot.score, lessThan(cold.score),
          reason: 'heat risk is weighted above cold risk');
      expect(hot.isGood, isFalse);
      expect(hot.reasons.first, contains('hot'));
    });

    test('heavy rain sinks the score and says so', () {
      final a = scoreWalkHour(hour(precip: 4));
      expect(a.score, lessThan(70));
      expect(a.reasons.any((r) => r.contains('Heavy rain')), isTrue);
    });

    test('wind and strong summer sun stack penalties', () {
      final a = scoreWalkHour(hour(temp: 24, wind: 10, uv: 9));
      expect(a.reasons.any((r) => r.contains('Windy')), isTrue);
      expect(a.reasons.any((r) => r.contains('Strong sun')), isTrue);
    });

    test('cat framing changes the headline, not the physics', () {
      final dog = scoreWalkHour(hour(temp: 15), species: 'dog');
      final cat = scoreWalkHour(hour(temp: 15), species: 'cat');
      expect(cat.score, dog.score);
      expect(cat.headline, isNot(dog.headline));
    });
  });

  group('bestWalkWindows', () {
    test('finds the contiguous good block and skips the storm', () {
      final day = DateTime(2026, 7, 24);
      final hours = [
        for (var h = 6; h <= 22; h++)
          hour(
            time: DateTime(2026, 7, 24, h),
            temp: 16,
            // Storm 12:00–15:00.
            precip: (h >= 12 && h < 15) ? 5 : 0,
          ),
      ];
      final windows = bestWalkWindows(hours, day: day);
      expect(windows, isNotEmpty);
      // Both surviving blocks are clean; neither includes storm hours.
      for (final w in windows) {
        expect(w.start.hour, isNot(inInclusiveRange(12, 14)));
        expect(w.score, greaterThanOrEqualTo(60));
      }
    });

    test('night hours are excluded from suggestions', () {
      final hours = [
        hour(time: DateTime(2026, 7, 24, 2), temp: 15),
        hour(time: DateTime(2026, 7, 24, 23, 30), temp: 15),
      ];
      expect(bestWalkWindows(hours, day: DateTime(2026, 7, 24)), isEmpty);
    });

    test('empty input yields no windows', () {
      expect(bestWalkWindows(const []), isEmpty);
    });
  });

  group('walkSuggestionCopy', () {
    test('good now → walk now with the pet name', () {
      final copy = walkSuggestionCopy(
        now: scoreWalkHour(hour(temp: 15)),
        windows: const [],
        petName: 'Rex',
      );
      expect(copy, contains('Rex'));
      expect(copy.toLowerCase(), contains('great time'));
    });

    test('poor now with a later window → recommends the window hour', () {
      final copy = walkSuggestionCopy(
        now: scoreWalkHour(hour(precip: 5, temp: 30)),
        windows: [
          WalkWindow(
              start: DateTime(2026, 7, 24, 17),
              end: DateTime(2026, 7, 24, 19),
              score: 88),
        ],
        petName: 'Rex',
      );
      expect(copy, contains('17:00'));
    });

    test('no name falls back gracefully per species', () {
      final copy = walkSuggestionCopy(
        now: scoreWalkHour(hour(temp: 15)),
        windows: const [],
        petName: null,
        species: 'cat',
      );
      expect(copy, contains('your cat'));
    });
  });
}
