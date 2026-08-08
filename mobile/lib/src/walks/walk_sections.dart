import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../health/health_sections.dart';
import 'walk_scorer.dart';
import 'weather_service.dart';

/// The pieces `smart_walks` and `weather_walk_advisor` share.
///
/// ## The one rule these two screens live under
///
/// **Everything here is about the weather, never about the animal.**
/// `walk_scorer.dart` has said so since it was written, and these two mockups
/// are the first surfaces that push hard against it. What they draw and what
/// ships:
///
/// | Reference | Shipped |
/// |---|---|
/// | "AI Walk Suggestion" | **Not AI.** [scoreWalkHour] is a pure function with no model behind it, and branding it AI would misrepresent it *and* imply the assistant is giving health advice (V-23) |
/// | "Up to 60 minutes a day is ideal for heart health and weight control" | gone — an exercise prescription with a number, on an animal the app has never examined |
/// | "Estimated duration 30–45 min", "Ideal distance 3–5 km" | gone — how far a dog should walk is age, breed, weight and health, which is the vet's call |
/// | "Give a water break every 15–20 minutes" | "Carry water when it is warm" — hydration guidance without a dosing schedule |
/// | "Calories burned · 215 kcal" | gone — it needs weight, gait and metabolism the app does not have, and a fabricated number on a health-adjacent screen is worse than a blank |
/// | "Ideal for Buddy" / "A great day for Buddy!" | "Comfortable conditions for a walk" — the sentence is about the sky |

// ---------------------------------------------------------------------------
// The comfort band
// ---------------------------------------------------------------------------

/// How a walk-comfort score reads in words and colour.
///
/// **None of these may be one of the action ladder's four safety-locked hues.**
/// The reference paints its four bands lime → green → amber → orange, and the
/// last two land on the MONITOR amber and near the EMERGENCY red — which would
/// make a cloudy afternoon look like a triage result. These reuse
/// [HealthTone]'s decorative tints, which `health_tone_test` already pins clear
/// of all six ladder values; `walk_tone_test` pins them again here.
enum WalkBand {
  ideal('Ideal', 'Comfortable conditions for a walk'),
  good('Good', 'Fine for a walk'),
  fair('Fair', 'Walkable, with care'),
  poor('Low', 'Better to wait for a kinder hour');

  const WalkBand(this.label, this.blurb);

  final String label;

  /// One line about the *weather*. Never about the pet.
  final String blurb;

  Color get tone => switch (this) {
        WalkBand.ideal => HealthTone.teal,
        WalkBand.good => HealthTone.teal,
        WalkBand.fair => HealthTone.gold,
        WalkBand.poor => HealthTone.coral,
      };

  /// Every tone above, for the guard test.
  static List<Color> get allTones =>
      [for (final b in WalkBand.values) b.tone];
}

/// Bands a 0–100 comfort score. Thresholds match [WalkAssessment.isGood] and
/// `.isFair` so the ring, the chip and the outlook can never disagree.
WalkBand walkBand(int score) {
  if (score >= 80) return WalkBand.ideal;
  if (score >= 70) return WalkBand.good;
  if (score >= 45) return WalkBand.fair;
  return WalkBand.poor;
}

// ---------------------------------------------------------------------------
// Weather glyphs
// ---------------------------------------------------------------------------

/// A Lucide glyph for a MET Norway symbol code. Falls back to a cloud rather
/// than to nothing — a missing icon reads as a rendering fault.
IconData weatherGlyph(String? symbol) {
  final s = (symbol ?? '').toLowerCase();
  if (s.contains('thunder')) return LucideIcons.cloudLightning;
  if (s.contains('snow')) return LucideIcons.cloudSnow;
  if (s.contains('sleet')) return LucideIcons.cloudHail;
  if (s.contains('rain') || s.contains('shower')) return LucideIcons.cloudRain;
  if (s.contains('fog')) return LucideIcons.cloudFog;
  if (s.contains('partlycloudy')) return LucideIcons.cloudSun;
  if (s.contains('cloudy')) return LucideIcons.cloud;
  if (s.contains('fair')) return LucideIcons.cloudSun;
  if (s.contains('clearsky')) return LucideIcons.sun;
  return LucideIcons.cloud;
}

/// "Partly cloudy" from `partlycloudy_day`. Locale-agnostic, like the rest of
/// this module.
String weatherWord(String? symbol) {
  final s = (symbol ?? '').toLowerCase();
  if (s.contains('thunder')) return 'Thunder';
  if (s.contains('heavysnow')) return 'Heavy snow';
  if (s.contains('snow')) return 'Snow';
  if (s.contains('sleet')) return 'Sleet';
  if (s.contains('heavyrain')) return 'Heavy rain';
  if (s.contains('rain')) return 'Rain';
  if (s.contains('shower')) return 'Showers';
  if (s.contains('fog')) return 'Fog';
  if (s.contains('partlycloudy')) return 'Partly cloudy';
  if (s.contains('cloudy')) return 'Cloudy';
  if (s.contains('fair')) return 'Fair';
  if (s.contains('clearsky')) return 'Clear';
  return 'Overcast';
}

