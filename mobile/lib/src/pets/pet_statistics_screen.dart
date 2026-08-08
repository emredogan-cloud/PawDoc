import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/dates.dart';
import '../core/friendly_error.dart';
import '../core/living_pet_avatar.dart';
import '../core/paw_nav_bar.dart';
import '../core/pet_display.dart';
import '../health/health_event.dart';
import '../health/health_sections.dart';
import '../health/history_timeline_screen.dart';
import '../health/medication_tracker_screen.dart';
import '../health/timeline.dart';
import '../health/vaccination_manager_screen.dart';
import '../home/home_sections.dart';
import '../reminders/reminder.dart';
import '../reminders/reminders_repository.dart';
import '../reminders/reminders_screen.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'active_pet.dart';
import 'pet.dart';
import 'pet_form_screen.dart';
import 'pet_profile_screen.dart';
import 'pets_repository.dart';

/// The record, counted, rebuilt against mockup `pet_statistics`.
///
/// Pet rail, the overview tiles, the trend chart, the Care Score dial, the
/// records breakdown, the category bars, the highlights and the pet
/// comparison — over the app's bottom navigation.
///
/// ## The most claim-heavy mockup in the set
///
/// Almost every figure on the reference is a grade on an animal, and one is a
/// feature that does not exist at all.
///
/// | Mockup | Shipped | Why |
/// |---|---|---|
/// | "Health Score · 92/100 · Excellent" | the Care Score and its record band | **D-2** |
/// | "Health Score Trend · average score over time", rising 78 → 92 | **Records Over Time** — how much was logged each month | this is the sparkline rule the result screen already settled: a line that trended better or worse would be a graded verdict on an animal drawn from nothing |
/// | "This Month · 92 · Excellent · +1 point · All good! Keep it up" | the Care Score dial and what it measures | an all-clear and a value judgement, neither of which the app can make |
/// | "Great Job! Buddy's health score has improved by 14 points" | the most recent record, dated | same |
/// | "Suggestion: Consider dental check-up. Regular dental care improves overall health." | **gone** | recommending a procedure is veterinary advice. PawDoc points at the vet; it does not prescribe one |
/// | "Expenses · ₺2,450 · Total Spent" | the tile, marked *Soon* | there is no expense tracking anywhere in the product — no column, no feature. A currency total would be invented money |
/// | "Pet Comparison · Health Score 92 Excellent / 88 Very Good" | Care Score and counted records per pet | comparing animals' health grades; comparing how complete their *records* are is a fact |
///
/// ## Layout departures, and why
///
/// The reference sets the trend chart beside its dial (262 × 101 logical) and
/// the donut beside the category bars (184 each). Its own type is ~7dp, which
/// `RESUME_GUIDE` §5.2 records as not reproducible on a handset. At readable
/// type an eight-month axis does not fit 262 points, so those two pairs are
/// stacked full-width. Every other block keeps the reference's composition.
class PetStatisticsScreen extends ConsumerStatefulWidget {
  const PetStatisticsScreen({super.key});

  @override
  ConsumerState<PetStatisticsScreen> createState() =>
      _PetStatisticsScreenState();
}

/// How far back the page counts.
enum StatsRange {
  threeMonths('Last 3 months', 3),
  sixMonths('Last 6 months', 6),
  twelveMonths('Last 12 months', 12),
  allTime('All time', 0);

  const StatsRange(this.label, this.months);

  final String label;

  /// 0 means everything.
  final int months;
}

/// Everything the page states, counted from the timeline. Pure, so the
/// arithmetic is unit-tested without pumping a widget.
class PetStats {
  const PetStats({
    required this.byType,
    required this.checks,
    required this.monthly,
    required this.monthlyByType,
    required this.monthLabels,
    required this.newest,
  });

  /// `event_type` → how many, for the health events in range.
  final Map<String, int> byType;

  /// `event_type` → that type's own per-month series, oldest first. The
  /// overview tiles each plot *their* line: a "Medications" tile drawing the
  /// total-records series says something it does not mean.
  final Map<String, List<int>> monthlyByType;

  /// The series for one type, or every record when [type] is null.
  List<int> seriesFor(String? type) => type == null
      ? monthly
      : (monthlyByType[type] ?? List<int>.filled(monthly.length, 0));

  /// AI checks in range. Counted separately: an analysis is not a health event
  /// the owner filed.
  final int checks;

  /// Records per month, oldest first.
  final List<int> monthly;
  final List<String> monthLabels;

