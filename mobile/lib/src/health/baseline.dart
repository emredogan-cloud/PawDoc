import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'timeline.dart';
import 'weight_trend_card.dart' show WeightPoint;

/// The arithmetic behind `know_your_baseline`, and the safety line it draws.
///
/// ## The reference asks for five vital signs the app does not measure
///
/// It prints **resting heart rate 60–100 bpm**, **respiratory rate 15–30
/// breaths/min**, **body temperature 38.0–39.2°C**, **resting time 12–16
/// hrs/day** and **activity 40–90 min/day**, each captioned *"Your Pet's
/// Normal Range"*, each with an average and a sparkline, over a **"Baseline
/// Strength · 92/100 · Excellent"** dial.
///
/// PawDoc has no wearable, no thermometer and no sensor of any kind. Every one
/// of those numbers would be invented — and the ones that are not invented are
/// worse: 60–100 bpm and 38.0–39.2°C are *textbook reference ranges*, and
/// printing a textbook range under a pet's name, captioned as *their* normal,
/// is medical content the app has no standing to publish. A reader who then
/// measured 105 bpm at home would draw a conclusion this product must never
/// invite.
///
/// So a baseline here is **what the owner has written down**: the range their
/// own records actually span, how long they have been keeping them, and where
/// the gaps are. Nothing is graded. Nothing is called normal. A measurement
/// with no records has no numbers — it says so, and says why.
///
/// This is the same rule [WeightTarget] already established for the ideal
/// weight band: the range comes from the owner, ideally from their vet, and
/// until it does there is no band and no verdict.

// ---------------------------------------------------------------------------
// Measures
// ---------------------------------------------------------------------------

/// One row of the reference's vital-signs strip.
enum BaselineMeasure {
  weight('Weight', 'kg', LucideIcons.scale, true),
  heartRate('Resting Heart Rate', 'bpm', LucideIcons.heartPulse, false),
  breathing('Respiratory Rate', 'breaths/min', LucideIcons.wind, false),
  temperature('Body Temperature', '°C', LucideIcons.thermometer, false),
  activity('Activity', 'min/day', LucideIcons.footprints, false);

  const BaselineMeasure(this.label, this.unit, this.icon, this.tracked);

  final String label;
  final String unit;
  final IconData icon;

  /// Whether PawDoc records this at all today. **Only weight does.**
  final bool tracked;

  /// What an owner is told when a measure has no numbers, and why it has none.
  /// Never "coming soon" alone — the reason matters, because the alternative
  /// the reference chose was to print a textbook range instead.
  String get untrackedReason => switch (this) {
        BaselineMeasure.weight => '',
        BaselineMeasure.heartRate =>
          'PawDoc has no way to measure a heartbeat, and it will not print a '
              'textbook range under your pet’s name and call it theirs.',
        BaselineMeasure.breathing =>
          'Counting resting breaths at home is something a vet may ask you to '
              'do. There is nowhere to file it yet, and a made-up range would '
              'be worse than none.',
        BaselineMeasure.temperature =>
          'A temperature needs a thermometer and a steady hand. The app has '
              'neither, so it holds no reading and states no range.',
        BaselineMeasure.activity =>
          'Nothing tracks a walk yet, so there are no minutes to average.',
      };
}

/// The span one measure's own records cover — never a reference range.
class MeasureBaseline {
  const MeasureBaseline({
    required this.measure,
    required this.count,
    this.min,
    this.max,
    this.latest,
    this.first,
    this.last,
    this.series = const [],
  });

  final BaselineMeasure measure;

  /// How many records are in range. **Zero means the tile shows no numbers.**
  final int count;

  final double? min;
  final double? max;
  final double? latest;
  final DateTime? first;
  final DateTime? last;

  /// The points, oldest first, for the tile's sparkline.
  final List<double> series;