// ---------------------------------------------------------------------------
// The multi-day outlook
// ---------------------------------------------------------------------------

/// One day of the reference's "5 Day Walk Outlook".
class WalkDayOutlook {
  const WalkDayOutlook({
    required this.day,
    required this.minC,
    required this.maxC,
    required this.score,
    required this.bestHour,
    required this.symbol,
  });

  final DateTime day;
  final double minC;
  final double maxC;

  /// The best *daylight* comfort score the day offers — not an average, which
  /// would bury a perfectly good early morning under a hot afternoon.
  final int score;

  /// The hour that earned [score].
  ///
  /// **The tile must print this.** A day peaking at 34°C can still hold an
  /// Ideal hour at six in the morning, and a chip reading "Ideal" over
  /// "34° / 26°" with no time on it invites a walk at noon. The band answers
  /// *whether*; this answers *when*, and without it the first answer is
  /// misleading.
  final int bestHour;
  final String? symbol;

  WalkBand get band => walkBand(score);

  /// `06:00` — the hour the band is about.
  String get bestHourLabel => '${bestHour.toString().padLeft(2, '0')}:00';
}

/// Groups [hours] into calendar days and reports each day's temperature range
/// and its best walkable hour.
///
/// Pure and unit-tested. MET's compact series is hourly for ~2 days and
/// 6-hourly after that, which is exactly why the score is a *max over the
/// day's daylight hours* rather than a reading taken at some fixed time: past
/// day two there may be only four samples, and picking one of them would be
/// arbitrary.
List<WalkDayOutlook> dailyWalkOutlook(
  List<HourlyWeather> hours, {
  String species = 'dog',
  int days = 5,
  DateTime? from,
}) {
  if (hours.isEmpty) return const [];
  final start = _dayOf(from ?? hours.first.time);
  final buckets = <DateTime, List<HourlyWeather>>{};
  for (final h in hours) {
    final day = _dayOf(h.time);
    if (day.isBefore(start)) continue;
    buckets.putIfAbsent(day, () => []).add(h);
  }
  final keys = buckets.keys.toList()..sort();
  final out = <WalkDayOutlook>[];
  for (final key in keys.take(days)) {
    final entries = buckets[key]!;
    final daylight =
        entries.where((h) => h.time.hour >= 6 && h.time.hour <= 22).toList();
    final pool0 = daylight.isEmpty ? entries : daylight;
    var best = -1;
    var bestHour = pool0.first.time.hour;
    for (final h in pool0) {
      final s = scoreWalkHour(h, species: species).score;
      if (s > best) {
        best = s;
        bestHour = h.time.hour;
      }
    }
    if (best < 0) best = 0;
    var minC = entries.first.tempC;
    var maxC = entries.first.tempC;
    for (final h in entries) {
      if (h.tempC < minC) minC = h.tempC;
      if (h.tempC > maxC) maxC = h.tempC;
    }
    // The symbol of the warmest daylight hour — the one a glance is asking
    // about.
    final pool = daylight.isEmpty ? entries : daylight;
    var face = pool.first;
    for (final h in pool) {
      if (h.tempC > face.tempC) face = h;
    }
    out.add(WalkDayOutlook(
      day: key,
      minC: minC,
      maxC: maxC,
      score: best,
      bestHour: bestHour,
      symbol: face.symbol,
    ));
  }
  return out;
}

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// `Today` / `Tomorrow` / `Wed`.
String outlookDayLabel(DateTime day, {DateTime? now}) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final today = _dayOf(now ?? DateTime.now());
  final delta = _dayOf(day).difference(today).inDays;
  if (delta == 0) return 'Today';
  if (delta == 1) return 'Tomorrow';
  return names[day.weekday - 1];
}

// ---------------------------------------------------------------------------
// Comfort hints
// ---------------------------------------------------------------------------

/// A practical, weather-derived note — glyph, label, and what to do about the
/// sky. Never a duration, a distance, or a claim about the animal.
class WalkHint {
  const WalkHint(this.icon, this.label, this.body);

  final IconData icon;
  final String label;
  final String body;
}