  /// The most recent record in range, if any.
  final DateTime? newest;

  int get total =>
      byType.values.fold<int>(0, (sum, n) => sum + n) + checks;

  int get thisMonth => monthly.isEmpty ? 0 : monthly.last;
  int get lastMonth => monthly.length < 2 ? 0 : monthly[monthly.length - 2];

  /// The busiest month in range — the scale the "this month" ring reads
  /// against, so a full ring means "your busiest month", never "healthy".
  int get busiestMonth =>
      monthly.isEmpty ? 0 : monthly.reduce((a, b) => a > b ? a : b);

  static const _labels = <String, String>{
    'vet_visit': 'Vet visits',
    'medication': 'Medications',
    'vaccination': 'Vaccinations',
    'lab_result': 'Lab results',
    'weight': 'Weights',
    'custom': 'Notes',
  };

  static String labelFor(String type) => _labels[type] ?? healthEventLabel(type);

  factory PetStats.from(List<TimelineItem> items, {required StatsRange range}) {
    final now = DateTime.now();
    final months = range.months;
    // A month bucket per calendar month in range; all-time spans from the
    // oldest record, capped so the axis stays readable.
    final oldest = items.isEmpty
        ? now
        : items.map((i) => i.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final span = months > 0
        ? months
        : math.max(
            1,
            math.min(
                24, (now.year - oldest.year) * 12 + now.month - oldest.month + 1),
          );
    final start = DateTime(now.year, now.month - (span - 1));

    final buckets = List<int>.filled(span, 0);
    final byType = <String, int>{};
    final seriesByType = <String, List<int>>{};
    var checks = 0;
    DateTime? newest;

    for (final item in items) {
      // "All time" means all time. The 24-month cap exists so the chart's axis
      // stays readable — letting it also filter the *counts* would quietly
      // drop a three-year-old vaccination from a total labelled "all time".
      if (months > 0 && item.date.isBefore(start)) continue;
      final index =
          (item.date.year - start.year) * 12 + item.date.month - start.month;
      final inSpan = index >= 0 && index < span;
      if (inSpan) buckets[index]++;
      final type =
          item.kind == TimelineKind.analysis ? null : (item.eventType ?? 'custom');
      if (type == null) {
        checks++;
      } else {
        byType[type] = (byType[type] ?? 0) + 1;
        if (inSpan) {
          (seriesByType[type] ??= List<int>.filled(span, 0))[index]++;
        }
      }
      if (newest == null || item.date.isAfter(newest)) newest = item.date;
    }

    return PetStats(
      byType: byType,
      checks: checks,
      monthly: buckets,
      monthlyByType: seriesByType,
      monthLabels: [
        for (var i = 0; i < span; i++)
          _monthLabel(DateTime(start.year, start.month + i)),
      ],
      newest: newest,
    );
  }

  static String _monthLabel(DateTime d) =>
      "${monthAbbrev(d).substring(0, 3)} '${d.year.toString().substring(2)}";
}

/// Normalises counts to 0..1 for a sparkline. A flat run of equal values sits
/// at mid-height rather than collapsing onto the floor.
List<double> normalise(List<int> counts) {
  if (counts.isEmpty) return const [];
  final max = counts.reduce((a, b) => a > b ? a : b);
  if (max == 0) return List<double>.filled(counts.length, 0.05);
  return [for (final c in counts) c / max];
}

class _PetStatisticsScreenState extends ConsumerState<PetStatisticsScreen> {
  StatsRange _range = StatsRange.twelveMonths;