  /// [series] scaled to 0..1 for [HealthSparkline], which wants a shape rather
  /// than a scale. A flat run sits mid-height instead of collapsing onto the
  /// floor — the same rule `pet_statistics` normalises by.
  List<double> get normalisedSeries {
    if (series.length < 2) return const [];
    final min = series.reduce((a, b) => a < b ? a : b);
    final max = series.reduce((a, b) => a > b ? a : b);
    if (max - min < 0.0001) return List<double>.filled(series.length, 0.5);
    return [for (final v in series) (v - min) / (max - min)];
  }

  /// Two readings is the floor for a *range*. One is a reading.
  bool get hasRange => count >= 2 && min != null && max != null && max! > min!;

  bool get hasAny => count > 0;

  /// `28.0 – 29.4` — what the owner's own records span. Null until there are
  /// two of them, because a single entry is not a range and drawing it as one
  /// is the first step towards drawing a normal.
  String? get rangeLabel => hasRange
      ? '${_n(min!)} – ${_n(max!)}'
      : (latest == null ? null : _n(latest!));

  String? get latestLabel => latest == null ? null : _n(latest!);

  /// How many days the records span. Null when there are fewer than two.
  int? get spanDays => (first == null || last == null || count < 2)
      ? null
      : last!.difference(first!).inDays;

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

/// Builds the weight baseline from the owner's own entries.
///
/// [since] trims to a window; null means every record ever filed.
MeasureBaseline weightBaseline(List<WeightPoint> points, {DateTime? since}) {
  final inRange = [
    for (final p in points)
      if (since == null || !p.date.isBefore(since)) p,
  ]..sort((a, b) => a.date.compareTo(b.date));
  if (inRange.isEmpty) {
    return const MeasureBaseline(measure: BaselineMeasure.weight, count: 0);
  }
  var min = inRange.first.kg;
  var max = inRange.first.kg;
  for (final p in inRange) {
    if (p.kg < min) min = p.kg;
    if (p.kg > max) max = p.kg;
  }
  return MeasureBaseline(
    measure: BaselineMeasure.weight,
    count: inRange.length,
    min: min,
    max: max,
    latest: inRange.last.kg,
    first: inRange.first.date,
    last: inRange.last.date,
    series: [for (final p in inRange) p.kg],
  );
}

// ---------------------------------------------------------------------------
// The record baseline
// ---------------------------------------------------------------------------

/// What the record itself says about how it has been kept.
///
/// This is the honest replacement for the reference's "Baseline Strength ·
/// 92/100 · Excellent", its "Consistency · 92%" and its "Alerts Triggered · 0".
/// Every field is a count or a date; not one of them is a judgement about an
/// animal, and none of them implies the app is monitoring anything.
class RecordBaseline {
  const RecordBaseline({
    required this.total,
    required this.byType,
    required this.first,
    required this.last,
    required this.longestGapDays,
    required this.monthsCovered,
  });

  final int total;
  final Map<String, int> byType;
  final DateTime? first;
  final DateTime? last;

  /// The longest stretch between two consecutive records. The reference calls
  /// its inverse "Consistency · 92%"; a gap is the same fact without the grade.
  final int? longestGapDays;

  /// How many distinct calendar months hold at least one record.
  final int monthsCovered;

  int get typesCovered => byType.keys.length;

  int? get spanDays =>
      (first == null || last == null) ? null : last!.difference(first!).inDays;

  /// Days since the newest record. The reference has no equivalent; it is the
  /// most useful number on the page for someone deciding whether to log
  /// something today.
  int? daysSinceLast({DateTime? now}) => last == null
      ? null
      : (now ?? DateTime.now()).difference(last!).inDays;

  /// The type with the most records, if any.
  String? get commonestType {
    String? best;
    var bestCount = 0;
    for (final entry in byType.entries) {
      if (entry.value > bestCount) {
        best = entry.key;
        bestCount = entry.value;
      }
    }
    return best;
  }

