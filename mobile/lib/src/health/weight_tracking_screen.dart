import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/dates.dart';
import '../core/friendly_error.dart';
import '../core/living_pet_avatar.dart';
import '../core/paw_nav_bar.dart';
import '../core/pet_display.dart';
import '../home/home_sections.dart';
import '../pets/active_pet.dart';
import '../pets/pet.dart';
import '../pets/pet_form_screen.dart';
import '../pets/pet_switcher.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'health_event_form_screen.dart';
import 'health_record_detail.dart';
import 'health_sections.dart';
import 'history_timeline_screen.dart';
import 'timeline.dart';
import 'weight_target.dart';
import 'weight_trend_card.dart';

/// The weight record, rebuilt against mockup `weight_tracking`.
///
/// Summary hero, four counted statistics, a real chart drawn from the logged
/// points, the record list, the add card and the educational footer.
///
/// **Copy departures from the mockup, and why** (layout reproduced in each
/// case):
///
/// | Mockup | Shipped | Reason |
/// |---|---|---|
/// | "Ideal Range (26.0 – 30.0 kg)" | the owner's own target range, or nothing | ideal weight is a body-condition judgement a vet makes; see [WeightTarget] |
/// | "Ideal" badge on every record | the change since the entry before it | a fact about the record, not a verdict on the animal |
/// | "Great job! Buddy is within the ideal weight range." | what the record actually shows, and whose call the rest is | an all-clear the app cannot vouch for |
/// | "helps detect health issues early" | "weight change is one of the first things a vet asks about" | the app does not detect anything |
class WeightTrackingScreen extends ConsumerStatefulWidget {
  const WeightTrackingScreen({super.key});

  @override
  ConsumerState<WeightTrackingScreen> createState() =>
      _WeightTrackingScreenState();
}

class _WeightTrackingScreenState extends ConsumerState<WeightTrackingScreen> {
  /// The window the chart draws, as the mockup's dropdown offers.
  _Window _window = _Window.threeMonths;