  void _push(Widget screen) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => screen));

  void _select(Pet pet) {
    if (pet.id != null) {
      ref.read(activePetIdProvider.notifier).select(pet.id!);
    }
  }

  void _openRange() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: 'Count records from',
        children: [
          for (final r in StatsRange.values)
            HealthRecordRow(
              key: Key('stats_range_${r.name}'),
              leading: HealthGlyphDisc(
                icon: LucideIcons.calendarDays,
                tint: r == _range
                    ? PawTone.of(context).accent
                    : HealthTone.info,
                size: 36,
              ),
              title: r.label,
              subtitle: r == _range ? 'Current' : null,
              chevron: false,
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _range = r);
              },
            ),
        ],
      ),
    );
  }

  void _openScoreNote(int score) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => HealthSheet(
        title: 'Care Score · ${careBand(score)}',
        children: const [
          _Point(
            icon: LucideIcons.fileText,
            text: 'It measures how complete the record is — a name, a breed, a '
                'birthday, a sex, a photo, at least one check and at least one '
                'reminder.',
          ),
          _Point(
            icon: LucideIcons.heartPulse,
            text: 'It is not a health score, and nothing on this page is. '
                'PawDoc has not examined your pet and cannot grade them.',
          ),
          _Point(
            icon: LucideIcons.chartLine,
            text: 'The trend counts how much you logged each month. It goes up '
                'when you file more, not when an animal is better.',
          ),
        ],
      ),
    );
  }

  void _soon(String what) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$what is coming soon.')));
  }

  @override
  Widget build(BuildContext context) {
    final petsAsync = ref.watch(petsListProvider);
    final pets = petsAsync.value ?? const <Pet>[];
    final pet = ref.watch(activePetProvider);

    if (pet == null) return const _NoPet();

    final async = ref.watch(healthTimelineProvider(pet.id!));
    final items = async.value ?? const <TimelineItem>[];
    final stats = PetStats.from(items, range: _range);
    final reminders =
        ref.watch(remindersForPetProvider(pet.id!)).value ?? const <Reminder>[];
    final score = careScore(
      pet,
      hasCheck: items.any((i) => i.kind == TimelineKind.analysis),
      hasReminder: reminders.isNotEmpty,
    );

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          icon: LucideIcons.chartColumn,
          title: 'Pet Statistics',
          subtitle: 'Health insights for your ',
          subtitleTrail: 'furry family',
          actionsWidth: 150,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: HealthActionPill(
                key: const Key('stats_range'),
                label: _range.label,
                icon: LucideIcons.calendarDays,
                dense: true,
                onTap: _openRange,
              ),
            ),
          ],
        ),
        onRefresh: () async {
          ref.invalidate(healthTimelineProvider(pet.id!));
          await ref.read(healthTimelineProvider(pet.id!).future);
        },
        bottomNav: const PawNavBar(detached: true),
        children: [
          gap(2),
          HealthBleed(
            child: _PetRail(
              pets: pets,
              activeId: pet.id,
              onSelect: _select,
              onAdd: () => _push(const PetFormScreen()),
            ),
          ),
          gap(11),
          ...switch (async) {
            AsyncError(:final error) => [
                _Notice(
                  icon: LucideIcons.cloudOff,
                  title: 'Could not load the record',
                  body: friendlyLoadError(error, noun: 'records'),
                ),
              ],
            AsyncLoading() when items.isEmpty => [
                const Center(child: CircularProgressIndicator()),
              ],
            _ => [
                _OverviewCard(stats: stats, onSoon: _soon, onOpen: _push),
                gap(9),
                _TrendCard(stats: stats),
                gap(9),
                _ScoreCard(
                  score: score,
                  stats: stats,
                  petName: pet.name,
                  onExplain: () => _openScoreNote(score),
                ),
                gap(9),
                _BreakdownCard(stats: stats),
                gap(9),
                _CategoriesCard(stats: stats, onOpen: _push),
                gap(9),
                _HighlightsCard(
                  stats: stats,
                  reminders: reminders,
                  petName: pet.name,
                  onReminders: () => _push(const RemindersScreen()),
                  onTimeline: () => _push(const HealthHistoryScreen()),
                ),
                gap(9),
                _ComparisonCard(
                  pets: pets,
                  range: _range,
                  onOpen: (p) {
                    _select(p);
                    _push(PetProfileScreen(pet: p));
                  },
                ),
              ],
          },
          gap(9),
          const _FooterStrip(),
          gap(8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pet rail
// ---------------------------------------------------------------------------

class _PetRail extends StatelessWidget {
  const _PetRail({
    required this.pets,
    required this.activeId,
    required this.onSelect,
    required this.onAdd,
  });

  final List<Pet> pets;
  final String? activeId;
  final ValueChanged<Pet> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SizedBox(
      height: 132,
      child: ListView(
        key: const Key('stats_pet_rail'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kRecordGutter),
        children: [
          for (final pet in pets) ...[
            _PetTile(
              pet: pet,
              selected: pet.id == activeId,
              onTap: () => onSelect(pet),
            ),
            const SizedBox(width: 8),
          ],
          InkWell(
            key: const Key('stats_add_pet'),
            onTap: onAdd,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 104,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: t.accent.withValues(alpha: 0.04),
                border: Border.all(color: t.accent.withValues(alpha: 0.45)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: t.accent.withValues(alpha: 0.65)),
                    ),
                    child: Icon(LucideIcons.plus, size: 19, color: t.accent),
                  ),
                  const SizedBox(height: 8),
                  Text('Add Pet',
                      style: TextStyle(
                          color: t.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PetTile extends StatelessWidget {
  const _PetTile({
    required this.pet,
    required this.selected,
    required this.onTap,
  });

  final Pet pet;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return InkWell(
      key: Key('stats_pet_${pet.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 104,
        padding: const EdgeInsets.fromLTRB(7, 10, 7, 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? t.accent.withValues(alpha: 0.08) : HealthTone.card,
          border: Border.all(
            color: selected
                ? t.accent
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: selected
                                ? t.accent
                                : Colors.white.withValues(alpha: 0.14),
                            width: selected ? 1.8 : 1),
                      ),
                      child: Center(
                        child: ClipOval(
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: PetPortrait(
                              pet: pet,
                              size: 52,
                              livingAvatar: pet.photoKey == null
                                  ? null
                                  : LivingPetAvatar(
                                      species: pet.species,
                                      size: 52,
                                      seed: pet.id,
                                      photoKey: pet.photoKey,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 19,
                        height: 19,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.accent,
                          border: const Border.fromBorderSide(
                              BorderSide(color: Color(0xFF000608), width: 1.6)),
                        ),
                        child: const Icon(LucideIcons.check,
                            size: 10, color: Color(0xFF06110A)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(petDisplayName(pet.name),
                  maxLines: 1,
                  style: TextStyle(
                      color: selected ? t.accent : Colors.white,
                      fontSize: 13,
                      height: 1.15,
                      fontWeight: FontWeight.w700)),
            ),
            Text(
              pet.breed?.trim().isNotEmpty == true
                  ? pet.breed!.trim()
                  : speciesName(pet.species),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: HealthTone.muted, fontSize: 10.5, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overview
// ---------------------------------------------------------------------------

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.stats,
    required this.onSoon,
    required this.onOpen,
  });

  final PetStats stats;
  final ValueChanged<String> onSoon;
  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(9, 11, 9, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: HealthSectionHead(
              leading:
                  Icon(LucideIcons.chartLine, size: 17, color: t.accent),
              title: 'Overview',
            ),
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _OverviewTile(
                    fieldKey: const Key('stats_tile_records'),
                    icon: LucideIcons.fileText,
                    value: '${stats.total}',
                    label: 'Records',
                    spark: normalise(stats.seriesFor(null)),
                    tint: t.accent,
                    onTap: () => onOpen(const HealthHistoryScreen()),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _OverviewTile(
                    fieldKey: const Key('stats_tile_visits'),
                    icon: LucideIcons.stethoscope,
                    value: '${stats.byType['vet_visit'] ?? 0}',
                    label: 'Vet visits',
                    spark: normalise(stats.seriesFor('vet_visit')),
                    tint: HealthTone.info,
                    onTap: () => onOpen(const HealthHistoryScreen()),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _OverviewTile(
                    fieldKey: const Key('stats_tile_meds'),
                    icon: LucideIcons.pill,
                    value: '${stats.byType['medication'] ?? 0}',
                    label: 'Medications',
                    spark: normalise(stats.seriesFor('medication')),
                    tint: HealthTone.violet,
                    onTap: () => onOpen(const MedicationTrackerScreen()),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  // The mockup's "Expenses · ₺2,450 · Total Spent". PawDoc
                  // tracks no money at all — no column, no feature — so the
                  // tile keeps its slot and says what it is.
                  child: _OverviewTile(
                    fieldKey: const Key('stats_tile_expenses'),
                    icon: LucideIcons.wallet,
                    value: 'Soon',
                    label: 'Expenses',
                    spark: const [],
                    tint: HealthTone.faint,
                    muted: true,
                    onTap: () => onSoon('Tracking what care costs'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.fieldKey,
    required this.icon,
    required this.value,
    required this.label,
    required this.spark,
    required this.tint,
    required this.onTap,
    this.muted = false,
  });

  final Key fieldKey;
  final IconData icon;
  final String value;
  final String label;
  final List<double> spark;
  final Color tint;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: fieldKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(7, 8, 7, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.025),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: tint),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  maxLines: 1,
                  style: TextStyle(
                      color: muted ? HealthTone.faint : Colors.white,
                      fontSize: 19,
                      height: 1.1,
                      fontWeight: FontWeight.w800)),
            ),
            // A fixed two-line slot: four tiles across 393 points leave a ~72dp
            // label, and inside the stretched Row a Text reports its unwrapped
            // height, so the second line would be clipped away.
            SizedBox(
              height: 24,
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: HealthTone.muted, fontSize: 9.5, height: 1.2)),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 22,
              child: spark.length < 2
                  ? const SizedBox.shrink()
                  : HealthSparkline(
                      points: spark, tint: tint, height: 22, dots: false),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trend
// ---------------------------------------------------------------------------

/// The mockup's "Health Score Trend · average score over time".
///
/// **It plots records logged, not health.** A line that trended better or
/// worse would be a graded verdict on an animal drawn from nothing — the rule
/// the result screen's sparkline already settled. The caption says exactly
/// what the line is.
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.stats});

  final PetStats stats;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            leading: Icon(LucideIcons.chartLine, size: 17, color: t.accent),
            title: 'Records Over Time',
          ),
          const SizedBox(height: 2),
          const Text('How much you logged each month — not a score.',
              style: TextStyle(
                  color: HealthTone.dim, fontSize: 11, height: 1.3)),
          const SizedBox(height: 12),
          if (stats.monthly.length < 2)
            const _EmptyLine(
              key: Key('stats_trend_empty'),
              icon: LucideIcons.chartLine,
              text: 'Not enough months yet. Once there are two, the line '
                  'shows how much was filed in each.',
            )
          else
            SizedBox(
              height: 168,
              child: CustomPaint(
                key: const Key('stats_trend_chart'),
                painter: _TrendPainter(
                  counts: stats.monthly,
                  labels: stats.monthLabels,
                  tint: t.accent,
                ),
                size: Size.infinite,
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.counts,
    required this.labels,
    required this.tint,
  });

  final List<int> counts;
  final List<String> labels;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 24.0;
    const bottomPad = 22.0;
    const topPad = 12.0;
    final plotW = size.width - leftPad;
    final plotH = size.height - bottomPad - topPad;
    if (plotW <= 0 || plotH <= 0) return;

    final maxCount = counts.reduce((a, b) => a > b ? a : b);
    final top = maxCount == 0 ? 1 : maxCount;

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    final axisStyle = TextStyle(
        color: HealthTone.faint, fontSize: 9, height: 1.1);

    void label(String text, Offset at, {bool right = false}) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: axisStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at.translate(right ? -tp.width : 0, 0));
    }

    // Four horizontal rules, labelled with a count.
    for (var i = 0; i <= 3; i++) {
      final y = topPad + plotH * (i / 3);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), grid);
      final value = (top * (1 - i / 3)).round();
      label('$value', Offset(leftPad - 4, y - 5), right: true);
    }

    final dx = counts.length == 1 ? 0.0 : plotW / (counts.length - 1);
    Offset at(int i) => Offset(
          leftPad + dx * i,
          topPad + plotH * (1 - counts[i] / top),
        );

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < counts.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      Path.from(path)
        ..lineTo(at(counts.length - 1).dx, topPad + plotH)
        ..lineTo(at(0).dx, topPad + plotH)
        ..close(),
      Paint()..color = tint.withValues(alpha: 0.10),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = tint,
    );

    // Every other month label when the axis is crowded, so nothing overlaps.
    final step = counts.length > 7 ? 2 : 1;
    for (var i = 0; i < counts.length; i++) {
      canvas.drawCircle(at(i), 3.4, Paint()..color = tint);
      canvas.drawCircle(
          at(i), 3.4, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF0A0F0B));
      if (i % step == 0 && i < labels.length) {
        final tp = TextPainter(
          text: TextSpan(text: labels[i], style: axisStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final x = (at(i).dx - tp.width / 2)
            .clamp(0.0, size.width - tp.width);
        tp.paint(canvas, Offset(x, size.height - bottomPad + 7));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.counts != counts || old.tint != tint;
}

// ---------------------------------------------------------------------------
// The Care Score dial
// ---------------------------------------------------------------------------

/// The mockup's "This Month · 92 · Excellent · +1 point · All good! Keep it up".
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.score,
    required this.stats,
    required this.petName,
    required this.onExplain,
  });

  final int score;
  final PetStats stats;
  final String petName;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final change = stats.thisMonth - stats.lastMonth;
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 12, 11, 12),
      onTap: onExplain,
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: CustomPaint(
              key: const Key('stats_score_dial'),
              painter: _DialPainter(value: score / 100, tint: t.accent),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$score',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            height: 1.1,
                            fontWeight: FontWeight.w800)),
                    Text(careBand(score),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: t.accent, fontSize: 10, height: 1.2)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Care Score',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  'How complete ${petDisplayPossessive(petName)} record is. '
                  'Not a health score — PawDoc has not examined them.',
                  style: const TextStyle(
                      color: HealthTone.dim, fontSize: 11.5, height: 1.35),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(
                      change >= 0
                          ? LucideIcons.trendingUp
                          : LucideIcons.trendingDown,
                      size: 14,
                      color: HealthTone.muted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      switch (change) {
                        0 => 'Same number of records as last month',
                        > 0 => '$change more record'
                            '${change == 1 ? '' : 's'} than last month',
                        _ => '${-change} fewer record'
                            '${change == -1 ? '' : 's'} than last month',
                      },
                      maxLines: 2,
                      style: const TextStyle(
                          color: HealthTone.muted, fontSize: 11, height: 1.3),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({required this.value, required this.tint});

  final double value;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = math.min(size.width, size.height) / 2 - 5;
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = Colors.white.withValues(alpha: 0.08),
    );
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      2 * math.pi * value.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = tint,
    );
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.value != value || old.tint != tint;
}

