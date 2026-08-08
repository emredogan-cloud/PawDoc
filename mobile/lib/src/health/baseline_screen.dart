import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/dates.dart';
import '../core/friendly_error.dart';
import '../core/living_pet_avatar.dart';
import '../core/paw_nav_bar.dart';
import '../core/pet_display.dart';
import '../account/user_profile.dart';
import '../export/health_report_service.dart';
import '../health_check/health_check_start_screen.dart';
import '../home/home_sections.dart';
import '../pets/pet.dart';
import '../pets/pet_switcher.dart';
import '../reminders/reminders_repository.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'baseline.dart';
import 'health_event.dart';
import 'health_event_form_screen.dart';
import 'health_sections.dart';
import 'history_timeline_screen.dart';
import 'timeline.dart';
import 'weight_target.dart';
import 'weight_tracking_screen.dart';
import 'weight_trend_card.dart' show WeightPoint, weightPointsProvider;

/// Know Your Baseline, rebuilt against its mockup.
///
/// **The most contract-hostile reference in the set.** It prints five vital
/// signs the app has no sensor for, captions their textbook reference ranges as
/// *"Your Pet's Normal Range"*, grades the animal **92/100 · Excellent**, and
/// closes with *"Everything looks good! Buddy's vitals are stable and well
/// within his normal range."* — an all-clear on measurements that do not exist.
///
/// What ships is the owner's own filing: what has been written down, over what
/// span, in what range **their records** cover, and where the gaps are. The
/// arithmetic lives in `baseline.dart` and is unit-tested; the safety reasoning
/// lives there too.
///
/// | Reference | Shipped |
/// |---|---|
/// | "Baseline Strength · 92/100 · Excellent" | the Care Score — record completeness, banded by `careBand()` (D-2) |
/// | "Key Vital Signs (Your Pet's Normal Range)" | **What You've Measured** — the five tiles keep their place; only weight has numbers, and they are the span of the owner's own entries |
/// | "60 – 100 bpm", "38.0 – 39.2 °C" | nothing. A textbook range under a pet's name is medical content this app has no standing to publish |
/// | "Within baseline" on every point | "within your target range", and only when the owner has set one ([WeightTarget]) |
/// | "Everything looks good! … stable and well within his normal range" | what the record holds, counted |
/// | "Alerts Triggered · 0" | gone — it implies the app is watching something |
/// | "Consistency · 92%" | the longest gap, in days. The same fact without the grade |
/// | "Great consistency! Keep up the good work!" | observations, counted, never praise |
/// | "Most active time · 5 PM – 8 PM" | gone — nothing tracks activity |
/// | "More exercise can improve vitals" / "Keep a healthy weight" | why a vet asks about each factor, and nothing more |
/// | "View Warning Signs" | **Start a health check** — a symptom list with no gate is the one thing this product must not hand out; the Check flow has the emergency override, the quota and the ladder |
/// | "How it works · Watch video" | "Read how it works" — there is no video |
class BaselineScreen extends ConsumerStatefulWidget {
  const BaselineScreen({super.key, required this.pet});

  final Pet pet;

  @override
  ConsumerState<BaselineScreen> createState() => _BaselineScreenState();
}

/// The windows the reference's "Last 30 days ⌄" control offers.
enum BaselineWindow {
  month('Last 30 days', 30),
  quarter('Last 90 days', 90),
  year('Last 12 months', 365),
  all('All time', 0);

  const BaselineWindow(this.label, this.days);

  final String label;

  /// 0 means everything ever filed.
  final int days;

  DateTime? since({DateTime? now}) => days == 0
      ? null
      : (now ?? DateTime.now()).subtract(Duration(days: days));
}

class _BaselineScreenState extends ConsumerState<BaselineScreen> {
  BaselineWindow _window = BaselineWindow.month;
  BaselineMeasure _chart = BaselineMeasure.weight;
  WeightTarget? _target;

  @override
  void initState() {
    super.initState();
    _loadTarget();
  }

  Future<void> _loadTarget() async {
    final target = await WeightTarget.load(widget.pet.id!);
    if (mounted) setState(() => _target = target);
  }