  Future<void> _addRecord(Pet pet) async {
    final logged = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HealthEventFormScreen(
            petId: pet.id!, petName: pet.name, initialType: 'weight'),
      ),
    );
    ref
      ..invalidate(weightPointsProvider(pet.id!))
      ..invalidate(healthTimelineProvider(pet.id!));
    if (logged == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Weight added to the record.')));
    }
  }

  Future<void> _editTarget(Pet pet, WeightTarget? current) async {
    final result = await showModalBottomSheet<WeightTarget?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TargetSheet(petName: pet.name, current: current),
    );
    if (result == null) return;
    if (result.minKg <= 0) {
      await WeightTarget.clear(pet.id!);
    } else {
      await WeightTarget.save(pet.id!, result);
    }
    ref.invalidate(weightTargetProvider(pet.id!));
  }

  void _openMenu(Pet pet, WeightTarget? target) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(children: [
        HealthRecordRow(
          key: const Key('weight_menu_target'),
          leading: const HealthGlyphDisc(
              icon: LucideIcons.target, tint: HealthTone.info),
          title: target == null ? 'Set a target range' : 'Edit target range',
          subtitle: 'Ask your vet what suits ${petDisplayName(pet.name)}',
          chevron: false,
          onTap: () {
            Navigator.pop(sheetContext);
            _editTarget(pet, target);
          },
        ),
        HealthRecordRow(
          key: const Key('weight_menu_add'),
          leading: const HealthGlyphDisc(
              icon: LucideIcons.plus, tint: HealthTone.teal),
          title: 'Add a weight record',
          subtitle: 'Log what the scale says today',
          chevron: false,
          onTap: () {
            Navigator.pop(sheetContext);
            _addRecord(pet);
          },
        ),
        HealthRecordRow(
          key: const Key('weight_menu_timeline'),
          leading: const HealthGlyphDisc(
              icon: LucideIcons.calendarDays, tint: HealthTone.violet),
          title: 'Open the full record',
          subtitle: 'Every event, not just weight',
          chevron: false,
          onTap: () {
            Navigator.pop(sheetContext);
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const HealthHistoryScreen()));
          },
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pet = ref.watch(activePetProvider);
    if (pet == null) return const _NoPet();

    final async = ref.watch(weightPointsProvider(pet.id!));
    final target = ref.watch(weightTargetProvider(pet.id!)).value;
    final all = async.value ?? const <WeightPoint>[];
    final windowed = _window.filter(all);
    final newest = all.isEmpty ? null : all.last;

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          icon: LucideIcons.scale,
          title: 'Weight Tracking',
          subtitleLead: petDisplayPossessive(pet.name),
          subtitle: ' weight journey',
          actions: [
            HealthCircleButton(
              key: const Key('weight_menu'),
              icon: LucideIcons.ellipsis,
              tooltip: 'More',
              onTap: () => _openMenu(pet, target),
            ),
          ],
        ),
        onRefresh: () async {
          ref.invalidate(weightPointsProvider(pet.id!));
          await ref.read(weightPointsProvider(pet.id!).future);
        },
        bottomNav: const PawNavBar(detached: true),
        children: [
          gap(2),
          PetModuleHeaderCard(
            portrait: PetPortrait(
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
            name: petDisplayName(pet.name),
            meta: petMetaLine(pet),
            onSwitch: () => showPetSwitcher(context, ref),
            onViewProfile: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PetFormScreen(pet: pet)),
            ),
            trailing: _CurrentWeight(newest: newest, previous: _previous(all)),
          ),
          gap(11),
          HealthStatTiles(
            grouped: true,
            layout: HealthStatLayout.stacked,
            stats: _stats(all, target),
          ),
          gap(11),
          _TrendCard(
            points: windowed,
            target: target,
            window: _window,
            petName: pet.name,
            onWindow: (w) => setState(() => _window = w),
            onSetTarget: () => _editTarget(pet, target),
          ),
          gap(9),
          _SummaryNote(points: windowed, window: _window, petName: pet.name),
          gap(11),
          ...switch (async) {
            AsyncError(:final error) => [
                _Notice(
                  icon: LucideIcons.cloudOff,
                  title: 'Could not load the weight record',
                  body: friendlyLoadError(error, noun: 'weights'),
                ),
              ],
            AsyncLoading() when all.isEmpty => [
                const Center(child: CircularProgressIndicator()),
              ],
            _ when all.isEmpty => [
                _Notice(
                  icon: LucideIcons.scale,
                  title: 'No weights logged yet',
                  body:
                      'Add the number off the scale and the chart starts drawing '
                      'itself. Two entries is all a trend needs.',
                ),
              ],
            _ => [_RecordsCard(points: all, pet: pet)],
          },
          gap(9),
          HealthAddCard(
            key: const Key('weight_add_card'),
            title: 'Add New Weight Record',
            subtitle: 'Log ${petDisplayPossessive(pet.name)} weight and keep '
                'the line honest.',
            onTap: () => _addRecord(pet),
          ),
          gap(9),
          const HealthEduCard(
            title: 'Why weight tracking matters',
            body: 'Weight change is one of the first things a vet asks about, '
                'and it is hard to notice by eye. A logged line gives them '
                'something to read instead of a guess.',
            art: _ScaleArt(),
          ),
          gap(8),
        ],
      ),
    );
  }

  static WeightPoint? _previous(List<WeightPoint> all) =>
      all.length < 2 ? null : all[all.length - 2];

  List<HealthStat> _stats(List<WeightPoint> all, WeightTarget? target) {
    final newest = all.isEmpty ? null : all.last;
    final monthAgo = DateTime.now().subtract(const Duration(days: 30));
    final before = all.where((p) => p.date.isBefore(monthAgo)).toList();
    final delta = (newest != null && before.isNotEmpty)
        ? newest.kg - before.last.kg
        : null;
    final span = all.isEmpty
        ? null
        : (
            all.map((p) => p.kg).reduce((a, b) => a < b ? a : b),
            all.map((p) => p.kg).reduce((a, b) => a > b ? a : b),
          );

    return [
      HealthStat(
        icon: LucideIcons.scale,
        value: newest == null ? '—' : '${_kg(newest.kg)} kg',
        label: 'Current weight',
      ),
      HealthStat(
        icon: delta == null
            ? LucideIcons.minus
            : (delta >= 0 ? LucideIcons.trendingUp : LucideIcons.trendingDown),
        value: delta == null ? '—' : _signed(delta),
        label: 'vs last month',
        // Deliberately the brand accent whichever way it moved: a red "up" or
        // a green "down" would grade the animal, and neither direction is
        // good or bad without a vet's read.
        tint: null,
      ),
      HealthStat(
        icon: LucideIcons.target,
        value: target?.label ?? 'Not set',
        label: target == null ? 'Target range' : 'Target range (yours)',
        caption: target == null ? 'Tap ⋯ to set' : null,
      ),
      HealthStat(
        icon: LucideIcons.calendarCheck,
        value: span == null
            ? '—'
            : '${_kg(span.$1)}–${_kg(span.$2)}',
        label: 'Logged range (kg)',
      ),
    ];
  }
}