// ---------------------------------------------------------------------------
// Breakdown
// ---------------------------------------------------------------------------

/// The donut's slice colours.
///
/// Decorative, and clear of the action ladder's four safety-locked hues — a
/// red wedge beside "Vet visits" reads as a severity signal.
/// `pet_statistics_test` pins the separation, as `vaccineTint` and
/// `reminderTint` are pinned.
List<Color> breakdownTints(BuildContext context) => [
      PawTone.of(context).accent,
      HealthTone.violet,
      HealthTone.info,
      HealthTone.teal,
      HealthTone.gold,
      HealthTone.coral,
    ];

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.stats});

  final PetStats stats;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final palette = breakdownTints(context);
    final entries = [
      ...stats.byType.entries
          .map((e) => (PetStats.labelFor(e.key), e.value))
          .toList()
        ..sort((a, b) => b.$2.compareTo(a.$2)),
      if (stats.checks > 0) ('AI checks', stats.checks),
    ];

    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            leading: Icon(LucideIcons.chartPie, size: 17, color: t.accent),
            title: 'Records Breakdown',
          ),
          const SizedBox(height: 2),
          const Text('By record type',
              style: TextStyle(
                  color: HealthTone.dim, fontSize: 11, height: 1.3)),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const _EmptyLine(
              key: Key('stats_breakdown_empty'),
              icon: LucideIcons.chartPie,
              text: 'Nothing filed in this range yet.',
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 118,
                  height: 118,
                  child: CustomPaint(
                    key: const Key('stats_donut'),
                    painter: _DonutPainter(
                      values: [for (final e in entries) e.$2],
                      colors: palette,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Total',
                              style: TextStyle(
                                  color: HealthTone.muted,
                                  fontSize: 10,
                                  height: 1.2)),
                          Text('${stats.total}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < entries.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: palette[i % palette.length],
                              ),
                            ),
                            const SizedBox(width: 7),
                            // Weighted shares: the label and the count give
                            // proportionally rather than the count being
                            // pushed off the row.
                            Flexible(
                              flex: 5,
                              child: Text(entries[i].$1,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      height: 1.25)),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              flex: 4,
                              child: Text(
                                '${entries[i].$2} '
                                '(${_percent(entries[i].$2, stats.total)}%)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    color: HealthTone.muted,
                                    fontSize: 11,
                                    height: 1.25),
                              ),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static int _percent(int part, int whole) =>
      whole == 0 ? 0 : (part * 100 / whole).round();
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values, required this.colors});

  final List<int> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (sum, v) => sum + v);
    if (total == 0) return;
    final centre = (Offset.zero & size).center;
    final radius = math.min(size.width, size.height) / 2 - 6;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = 2 * math.pi * values[i] / total;
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        start,
        // A hair of separation so adjacent slices read as two.
        math.max(0, sweep - 0.02),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 17
          ..color = colors[i % colors.length],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.values != values;
}