  factory RecordBaseline.from(List<TimelineItem> items, {DateTime? since}) {
    final inRange = [
      for (final i in items)
        if (since == null || !i.date.isBefore(since)) i,
    ]..sort((a, b) => a.date.compareTo(b.date));
    if (inRange.isEmpty) {
      return const RecordBaseline(
        total: 0,
        byType: {},
        first: null,
        last: null,
        longestGapDays: null,
        monthsCovered: 0,
      );
    }
    final byType = <String, int>{};
    final months = <String>{};
    int? longest;
    DateTime? previous;
    for (final item in inRange) {
      final type = item.eventType ?? (item.action == null ? 'custom' : 'check');
      byType[type] = (byType[type] ?? 0) + 1;
      months.add('${item.date.year}-${item.date.month}');
      if (previous != null) {
        final gap = item.date.difference(previous).inDays;
        if (longest == null || gap > longest) longest = gap;
      }
      previous = item.date;
    }
    return RecordBaseline(
      total: inRange.length,
      byType: byType,
      first: inRange.first.date,
      last: inRange.last.date,
      longestGapDays: longest,
      monthsCovered: months.length,
    );
  }
}

// ---------------------------------------------------------------------------
// Observations
// ---------------------------------------------------------------------------

/// One line of the reference's "Recent Insights" — counted, never praised.
class BaselineNote {
  const BaselineNote(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

/// What the record can be *observed* to say.
///
/// The reference's two are **"Great consistency! Buddy's baseline is very
/// consistent. Keep up the good work!"** and **"Buddy is usually most active
/// between 5 PM – 8 PM"**. The first is praise on a grade the app cannot
/// award; the second is activity tracking that does not exist. These are
/// arithmetic on the owner's own filing, and every one of them is a statement
/// about the *record*.
List<BaselineNote> baselineNotes(
  RecordBaseline record,
  MeasureBaseline weight, {
  DateTime? now,
}) {
  final out = <BaselineNote>[];
  final span = record.spanDays;
  if (record.total == 0) {
    return const [
      BaselineNote(
        LucideIcons.filePlus2,
        'Nothing on file yet',
        'The first record is the one everything after it is compared against.',
      ),
    ];
  }
  if (span != null && span > 0) {
    out.add(BaselineNote(
      LucideIcons.calendarRange,
      'Kept for ${_days(span)}',
      '${record.total} ${record.total == 1 ? 'record' : 'records'} across '
          '${record.monthsCovered} ${record.monthsCovered == 1 ? 'month' : 'months'}.',
    ));
  }
  final gap = record.longestGapDays;
  if (gap != null && gap > 0) {
    out.add(BaselineNote(
      LucideIcons.unlink,
      'Longest gap: ${_days(gap)}',
      'A stretch with nothing filed. Vets read the gaps as well as the '
          'entries.',
    ));
  }
  final since = record.daysSinceLast(now: now);
  if (since != null) {
    out.add(BaselineNote(
      LucideIcons.clock,
      since == 0 ? 'Something filed today' : 'Last entry ${_days(since)} ago',
      'The newest thing on file.',
    ));
  }
  if (weight.hasRange) {
    out.add(BaselineNote(
      LucideIcons.scale,
      'Weights span ${weight.rangeLabel} kg',
      'Across ${weight.count} entries. What that span means is a question for '
          'your vet.',
    ));
  }
  return out;
}

String _days(int n) => n == 1 ? '1 day' : '$n days';

/// The things a vet asks about, which is why the reference's "Factors That Can
/// Affect Baseline" strip survives.
///
/// Its own copy prescribes — *"More exercise can improve vitals"*, *"Keep a
/// healthy weight"*. These say why a factor is worth writing down, and stop
/// there.
const List<(IconData, String, String)> kBaselineFactors = [
  (
    LucideIcons.cake,
    'Age',
    'What is usual changes as an animal gets older. A record kept across '
        'years shows that; one reading cannot.'
  ),
  (
    LucideIcons.scale,
    'Weight',
    'One of the first things a vet asks about — and the one measure this '
        'app keeps.'
  ),
  (
    LucideIcons.sun,
    'Season',
    'Heat, cold and daylight all move how an animal eats, sleeps and moves.'
  ),
  (
    LucideIcons.house,
    'What changed at home',
    'A move, a new animal, a different food, a person away. Worth a note the '
        'day it happens.'
  ),
  (
    LucideIcons.pill,
    'Medication',
    'Anything being given, and when it started. A vet will ask.'
  ),
];