String _kg(double v) => v.toStringAsFixed(1);

String _signed(double delta) {
  if (delta.abs() < 0.05) return 'steady';
  return '${delta > 0 ? '+' : '−'}${delta.abs().toStringAsFixed(1)} kg';
}

// ---------------------------------------------------------------------------
// Window
// ---------------------------------------------------------------------------

enum _Window {
  oneMonth('1 Month', 30),
  threeMonths('3 Months', 90),
  sixMonths('6 Months', 182),
  oneYear('1 Year', 365),
  all('All time', null);

  const _Window(this.label, this.days);

  final String label;
  final int? days;

  List<WeightPoint> filter(List<WeightPoint> points) {
    if (days == null) return points;
    final from = DateTime.now().subtract(Duration(days: days!));
    final inside =
        points.where((p) => !p.date.isBefore(from)).toList(growable: false);
    // Never show an empty chart just because the window is short — fall back
    // to everything rather than draw a blank frame.
    return inside.length >= 2 ? inside : points;
  }
}

// ---------------------------------------------------------------------------
// Hero trailing
// ---------------------------------------------------------------------------

class _CurrentWeight extends StatelessWidget {
  const _CurrentWeight({required this.newest, required this.previous});

  final WeightPoint? newest;
  final WeightPoint? previous;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Current Weight',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: HealthTone.muted, fontSize: 10.5)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(newest == null ? '—' : _kg(newest!.kg),
                key: const Key('weight_current'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.05,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 3),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('kg',
                  style: TextStyle(
                      color: HealthTone.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        const SizedBox(height: 3),
        if (newest != null && previous != null)
          HealthPill(
            label: '${_signed(newest!.kg - previous!.kg)} since last',
            tint: t.accent,
          ),
        const SizedBox(height: 3),
        Text(
            newest == null
                ? 'Nothing logged yet'
                : 'Updated ${shortDate(newest!.date)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: HealthTone.faint, fontSize: 10)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The chart
// ---------------------------------------------------------------------------

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.points,
    required this.target,
    required this.window,
    required this.petName,
    required this.onWindow,
    required this.onSetTarget,
  });

  final List<WeightPoint> points;
  final WeightTarget? target;
  final _Window window;
  final String petName;
  final ValueChanged<_Window> onWindow;
  final VoidCallback onSetTarget;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: Text('Weight Trend',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ),
            _WindowMenu(window: window, onSelect: onWindow),
          ]),
          const SizedBox(height: 9),
          Wrap(spacing: 14, runSpacing: 4, children: [
            _LegendDot(
                color: t.accent, label: '${petDisplayPossessive(petName)} weight'),
            InkWell(
              onTap: onSetTarget,
              child: _LegendDot(
                color: HealthTone.info,
                dashed: true,
                label: target == null
                    ? 'Target range · tap to set'
                    : 'Target range (${target!.label})',
              ),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 178,
            child: points.length < 2
                ? const Center(
                    child: Text(
                        'Two entries and this becomes a line.',
                        style: TextStyle(
                            color: HealthTone.faint, fontSize: 12)),
                  )
                : CustomPaint(
                    key: const Key('weight_chart'),
                    size: Size.infinite,
                    painter: WeightChartPainter(
                      points: points,
                      accent: t.accent,
                      target: target,
                      grid: Colors.white.withValues(alpha: 0.07),
                      axisText: HealthTone.faint,
                      valueText: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 20,
        height: 8,
        child: CustomPaint(painter: _LegendPainter(color, dashed)),
      ),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(color: HealthTone.muted, fontSize: 11)),
    ]);
  }
}