// ---------------------------------------------------------------------------
// Categories
// ---------------------------------------------------------------------------

class _CategoriesCard extends StatelessWidget {
  const _CategoriesCard({required this.stats, required this.onOpen});

  final PetStats stats;
  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final rows = [
      ('vaccination', LucideIcons.syringe, const VaccinationManagerScreen()),
      ('medication', LucideIcons.pill, const MedicationTrackerScreen()),
      ('vet_visit', LucideIcons.stethoscope, const HealthHistoryScreen()),
      ('lab_result', LucideIcons.flaskConical, const HealthHistoryScreen()),
      ('custom', LucideIcons.notebookPen, const HealthHistoryScreen()),
    ];
    final max = rows
        .map((r) => stats.byType[r.$1] ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            leading: Icon(LucideIcons.layers, size: 17, color: t.accent),
            title: 'Top Health Categories',
          ),
          const SizedBox(height: 2),
          const Text('Based on records',
              style: TextStyle(
                  color: HealthTone.dim, fontSize: 11, height: 1.3)),
          const SizedBox(height: 11),
          for (final (type, icon, target) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: InkWell(
                key: Key('stats_category_$type'),
                onTap: () => onOpen(target),
                borderRadius: BorderRadius.circular(10),
                child: Row(children: [
                  Icon(icon, size: 16, color: t.accent),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(PetStats.labelFor(type),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                height: 1.25)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: max == 0
                                ? 0
                                : (stats.byType[type] ?? 0) / max,
                            minHeight: 5,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.07),
                            valueColor: AlwaysStoppedAnimation(t.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 26,
                    child: Text('${stats.byType[type] ?? 0}',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Highlights
// ---------------------------------------------------------------------------

/// The mockup's "Insights & Highlights": "Great Job! …improved by 14 points",
/// a reminder, and "Suggestion: Consider dental check-up."
///
/// The first grades the animal and the third prescribes a procedure —
/// veterinary advice PawDoc does not give. What survives is what the app
/// actually knows: when the last record was filed, what is due next, and how
/// many months the record covers.
class _HighlightsCard extends StatelessWidget {
  const _HighlightsCard({
    required this.stats,
    required this.reminders,
    required this.petName,
    required this.onReminders,
    required this.onTimeline,
  });

  final PetStats stats;
  final List<Reminder> reminders;
  final String petName;
  final VoidCallback onReminders;
  final VoidCallback onTimeline;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final next = reminders.where((r) => !r.isPastDue).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final soonest = next.isEmpty ? null : next.first;

    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            leading: Icon(LucideIcons.lightbulb, size: 17, color: t.accent),
            title: 'Highlights',
          ),
          const SizedBox(height: 10),
          _Highlight(
            key: const Key('stats_highlight_latest'),
            icon: LucideIcons.fileText,
            title: 'Most recent record',
            body: stats.newest == null
                ? 'Nothing filed in this range yet.'
                : 'Filed ${shortDate(stats.newest!)}. '
                    '${stats.total} record${stats.total == 1 ? '' : 's'} in '
                    'range.',
            onTap: onTimeline,
          ),
          const SizedBox(height: 8),
          _Highlight(
            key: const Key('stats_highlight_next'),
            icon: LucideIcons.calendarClock,
            title: 'Next reminder',
            body: soonest == null
                ? 'Nothing scheduled. A date you set here also sets a '
                    'notification.'
                : '${soonest.reminderType} · '
                    '${shortDate(soonest.dueDate)} '
                    '(in ${soonest.daysUntilDue} days).',
            onTap: onReminders,
          ),
          const SizedBox(height: 8),
          _Highlight(
            key: const Key('stats_highlight_vet'),
            icon: LucideIcons.stethoscope,
            title: 'What this page is for',
            body: 'Bring it to your next appointment. What the record means '
                'for ${petDisplayName(petName)} is your vet\'s call.',
            tint: HealthTone.info,
          ),
        ],
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({
    required this.icon,
    required this.title,
    required this.body,
    this.onTap,
    this.tint,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final c = tint ?? PawTone.of(context).accent;
    return Material(
      color: HealthTone.raised,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: c),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c,
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(body,
                        style: const TextStyle(
                            color: HealthTone.dim,
                            fontSize: 11.5,
                            height: 1.35)),
                  ],
                ),
              ),
              if (onTap != null)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(LucideIcons.chevronRight,
                      size: 15, color: Colors.white54),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Comparison
// ---------------------------------------------------------------------------

/// The mockup compares health scores across pets. This compares how complete
/// each *record* is, plus what has been filed — facts, not grades.
class _ComparisonCard extends ConsumerWidget {
  const _ComparisonCard({
    required this.pets,
    required this.range,
    required this.onOpen,
  });

  final List<Pet> pets;
  final StatsRange range;
  final ValueChanged<Pet> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = PawTone.of(context);
    if (pets.length < 2) return const SizedBox.shrink();

    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            leading: Icon(LucideIcons.columns3, size: 17, color: t.accent),
            title: 'Pet Comparison',
          ),
          const SizedBox(height: 2),
          const Text('How complete each record is',
              style: TextStyle(
                  color: HealthTone.dim, fontSize: 11, height: 1.3)),
          const SizedBox(height: 11),
          Row(children: const [
            SizedBox(width: 34),
            Expanded(flex: 5, child: _Head('Pet')),
            Expanded(flex: 6, child: _Head('Care Score')),
            Expanded(flex: 3, child: _Head('Records', right: true)),
          ]),
          const SizedBox(height: 4),
          for (final pet in pets)
            _ComparisonRow(
              pet: pet,
              range: range,
              onTap: () => onOpen(pet),
            ),
        ],
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text, {this.right = false});

  final String text;
  final bool right;

  @override
  Widget build(BuildContext context) => Text(text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
          color: HealthTone.faint, fontSize: 10, height: 1.2));
}