/// The reference's four-row advice block, rebuilt out of the forecast.
///
/// Its own rows are "best time · estimated duration · ideal distance · surface".
/// **Two of those cannot ship**: a duration and a distance for an animal are an
/// exercise prescription, and the app has never met the animal. The slots hold
/// what the weather really says instead — the shade, the ground, and the water
/// — and the best window, which is computed and true.
List<WalkHint> walkHints(
  HourlyWeather now,
  List<WalkWindow> windows, {
  String species = 'dog',
}) {
  final t = now.tempC;
  final hints = <WalkHint>[];

  if (windows.isNotEmpty) {
    final w = windows.first;
    hints.add(WalkHint(
      LucideIcons.clock,
      'Kindest hours today',
      '${_hh(w.start)} – ${_hh(w.end)}, by the forecast',
    ));
  } else {
    hints.add(const WalkHint(
      LucideIcons.clock,
      'Kindest hours today',
      'No comfortable stretch in today’s forecast',
    ));
  }

  // Ground temperature is the classic warm-weather hazard and the classic
  // cold-weather one; both are statements about the pavement, not the pet.
  if (t >= 26) {
    hints.add(const WalkHint(LucideIcons.footprints, 'The ground',
        'Pavement holds heat. Grass, shade and earth stay kinder underfoot.'));
  } else if (t <= 0) {
    hints.add(const WalkHint(LucideIcons.footprints, 'The ground',
        'Grit and ice collect between the toes. Rinse and dry paws after.'));
  } else {
    hints.add(const WalkHint(LucideIcons.footprints, 'The ground',
        'Nothing unusual underfoot at this temperature.'));
  }

  if (t >= 22) {
    hints.add(const WalkHint(LucideIcons.droplets, 'Water',
        'Carry water and offer it whenever you stop.'));
  } else {
    hints.add(const WalkHint(LucideIcons.droplets, 'Water',
        'Water on the way back is plenty in this weather.'));
  }

  final uv = now.uvIndex ?? 0;
  if (uv >= 6) {
    hints.add(const WalkHint(LucideIcons.sun, 'Sun',
        'Strong sun. Shaded routes are the comfortable ones.'));
  } else if (now.precipMm > 0) {
    hints.add(const WalkHint(LucideIcons.umbrella, 'Rain',
        'Rain about. A towel by the door saves the hallway.'));
  } else if (now.windMs >= 9) {
    hints.add(const WalkHint(LucideIcons.wind, 'Wind',
        'Windy. Sheltered streets feel several degrees warmer.'));
  } else {
    hints.add(const WalkHint(LucideIcons.cloudSun, 'Conditions',
        'Settled — nothing in the forecast to plan around.'));
  }
  return hints;
}

String _hh(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:00';

/// The standing line both screens close their guidance with.
///
/// Every one of these mockups wants to say how long a dog should walk. This is
/// the sentence that goes where that number would have been, and it is the
/// whole reason the duration and distance rows are gone.
const String kWalkDurationDisclaimer =
    'How long and how far suits your pet depends on their age, breed, weight '
    'and health — that is your vet’s call, not the weather’s.';

// ---------------------------------------------------------------------------
// Small shared widgets
// ---------------------------------------------------------------------------

/// The band chip both screens put under the temperature — "Ideal for a walk".
class WalkBandChip extends StatelessWidget {
  const WalkBandChip({required this.band, this.compact = false, super.key});

  final WalkBand band;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10, vertical: compact ? 4 : 5),
      decoration: BoxDecoration(
        color: band.tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: band.tone.withValues(alpha: 0.45)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(LucideIcons.pawPrint, size: compact ? 11 : 13, color: band.tone),
        SizedBox(width: compact ? 5 : 6),
        Flexible(
          child: Text(
            compact ? band.label : '${band.label} for a walk',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: band.tone,
                fontSize: compact ? 10.5 : 11.5,
                fontWeight: FontWeight.w700),
          ),
        ),
      ]),
    );
  }
}

/// The half-ring dial `weather_walk_advisor` draws its score in.
class WalkScoreDial extends StatelessWidget {
  const WalkScoreDial({
    required this.score,
    this.size = 132,
    super.key,
  });

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final band = walkBand(score);
    return SizedBox(
      width: size,
      height: size * 0.62,
      child: CustomPaint(
        painter: _ArcPainter(
          fraction: score / 100,
          color: band.tone,
          track: Colors.white.withValues(alpha: 0.09),
        ),
        child: Align(
          alignment: const Alignment(0, 0.72),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '$score',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        height: 1,
                        fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(
                    text: '/100',
                    style: TextStyle(
                        color: HealthTone.muted, fontSize: 13, height: 1),
                  ),
                ]),
              ),
              const SizedBox(height: 2),
              const Text('Walk comfort',
                  style: TextStyle(color: HealthTone.muted, fontSize: 10.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.fraction,
    required this.color,
    required this.track,
  });

  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const sweep = 3.14159;
    final rect = Rect.fromLTWH(7, 7, size.width - 14, size.width - 14);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, sweep, sweep, false, base);
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, sweep, sweep * fraction.clamp(0.0, 1.0), false, arc);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.fraction != fraction || old.color != color;
}