class _LegendPainter extends CustomPainter {
  const _LegendPainter(this.color, this.dashed);

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (dashed) {
      for (var x = 0.0; x < size.width; x += 6) {
        canvas.drawLine(Offset(x, y), Offset(x + 3.5, y), paint);
      }
      return;
    }
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    canvas.drawCircle(Offset(size.width / 2, y), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _LegendPainter old) =>
      old.color != color || old.dashed != dashed;
}

/// The chart, drawn from the points. No image, no chart package: a kg axis with
/// gridlines, dated ticks, the owner's target band when there is one, and the
/// line with a labelled dot per entry.
class WeightChartPainter extends CustomPainter {
  const WeightChartPainter({
    required this.points,
    required this.accent,
    required this.grid,
    required this.axisText,
    required this.valueText,
    this.target,
  });

  final List<WeightPoint> points;
  final Color accent;
  final Color grid;
  final Color axisText;
  final Color valueText;
  final WeightTarget? target;

  static const double _leftGutter = 30;
  static const double _bottomGutter = 22;
  static const double _topGutter = 16;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // 1 · the value window, rounded outward to whole kilograms so the labels
    //     are readable numbers rather than 27.34.
    var lo = points.map((p) => p.kg).reduce((a, b) => a < b ? a : b);
    var hi = points.map((p) => p.kg).reduce((a, b) => a > b ? a : b);
    if (target != null) {
      lo = lo < target!.minKg ? lo : target!.minKg;
      hi = hi > target!.maxKg ? hi : target!.maxKg;
    }
    final pad = ((hi - lo) * 0.25).clamp(0.5, 4.0);
    var minKg = (lo - pad).floorToDouble();
    var maxKg = (hi + pad).ceilToDouble();
    if (maxKg - minKg < 2) maxKg = minKg + 2;

    final plot = Rect.fromLTRB(
        _leftGutter, _topGutter, size.width, size.height - _bottomGutter);
    double yFor(double kg) =>
        plot.bottom - (kg - minKg) / (maxKg - minKg) * plot.height;

    final first = points.first.date.millisecondsSinceEpoch.toDouble();
    final last = points.last.date.millisecondsSinceEpoch.toDouble();
    final spanMs = (last - first).abs() < 1 ? 1.0 : last - first;
    double xFor(DateTime d) =>
        plot.left +
        (d.millisecondsSinceEpoch - first) / spanMs * (plot.width - 14) +
        7;