class _ComparisonRow extends ConsumerWidget {
  const _ComparisonRow({
    required this.pet,
    required this.range,
    required this.onTap,
  });

  final Pet pet;
  final StatsRange range;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = PawTone.of(context);
    final items = pet.id == null
        ? const <TimelineItem>[]
        : (ref.watch(healthTimelineProvider(pet.id!)).value ??
            const <TimelineItem>[]);
    final reminders = pet.id == null
        ? const <Reminder>[]
        : (ref.watch(remindersForPetProvider(pet.id!)).value ??
            const <Reminder>[]);
    final stats = PetStats.from(items, range: range);
    final score = careScore(
      pet,
      hasCheck: items.any((i) => i.kind == TimelineKind.analysis),
      hasReminder: reminders.isNotEmpty,
    );

    return InkWell(
      key: Key('stats_compare_${pet.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: ClipOval(
                child: PetPortrait(
                  pet: pet,
                  size: 26,
                  livingAvatar: pet.photoKey == null
                      ? null
                      : LivingPetAvatar(
                          species: pet.species,
                          size: 26,
                          seed: pet.id,
                          photoKey: pet.photoKey,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: Text(petDisplayName(pet.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Text('$score',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(careBand(score),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: t.accent, fontSize: 10)),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: score / 100,
                      minHeight: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.07),
                      valueColor: AlwaysStoppedAnimation(t.accent),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text('${stats.total}',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Footer + shared bits
// ---------------------------------------------------------------------------

class _FooterStrip extends StatelessWidget {
  const _FooterStrip();

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      child: Row(children: [
        Icon(LucideIcons.calculator, size: 14, color: t.accent),
        const SizedBox(width: 7),
        const Expanded(
          child: Text('Counted from your own records.',
              maxLines: 2,
              style: TextStyle(
                  color: HealthTone.dim, fontSize: 10.5, height: 1.3)),
        ),
        const SizedBox(width: 8),
        Icon(LucideIcons.lock, size: 14, color: t.accent),
        const SizedBox(width: 7),
        const Expanded(
          child: Text('Private to your account.',
              maxLines: 2,
              style: TextStyle(
                  color: HealthTone.dim, fontSize: 10.5, height: 1.3)),
        ),
      ]),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: PawTone.of(context).accent),
        const SizedBox(width: 11),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: HealthTone.dim, fontSize: 12, height: 1.4)),
        ),
      ],
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 14),
      decoration: BoxDecoration(
        color: HealthTone.raised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: HealthTone.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: HealthTone.dim, fontSize: 11.5, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 26, color: HealthTone.muted),
          const SizedBox(height: 11),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: HealthTone.dim, fontSize: 11.5, height: 1.4)),
        ],
      ),
    );
  }
}

class _NoPet extends StatelessWidget {
  const _NoPet();

  @override
  Widget build(BuildContext context) {
    return PawBackground(
      variant: PawSurface.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const PetModuleAppBar(
          icon: LucideIcons.chartColumn,
          title: 'Pet Statistics',
          subtitle: 'Health insights for your ',
          subtitleTrail: 'furry family',
        ),
        bottomNavigationBar: const PawNavBar(detached: true),
        body: Padding(
          padding: kRecordPadding,
          child: Center(
            child: HealthAddCard(
              title: 'Add a pet to see statistics',
              subtitle: 'Everything on this page is counted from one pet\'s '
                  'records.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PetFormScreen()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
