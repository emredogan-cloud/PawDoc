/// Deterministic walk-quality scoring (Next Evolution Phase 5).
///
/// A pure function beats a model here: zero cost, zero latency, fully
/// testable, and no safety surface. Scores are comfort guidance about
/// WEATHER — never health advice about the animal.
library;

import 'weather_service.dart';

class WalkAssessment {
  const WalkAssessment({
    required this.score,
    required this.headline,
    required this.reasons,
  });

  /// 0–100 walk-comfort score.
  final int score;

  /// Short human copy, e.g. "Great walk weather".
  final String headline;

  /// Concrete factors ("Light rain expected", "Hot for a flat-faced walk").
  final List<String> reasons;

  bool get isGood => score >= 70;
  bool get isFair => score >= 45 && score < 70;
}

/// A recommended walking window within the forecast.
class WalkWindow {
  const WalkWindow({required this.start, required this.end, required this.score});
  final DateTime start;
  final DateTime end;
  final int score;
}

/// Score one forecast hour for a walk with [species] (dogs walk; for cats the
/// same comfort logic frames "outdoor time"). Deliberately conservative in
/// heat — heat risk rises faster than cold risk for most pets.
WalkAssessment scoreWalkHour(HourlyWeather hour, {String species = 'dog'}) {
  var score = 100.0;
  final reasons = <String>[];

  final t = hour.tempC;
  if (t >= 29) {
    score -= 55;
    reasons.add('Very hot (${t.round()}°C) — pavement and heat risk');
  } else if (t >= 26) {
    score -= 35;
    reasons.add('Hot (${t.round()}°C) — keep it short, carry water');
  } else if (t >= 20) {
    score -= 10;
    reasons.add('Warm (${t.round()}°C)');
  } else if (t >= 8) {
    // The comfort band — no penalty.
  } else if (t >= 0) {
    score -= 10;
    reasons.add('Chilly (${t.round()}°C)');
  } else if (t >= -8) {
    score -= 25;
    reasons.add('Cold (${t.round()}°C) — short walks for small or thin-coated pets');
  } else {
    score -= 45;
    reasons.add('Very cold (${t.round()}°C)');
  }

  final p = hour.precipMm;
  if (p >= 3) {
    score -= 40;
    reasons.add('Heavy rain expected');
  } else if (p >= 0.5) {
    score -= 20;
    reasons.add('Light rain expected');
  } else if (p > 0) {
    score -= 8;
    reasons.add('A drizzle is possible');
  }

  final w = hour.windMs;
  if (w >= 14) {
    score -= 30;
    reasons.add('Very windy');
  } else if (w >= 9) {
    score -= 15;
    reasons.add('Windy');
  }

  final uv = hour.uvIndex ?? 0;
  if (uv >= 8 && t >= 20) {
    score -= 10;
    reasons.add('Strong sun — seek shade');
  }

  final clamped = score.clamp(0, 100).round();
  final String headline;
  if (clamped >= 80) {
    headline = species == 'cat' ? 'Lovely weather outside' : 'Great walk weather';
  } else if (clamped >= 70) {
    headline = 'Good time for a walk';
  } else if (clamped >= 45) {
    headline = 'Walkable, with care';
  } else {
    headline = 'Better to wait';
  }
  return WalkAssessment(
    score: clamped,
    headline: headline,
    reasons: reasons.isEmpty ? const ['Clear and comfortable'] : reasons,
  );
}

/// Best contiguous walk windows among [hours] (same calendar day as
/// [hours.first] unless [day] is given): scans hourly scores, groups adjacent
/// hours ≥ [threshold], returns up to [max] windows, best first.
List<WalkWindow> bestWalkWindows(
  List<HourlyWeather> hours, {
  String species = 'dog',
  DateTime? day,
  int threshold = 60,
  int max = 2,
}) {
  if (hours.isEmpty) return const [];
  final target = day ?? hours.first.time;
  final sameDay = hours
      .where((h) =>
          h.time.year == target.year &&
          h.time.month == target.month &&
          h.time.day == target.day &&
          h.time.hour >= 6 &&
          h.time.hour <= 22)
      .toList();
  final windows = <WalkWindow>[];
  DateTime? start;
  var sum = 0, n = 0;
  void closeWindow(DateTime end) {
    if (start != null && n > 0) {
      windows.add(WalkWindow(start: start!, end: end, score: (sum / n).round()));
    }
    start = null;
    sum = 0;
    n = 0;
  }

  for (final hour in sameDay) {
    final s = scoreWalkHour(hour, species: species).score;
    if (s >= threshold) {
      start ??= hour.time;
      sum += s;
      n++;
    } else {
      closeWindow(hour.time);
    }
  }
  if (sameDay.isNotEmpty) {
    closeWindow(sameDay.last.time.add(const Duration(hours: 1)));
  }
  windows.sort((a, b) => b.score.compareTo(a.score));
  return windows.take(max).toList(growable: false);
}

/// The pet-personalised one-liner for the Home card, e.g.
/// "Today looks perfect for a walk with Rex — best around 17:00."
String walkSuggestionCopy({
  required WalkAssessment now,
  required List<WalkWindow> windows,
  required String? petName,
  String species = 'dog',
}) {
  final name = petName ?? (species == 'cat' ? 'your cat' : 'your dog');
  final verb = species == 'cat' ? 'some fresh air' : 'a walk';
  if (now.isGood) {
    return 'Right now is a great time for $verb with $name.';
  }
  if (windows.isNotEmpty) {
    final best = windows.first;
    final hh = best.start.hour.toString().padLeft(2, '0');
    return 'Best time for $verb with $name today: around $hh:00.';
  }
  if (now.isFair) {
    return '$verb with $name is doable — ${now.reasons.first.toLowerCase()}.'
        .replaceFirst('a walk', 'A walk')
        .replaceFirst('some fresh air', 'Some fresh air');
  }
  return 'Not the best day out for $name — ${now.reasons.first.toLowerCase()}.';
}