    // 2 · gridlines and the kg axis.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    final steps = ((maxKg - minKg) / _tick(maxKg - minKg)).round();
    for (var i = 0; i <= steps; i++) {
      final kg = minKg + i * _tick(maxKg - minKg);
      if (kg > maxKg + 0.001) break;
      final y = yFor(kg);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _text(canvas, kg.toStringAsFixed(0), Offset(0, y - 6), axisText, 10,
          width: _leftGutter - 6, align: TextAlign.right);
    }
    _text(canvas, 'kg', const Offset(0, 0), axisText, 9.5,
        width: _leftGutter - 6, align: TextAlign.right);

    // 3 · the owner's target band, when they set one.
    if (target != null) {
      final top = yFor(target!.maxKg);
      final bottom = yFor(target!.minKg);
      canvas.drawRect(
        Rect.fromLTRB(plot.left, top, plot.right, bottom),
        Paint()..color = accent.withValues(alpha: 0.07),
      );
      final dash = Paint()
        ..color = HealthTone.info.withValues(alpha: 0.8)
        ..strokeWidth = 1.2;
      for (final y in [top, bottom]) {
        for (var x = plot.left; x < plot.right; x += 8) {
          canvas.drawLine(Offset(x, y), Offset(x + 4, y), dash);
        }
      }
    }

    // 4 · the line.
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(xFor(points[i].date), yFor(points[i].kg));
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = accent
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // 5 · the dots, their values, and the dated ticks. Labels are thinned when
    //     the points would collide — six months of weekly weigh-ins is a wall
    //     of numbers otherwise.
    final every = (points.length / 7).ceil();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final o = Offset(xFor(p.date), yFor(p.kg));
      canvas.drawCircle(o, 4.5, Paint()..color = const Color(0xFF000608));
      canvas.drawCircle(o, 3.4, Paint()..color = accent);
      final show = i % every == 0 || i == points.length - 1;
      if (show) {
        _text(canvas, p.kg.toStringAsFixed(1),
            Offset(o.dx - 17, o.dy - 20), valueText, 10.5,
            width: 34, align: TextAlign.center);
        _text(canvas, '${_month(p.date.month)} ${p.date.day}',
            Offset(o.dx - 20, size.height - _bottomGutter + 6), axisText, 9.5,
            width: 40, align: TextAlign.center);
      }
    }
  }

  /// A whole-kilogram tick that keeps the axis to ~5 labels.
  static double _tick(double span) {
    if (span <= 4) return 1;
    if (span <= 10) return 2;
    if (span <= 25) return 5;
    return 10;
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _month(int m) => _months[m - 1];

  void _text(Canvas canvas, String text, Offset at, Color color, double size,
      {required double width, required TextAlign align}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color, fontSize: size, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: width);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant WeightChartPainter old) =>
      old.points != points ||
      old.target?.minKg != target?.minKg ||
      old.target?.maxKg != target?.maxKg ||
      old.accent != accent;
}

class _WindowMenu extends StatelessWidget {
  const _WindowMenu({required this.window, required this.onSelect});

  final _Window window;
  final ValueChanged<_Window> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return PopupMenuButton<_Window>(
      key: const Key('weight_window_menu'),
      tooltip: 'Chart range',
      color: HealthTone.card,
      onSelected: onSelect,
      itemBuilder: (_) => [
        for (final w in _Window.values)
          PopupMenuItem(
            value: w,
            child: Text(w.label,
                style: TextStyle(
                    color: w == window ? t.accent : Colors.white,
                    fontSize: 13)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(window.label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          const Icon(LucideIcons.chevronDown, size: 13, color: Colors.white70),
        ]),
      ),
    );
  }
}

/// The card the mockup fills with "Great job! Buddy is within the ideal weight
/// range."
///
/// It keeps the position, the star and the density, and states what the record
/// shows rather than passing a verdict — plus whose call the rest of it is.
class _SummaryNote extends StatelessWidget {
  const _SummaryNote({
    required this.points,
    required this.window,
    required this.petName,
  });