  void _refresh() {
    ref
      ..invalidate(weightPointsProvider(widget.pet.id!))
      ..invalidate(healthTimelineProvider(widget.pet.id!));
  }

  // -------------------------------------------------------------------------
  // Sheets
  // -------------------------------------------------------------------------

  void _explain() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const HealthSheet(
        title: 'What a baseline is here',
        scrollable: true,
        children: [
          HealthDetailRow(
            icon: LucideIcons.notebookPen,
            label: 'Yours, not a textbook’s',
            value: 'A baseline on this page is the range your own records '
                'cover — nothing else. PawDoc never prints a published normal '
                'range under your pet’s name and calls it theirs.',
          ),
          HealthDetailRow(
            icon: LucideIcons.scale,
            label: 'What is measured',
            value: 'Weight. It is the one number the app records, and it is '
                'the one a vet asks about first.',
          ),
          HealthDetailRow(
            icon: LucideIcons.activity,
            label: 'What is not',
            value: 'Heart rate, breathing, temperature and activity. There is '
                'no sensor behind any of them, so those tiles hold no numbers.',
          ),
          HealthDetailRow(
            icon: LucideIcons.stethoscope,
            label: 'What it is for',
            value: 'A vet asks what is usual for your animal. A record kept '
                'over months answers that better than anything measured once.',
          ),
          HealthDetailRow(
            icon: LucideIcons.shieldOff,
            label: 'What it is not',
            value: 'PawDoc is not watching these numbers and will not alert '
                'you about them. Nothing here is a diagnosis or an all-clear.',
          ),
        ],
      ),
    );
  }

  void _explainMeasure(BaselineMeasure measure) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: measure.label,
        scrollable: true,
        children: [
          Text(measure.untrackedReason,
              style: const TextStyle(
                  color: HealthTone.dim, fontSize: 12.5, height: 1.45)),
          const HealthEduCard(
            icon: LucideIcons.stethoscope,
            title: 'If your vet asks you to take this at home',
            body: 'Write it in a note on the health record with the date. It '
                'is the record they will want to see, and it belongs in your '
                'own words rather than in a number the app invented.',
          ),
          HealthPrimaryCta(
            key: const Key('baseline_measure_note'),
            icon: LucideIcons.notebookPen,
            label: 'Add a note',
            onTap: () {
              Navigator.pop(sheetContext);
              _addRecord('custom');
            },
          ),
        ],
      ),
    );
  }

  void _openWindows() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: 'Over what period',
        scrollable: true,
        children: [
          for (final w in BaselineWindow.values)
            HealthRecordRow(
              key: Key('baseline_window_${w.name}'),
              leading: HealthGlyphDisc(
                icon: LucideIcons.calendarDays,
                tint: w == _window
                    ? PawTone.of(context).accent
                    : HealthTone.info,
                size: 36,
              ),
              title: w.label,
              subtitle: w == _window ? 'Current' : null,
              chevron: false,
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _window = w);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _addRecord(String type) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HealthEventFormScreen(
          petId: widget.pet.id!,
          petName: widget.pet.name,
          initialType: type,
        ),
      ),
    );
    if (saved == true) _refresh();
  }

  Future<void> _startCheck() async {
    final isPremium = ref.read(userProfileProvider).maybeWhen(
          data: (p) => p.isPremium,
          orElse: () => false,
        );
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          HealthCheckStartScreen(pet: widget.pet, isPremium: isPremium),
    ));
    if (mounted) _refresh();
  }

  Future<void> _share() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(healthReportServiceProvider).exportForPet(widget.pet);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not prepare the report. Please try again.')));
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final petId = widget.pet.id!;
    final weightsAsync = ref.watch(weightPointsProvider(petId));
    final timelineAsync = ref.watch(healthTimelineProvider(petId));
    final since = _window.since();

    final weights = weightsAsync.value ?? const <WeightPoint>[];
    final items = timelineAsync.value ?? const <TimelineItem>[];
    final weight = weightBaseline(weights, since: since);
    final record = RecordBaseline.from(items, since: since);
    final error = weightsAsync.error ?? timelineAsync.error;
    final loading = weightsAsync.isLoading && timelineAsync.isLoading;

    // Computed exactly as `health_timeline` computes it — same inputs, same
    // helper. Two surfaces printing a different Care Score for one pet is how
    // a number stops meaning anything.
    final hasReminder =
        ref.watch(remindersForPetProvider(petId)).value?.isNotEmpty == true;
    final score = careScore(
      widget.pet,
      hasCheck: items.any((i) => i.kind == TimelineKind.analysis),
      hasReminder: hasReminder,
    );

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          icon: LucideIcons.pawPrint,
          title: 'Know Your Baseline',
          subtitle: 'What you have written down for ',
          subtitleTrail: petDisplayName(widget.pet.name),
          actionsWidth: 108,
          actions: [
            HealthActionPill(
              key: const Key('baseline_history'),
              label: 'History',
              icon: LucideIcons.history,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const HealthHistoryScreen()),
              ),
            ),
          ],
        ),
        bottomNav: const PawNavBar(detached: true),
        onRefresh: () async {
          _refresh();
          await _loadTarget();
        },
        footer: HealthPrimaryCta(
          key: const Key('baseline_add'),
          label: 'Add a Record',
          onTap: () => _addRecord('weight'),
        ),
        children: [
          gap(2),
          PetModuleHeaderCard(
            portrait: PetPortrait(
              pet: widget.pet,
              size: 52,
              livingAvatar: widget.pet.photoKey == null
                  ? null
                  : LivingPetAvatar(
                      species: widget.pet.species,
                      size: 52,
                      seed: widget.pet.id,
                      photoKey: widget.pet.photoKey,
                    ),
            ),
            name: petDisplayName(widget.pet.name),
            meta: petMetaLine(widget.pet),
            onSwitch: () => showPetSwitcher(context, ref),
            trailing: _CareBox(score: score),
          ),
          gap(11),
          _WhyCard(onRead: _explain),
          gap(11),
          if (error != null)
            _Notice(
              icon: LucideIcons.cloudOff,
              title: 'Could not load the record',
              body: friendlyLoadError(error, noun: 'records'),
            )
          else if (loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            _MeasuresCard(
              weight: weight,
              window: _window,
              onWindow: _openWindows,
              onMeasure: _explainMeasure,
              onWeight: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const WeightTrackingScreen()),
              ),
            ),
            gap(11),
            _TrendCard(
              measure: _chart,
              weight: weight,
              target: _target,
              onMeasure: (m) => setState(() => _chart = m),
            ),
            gap(11),
            _SummaryCard(
              record: record,
              weight: weight,
              window: _window,
              onShare: _share,
            ),
            gap(11),
            _FactorsCard(),
            gap(11),
            _NotesCard(notes: baselineNotes(record, weight)),
          ],
          gap(11),
          _ConcernCard(onCheck: _startCheck),
          gap(8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The header aside
// ---------------------------------------------------------------------------

/// The reference's "Baseline Strength · 92/100 · Excellent" dial.
///
/// It is the Care Score under owner decision D-2: record completeness, banded
/// by [careBand]. There is no strength to measure and nothing to call
/// excellent.
class _CareBox extends StatelessWidget {
  const _CareBox({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Container(
      key: const Key('baseline_care'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Record',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: HealthTone.muted, fontSize: 10.5)),
          const SizedBox(height: 2),
          Row(children: [
            Icon(LucideIcons.shieldCheck, size: 15, color: t.accent),
            const SizedBox(width: 5),
            Text('$score',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    height: 1,
                    fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 2),
          Text(careBand(score),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: t.accent, fontSize: 10.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

class _WhyCard extends StatelessWidget {
  const _WhyCard({required this.onRead});

  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      key: const Key('baseline_why_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.accent.withValues(alpha: 0.10),
            ),
            child: Icon(LucideIcons.lightbulb, size: 17, color: t.accent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Why write it down?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        height: 1.2,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                const Text(
                  'A vet’s first question is what is usual for your animal. '
                  'Months of your own records answer that; a single reading '
                  'never can.',
                  style: TextStyle(
                      color: HealthTone.dim, fontSize: 11.5, height: 1.4),
                ),
                const SizedBox(height: 9),
                // The reference offers "Watch video". There is no video.
                HealthActionPill(
                  key: const Key('baseline_how'),
                  label: 'Read how it works',
                  icon: LucideIcons.bookOpen,
                  onTap: onRead,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The reference's vital-signs strip, with only the measure the app really
/// records carrying numbers.
class _MeasuresCard extends StatelessWidget {
  const _MeasuresCard({
    required this.weight,
    required this.window,
    required this.onWindow,
    required this.onMeasure,
    required this.onWeight,
  });

  final MeasureBaseline weight;
  final BaselineWindow window;
  final VoidCallback onWindow;
  final ValueChanged<BaselineMeasure> onMeasure;
  final VoidCallback onWeight;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      key: const Key('baseline_measures_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(LucideIcons.activity, size: 15, color: t.accent),
            const SizedBox(width: 7),
            const Expanded(
              child: Text('What You’ve Measured',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      height: 1.15,
                      fontWeight: FontWeight.w700)),
            ),
            HealthActionPill(
              key: const Key('baseline_window'),
              label: window.label,
              icon: LucideIcons.calendarDays,
              onTap: onWindow,
            ),
          ]),
          const SizedBox(height: 3),
          const Text(
            'The span your own records cover — never a published normal range.',
            style: TextStyle(
                color: HealthTone.dim, fontSize: 11, height: 1.35),
          ),
          const SizedBox(height: 11),
          SizedBox(
            height: 150,
            child: ListView.separated(
              key: const Key('baseline_measures_rail'),
              scrollDirection: Axis.horizontal,
              itemCount: BaselineMeasure.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 9),
              itemBuilder: (context, i) {
                final measure = BaselineMeasure.values[i];
                return _MeasureTile(
                  measure: measure,
                  baseline: measure == BaselineMeasure.weight ? weight : null,
                  onTap: measure.tracked ? onWeight : () => onMeasure(measure),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasureTile extends StatelessWidget {
  const _MeasureTile({
    required this.measure,
    required this.baseline,
    required this.onTap,
  });

  final BaselineMeasure measure;
  final MeasureBaseline? baseline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final has = baseline?.hasAny ?? false;
    return SizedBox(
      width: 138,
      child: Material(
        color: HealthTone.raised,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          key: Key('baseline_measure_${measure.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(measure.icon,
                      size: 15, color: has ? t.accent : HealthTone.faint),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(measure.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: has ? Colors.white : HealthTone.muted,
                            fontSize: 11,
                            height: 1.2,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
                const Spacer(),
                if (has) ...[
                  Text(baseline!.rangeLabel ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: t.accent,
                          fontSize: 19,
                          height: 1.05,
                          fontWeight: FontWeight.w800)),
                  Text(measure.unit,
                      style: const TextStyle(
                          color: HealthTone.muted, fontSize: 10.5)),
                  const SizedBox(height: 5),
                  Text(
                    baseline!.hasRange
                        ? 'Latest ${baseline!.latestLabel} · '
                            '${baseline!.count} entries'
                        : 'One entry so far',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: HealthTone.faint, fontSize: 10, height: 1.2),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 20,
                    child: baseline!.series.length >= 2
                        ? HealthSparkline(
                            points: baseline!.normalisedSeries,
                            tint: t.accent,
                            height: 20,
                            dots: false,
                          )
                        : const SizedBox.shrink(),
                  ),
                ] else ...[
                  const Text('Not tracked',
                      style: TextStyle(
                          color: HealthTone.muted,
                          fontSize: 14,
                          height: 1.1,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  const Text('No sensor, and no invented range.',
                      maxLines: 3,
                      style: TextStyle(
                          color: HealthTone.faint, fontSize: 10, height: 1.3)),
                  const Spacer(),
                  Row(children: [
                    const Text('Why',
                        style: TextStyle(
                            color: HealthTone.muted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600)),
                    const Icon(LucideIcons.chevronRight,
                        size: 12, color: HealthTone.muted),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The reference's trend chart. Its dashed band is a "normal range"; this one
/// is the owner's own target, and there is no band at all until they set one.
class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.measure,
    required this.weight,
    required this.target,
    required this.onMeasure,
  });

  final BaselineMeasure measure;
  final MeasureBaseline weight;
  final WeightTarget? target;
  final ValueChanged<BaselineMeasure> onMeasure;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      key: const Key('baseline_trend_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(LucideIcons.chartLine, size: 15, color: t.accent),
            const SizedBox(width: 7),
            const Expanded(
              child: Text('Trend',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      height: 1.15,
                      fontWeight: FontWeight.w700)),
            ),
            const HealthPill(
                label: 'Weight', tint: HealthTone.info, icon: LucideIcons.scale),
          ]),
          const SizedBox(height: 11),
          if (weight.series.length < 2)
            SizedBox(
              height: 120,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    weight.hasAny
                        ? 'One weight on file. A second makes a line.'
                        : 'No weights on file yet. Two make a line.',
                    key: const Key('baseline_trend_empty'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: HealthTone.faint, fontSize: 12, height: 1.4),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: CustomPaint(
                key: const Key('baseline_trend_chart'),
                size: const Size(double.infinity, 140),
                painter: _TrendPainter(
                  values: weight.series,
                  line: t.accent,
                  target: target,
                ),
              ),
            ),
          const SizedBox(height: 9),
          Text(
            target == null
                ? 'The line is what you weighed and when. PawDoc draws no '
                    'target band, because a healthy weight is a body-condition '
                    'judgement your vet makes.'
                : 'The shaded band is the target you entered (${target!.label}), '
                    'kept on this device. PawDoc does not set one.',
            key: const Key('baseline_trend_note'),
            style: const TextStyle(
                color: HealthTone.faint, fontSize: 10.5, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.values,
    required this.line,
    required this.target,
  });

  final List<double> values;
  final Color line;
  final WeightTarget? target;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    var min = values.reduce((a, b) => a < b ? a : b);
    var max = values.reduce((a, b) => a > b ? a : b);
    if (target != null) {
      if (target!.minKg < min) min = target!.minKg;
      if (target!.maxKg > max) max = target!.maxKg;
    }
    final pad = (max - min) * 0.15;
    min -= pad == 0 ? 1 : pad;
    max += pad == 0 ? 1 : pad;
    final span = max - min;

    double y(double v) => size.height - ((v - min) / span) * size.height;
    double x(int i) => (i / (values.length - 1)) * size.width;

    // The owner's own band, when they set one. Never a computed "normal".
    if (target != null) {
      final rect = Rect.fromLTRB(0, y(target!.maxKg), size.width,
          y(target!.minKg));
      canvas.drawRect(
          rect, Paint()..color = line.withValues(alpha: 0.07));
      final dash = Paint()
        ..color = line.withValues(alpha: 0.35)
        ..strokeWidth = 1;
      for (final edge in [y(target!.maxKg), y(target!.minKg)]) {
        var dx = 0.0;
        while (dx < size.width) {
          canvas.drawLine(
              Offset(dx, edge), Offset(dx + 5, edge), dash);
          dx += 9;
        }
      }
    }

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final p = Offset(x(i), y(values[i]));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = line;
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(Offset(x(i), y(values[i])), 3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.values != values || old.target != target;
}

/// The reference's "Baseline Summary". Its headline is an all-clear; this one
/// counts.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.record,
    required this.weight,
    required this.window,
    required this.onShare,
  });

  final RecordBaseline record;
  final MeasureBaseline weight;
  final BaselineWindow window;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final gap = record.longestGapDays;
    return HomeCard(
      key: const Key('baseline_summary_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HealthSectionHead(
            title: 'What the Record Holds',
            leading: Icon(LucideIcons.chartColumn,
                size: 15, color: HealthTone.muted),
          ),
          const SizedBox(height: 10),
          HealthInfoGrid(
            cells: [
              HealthInfoCell(
                icon: LucideIcons.fileText,
                label: 'Records',
                value: '${record.total}',
              ),
              HealthInfoCell(
                icon: LucideIcons.calendarDays,
                label: 'First entry',
                value: record.first == null ? '—' : shortDate(record.first!),
              ),
              HealthInfoCell(
                icon: LucideIcons.layers,
                label: 'Kinds covered',
                value: '${record.typesCovered} of ${kHealthEventTypes.length}',
              ),
              HealthInfoCell(
                icon: LucideIcons.unlink,
                label: 'Longest gap',
                value: gap == null ? '—' : '$gap days',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            record.total == 0
                ? 'Nothing filed in this period.'
                : '${record.total} ${record.total == 1 ? 'record' : 'records'} '
                    'in ${window.label.toLowerCase()}'
                    '${weight.hasRange ? ', ${weight.count} of them weights' : ''}'
                    '. What they mean is a conversation with your vet.',
            key: const Key('baseline_summary_line'),
            style: const TextStyle(
                color: HealthTone.dim, fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 11),
          HealthActionPill(
            key: const Key('baseline_share'),
            label: 'Share the record',
            icon: LucideIcons.share2,
            onTap: onShare,
          ),
        ],
      ),
    );
  }
}

class _FactorsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return HomeCard(
      key: const Key('baseline_factors_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HealthSectionHead(
            title: 'What Moves the Picture',
            leading: Icon(LucideIcons.sprout,
                size: 15, color: HealthTone.muted),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 132,
            child: ListView.separated(
              key: const Key('baseline_factors_rail'),
              scrollDirection: Axis.horizontal,
              itemCount: kBaselineFactors.length,
              separatorBuilder: (_, _) => const SizedBox(width: 9),
              itemBuilder: (context, i) {
                final (icon, title, body) = kBaselineFactors[i];
                return Container(
                  width: 152,
                  padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
                  decoration: BoxDecoration(
                    color: HealthTone.raised,
                    borderRadius: BorderRadius.circular(15),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.07)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 16, color: HealthTone.gold),
                      const SizedBox(height: 8),
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              height: 1.15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(body,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: HealthTone.faint,
                                fontSize: 10,
                                height: 1.35)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});

  final List<BaselineNote> notes;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      key: const Key('baseline_notes_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HealthSectionHead(
            title: 'What Can Be Observed',
            leading:
                Icon(LucideIcons.eye, size: 15, color: HealthTone.muted),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < notes.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.accent.withValues(alpha: 0.09),
                  ),
                  child: Icon(notes[i].icon, size: 15, color: t.accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(notes[i].title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              height: 1.2,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(notes[i].body,
                          style: const TextStyle(
                              color: HealthTone.dim,
                              fontSize: 11,
                              height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The reference's "When to be concerned?" block — the one thing on the page
/// that was already pointing the right way.
///
/// Its button opens a list of warning signs. An ungated symptom list is the
/// one thing this product must not hand out; the Check flow is where a worry
/// belongs, because that is where the emergency override, the quota rules and
/// the action ladder apply.
class _ConcernCard extends StatelessWidget {
  const _ConcernCard({required this.onCheck});

  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      key: const Key('baseline_concern_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.accent.withValues(alpha: 0.10),
            ),
            child: Icon(LucideIcons.shieldQuestionMark,
                size: 17, color: t.accent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Something looks different?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        height: 1.2,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                const Text(
                  'A change from what you usually see is worth a word with '
                  'your vet — sooner if your pet seems unwell. PawDoc does not '
                  'watch these records and will not alert you about them.',
                  style: TextStyle(
                      color: HealthTone.dim, fontSize: 11.5, height: 1.4),
                ),
                const SizedBox(height: 9),
                HealthActionPill(
                  key: const Key('baseline_check'),
                  label: 'Start a health check',
                  icon: LucideIcons.stethoscope,
                  onTap: onCheck,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => HomeCard(
        radius: 16,
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
        child: Column(
          children: [
            Icon(icon, size: 26, color: HealthTone.muted),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: HealthTone.dim, fontSize: 11.5, height: 1.4)),
          ],
        ),
      );
}