  final List<WeightPoint> points;
  final _Window window;
  final String petName;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final String headline;
    if (points.isEmpty) {
      headline = 'Nothing logged yet.';
    } else if (points.length == 1) {
      headline = 'One entry so far — ${_kg(points.first.kg)} kg.';
    } else {
      final delta = points.last.kg - points.first.kg;
      final moved = delta.abs() < 0.05
          ? 'held steady'
          : 'moved ${_signed(delta)}';
      headline = '${points.length} entries over ${window.label.toLowerCase()}. '
          '${petDisplayPossessive(petName)} weight has $moved.';
    }
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: t.accent.withValues(alpha: 0.5)),
            ),
            child: Icon(LucideIcons.star, size: 16, color: t.accent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(headline,
                    key: const Key('weight_summary'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                const Text(
                    'What counts as a healthy weight depends on breed, frame '
                    'and body condition — that one is your vet’s call.',
                    style: TextStyle(
                        color: HealthTone.dim, fontSize: 11, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const _PetOutline(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Records
// ---------------------------------------------------------------------------

class _RecordsCard extends ConsumerStatefulWidget {
  const _RecordsCard({required this.points, required this.pet});

  final List<WeightPoint> points;
  final Pet pet;

  @override
  ConsumerState<_RecordsCard> createState() => _RecordsCardState();
}

class _RecordsCardState extends ConsumerState<_RecordsCard> {
  static const _collapsed = 4;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Newest first, which is how the mockup lists them.
    final rows = widget.points.reversed.toList(growable: false);
    final shown =
        _expanded ? rows : rows.take(_collapsed).toList(growable: false);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            title: 'Weight Records',
            actionLabel: rows.length <= _collapsed
                ? null
                : (_expanded ? 'Show less' : 'View All Records'),
            onAction: () => setState(() => _expanded = !_expanded),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < shown.length; i++)
            Padding(
              padding:
                  EdgeInsets.only(bottom: i == shown.length - 1 ? 0 : 7),
              child: _WeightRow(
                point: shown[i],
                // Newest-first, so the "previous" entry is the next one down.
                previous: i + 1 < rows.length ? rows[i + 1] : null,
                pet: widget.pet,
              ),
            ),
        ],
      ),
    );
  }
}

class _WeightRow extends ConsumerWidget {
  const _WeightRow({
    required this.point,
    required this.previous,
    required this.pet,
  });

  final WeightPoint point;
  final WeightPoint? previous;
  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = PawTone.of(context);
    final delta = previous == null ? null : point.kg - previous!.kg;
    return HealthRecordRow(
      key: Key('weight_row_${point.id ?? point.date.toIso8601String()}'),
      background: HealthTone.raised,
      leading: HealthGlyphDisc(icon: LucideIcons.scale, tint: t.accent),
      title: shortDate(point.date),
      subtitle: point.time,
      middle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_kg(point.kg)} kg',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          // The mockup badges every entry "Ideal". This one states the change,
          // which is a fact about the record rather than a verdict on the pet.
          HealthPill(
            label: delta == null ? 'First entry' : _signed(delta),
            tint: t.accent,
          ),
        ],
      ),
      trailing: point.note == null || point.note!.isEmpty
          ? null
          : SizedBox(
              width: 96,
              child: HealthMetaBlock(
                align: CrossAxisAlignment.start,
                lines: [('Note', false), (point.note!, true)],
              ),
            ),
      onTap: () => showHealthRecordDetail(
        context,
        ref,
        item: TimelineItem(
          kind: TimelineKind.healthEvent,
          date: point.date,
          title: 'Weight',
          subtitle: '${_kg(point.kg)} kg',
          detail: point.note,
          eventType: 'weight',
          id: point.id,
          payload: {
            'weight_kg': point.kg,
            if (point.time != null) 'time': point.time,
          },
        ),
        pet: pet,
        onChanged: () {
          ref
            ..invalidate(weightPointsProvider(pet.id!))
            ..invalidate(healthTimelineProvider(pet.id!));
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Target sheet
// ---------------------------------------------------------------------------

class _TargetSheet extends StatefulWidget {
  const _TargetSheet({required this.petName, required this.current});

  final String petName;
  final WeightTarget? current;

  @override
  State<_TargetSheet> createState() => _TargetSheetState();
}

class _TargetSheetState extends State<_TargetSheet> {
  late final _min = TextEditingController(
      text: widget.current == null ? '' : _kg(widget.current!.minKg));
  late final _max = TextEditingController(
      text: widget.current == null ? '' : _kg(widget.current!.maxKg));

  @override
  void initState() {
    super.initState();
    for (final c in [_min, _max]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  (double, double)? get _parsed {
    final lo = double.tryParse(_min.text.trim().replaceAll(',', '.'));
    final hi = double.tryParse(_max.text.trim().replaceAll(',', '.'));
    if (lo == null || hi == null) return null;
    if (lo <= 0 || hi <= lo || hi > 500) return null;
    return (lo, hi);
  }

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final parsed = _parsed;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: HealthSheet(
        scrollable: true,
        title: 'Target weight range',
        children: [
          Text(
              'Ask your vet what range suits ${petDisplayName(widget.petName)}. '
              'It depends on breed, frame, age and body condition, which is why '
              'PawDoc does not guess one.',
              style: const TextStyle(
                  color: HealthTone.dim, fontSize: 12, height: 1.4)),
          Row(children: [
            Expanded(child: _NumberField(controller: _min, label: 'From (kg)')),
            const SizedBox(width: 10),
            Expanded(child: _NumberField(controller: _max, label: 'To (kg)')),
          ]),
          Row(children: [
            const Icon(LucideIcons.smartphone,
                size: 13, color: HealthTone.faint),
            const SizedBox(width: 7),
            const Expanded(
              child: Text('Saved on this device.',
                  style:
                      TextStyle(color: HealthTone.faint, fontSize: 10.5)),
            ),
          ]),
          Row(children: [
            if (widget.current != null) ...[
              Expanded(
                child: TextButton(
                  key: const Key('weight_target_clear'),
                  onPressed: () =>
                      Navigator.pop(context, const WeightTarget(0, 0)),
                  child: const Text('Remove'),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              flex: 2,
              child: FilledButton(
                key: const Key('weight_target_save'),
                style: FilledButton.styleFrom(
                    backgroundColor: t.accent,
                    foregroundColor: const Color(0xFF06110A),
                    minimumSize: const Size(0, 46)),
                onPressed: parsed == null
                    ? null
                    : () => Navigator.pop(
                        context, WeightTarget(parsed.$1, parsed.$2)),
                child: const Text('Save range'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: HealthTone.muted, fontSize: 12.5),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: PawTone.of(context).accent, width: 1.4),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Decoration + states
// ---------------------------------------------------------------------------

/// The outlined animal the mockup tucks into the corner of its note card.
class _PetOutline extends StatelessWidget {
  const _PetOutline();

  @override
  Widget build(BuildContext context) => Icon(LucideIcons.dog,
      size: 30, color: PawTone.of(context).accent.withValues(alpha: 0.20));
}

class _ScaleArt extends StatelessWidget {
  const _ScaleArt();

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(LucideIcons.dog, size: 26, color: t.accent.withValues(alpha: 0.22)),
      const SizedBox(width: 4),
      Icon(LucideIcons.clipboardList,
          size: 22, color: t.accent.withValues(alpha: 0.22)),
    ]);
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
          icon: LucideIcons.scale,
          title: 'Weight Tracking',
          subtitleLead: 'PawDoc',
          subtitle: ' weight record',
        ),
        bottomNavigationBar: const PawNavBar(detached: true),
        body: Padding(
          padding: kRecordPadding,
          child: Center(
            child: HealthAddCard(
              title: 'Add a pet to start weighing',
              subtitle: 'Two entries and the chart draws itself.',
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
