import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/supabase_providers.dart';
import '../core/dates.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';

/// A logged weight point (read back from `health_events` metadata — E4: the
/// single most useful longitudinal signal used to be write-only).
class WeightPoint {
  const WeightPoint({
    required this.date,
    required this.kg,
    this.id,
    this.note,
    this.time,
  });

  final DateTime date;
  final double kg;

  /// The `health_events` row, so a record row can open or delete itself.
  final String? id;

  /// What the owner wrote alongside the number.
  final String? note;

  /// `10:24` — the time they entered, when they entered one. `event_date` is a
  /// DATE, so there is no clock time to fall back on.
  final String? time;
}

/// Weight points for a pet, oldest→newest (RLS-scoped).
///
/// **`ascending: true` explicitly.** `postgrest`'s `order()` defaults to
/// *descending*, so a bare `.order('event_date')` returned newest-first while
/// every consumer here reads the list as oldest-first. The trend sparkline in
/// the vet-prep pack has been drawing the line backwards, and the chart on
/// `weight_tracking` showed the oldest entry as the current weight — which is
/// how it was found. The Dart sort below is the belt to that braces: the order
/// this list arrives in is load-bearing, so it does not depend on a client
/// library's default.
final weightPointsProvider = FutureProvider.autoDispose
    .family<List<WeightPoint>, String>((ref, petId) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('health_events')
      .select('id, event_date, notes, metadata')
      .eq('pet_id', petId)
      .eq('event_type', 'weight')
      .order('event_date', ascending: true);
  final out = <WeightPoint>[];
  for (final r in rows as List) {
    final m = r as Map;
    final date = DateTime.tryParse((m['event_date'] as String?) ?? '');
    final meta = m['metadata'] as Map?;
    final kg = (meta?['weight_kg'] as num?)?.toDouble();
    if (date != null && kg != null && kg > 0) {
      out.add(WeightPoint(
        date: date,
        kg: kg,
        id: m['id'] as String?,
        note: (m['notes'] as String?)?.trim(),
        time: (meta?['time'] as String?)?.trim(),
      ));
    }
  }
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
});

/// The weight trend card (record centerpiece #1). Renders only when there are
/// at least two points — a single point is a number, not a trend. Pure
/// CustomPainter; no chart dependency.
class WeightTrendCard extends ConsumerWidget {
  const WeightTrendCard({super.key, required this.petId});
  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(weightPointsProvider(petId));
    return points.maybeWhen(
      data: (list) {
        if (list.length < 2) return const SizedBox.shrink();
        final latest = list.last;
        final first = list.first;
        final delta = latest.kg - first.kg;
        final deltaLabel = delta.abs() < 0.05
            ? 'steady'
            : '${delta > 0 ? '+' : '−'}${delta.abs().toStringAsFixed(1)} kg since ${shortDate(first.date)}';
        return PawCard(
          key: const Key('weight_trend_card'),
          padding: const EdgeInsets.all(AppSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.monitor_weight_outlined,
                      size: 18, color: PawPalette.mint),
                  const SizedBox(width: AppSpace.s8),
                  Text('Weight',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: AppColors.ink50)),
                  const Spacer(),
                  Text('${latest.kg.toStringAsFixed(1)} kg',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: PawPalette.mint)),
                ],
              ),
              const SizedBox(height: AppSpace.s12),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: CustomPaint(
                  painter: _SparklinePainter(list),
                ),
              ),
              const SizedBox(height: AppSpace.s8),
              Text(
                '${list.length} entries · $deltaLabel',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.ink300),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.points);
  final List<WeightPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final minKg = points.map((p) => p.kg).reduce((a, b) => a < b ? a : b);
    final maxKg = points.map((p) => p.kg).reduce((a, b) => a > b ? a : b);
    final span = (maxKg - minKg).abs() < 0.001 ? 1.0 : maxKg - minKg;
    final minMs = points.first.date.millisecondsSinceEpoch.toDouble();
    final maxMs = points.last.date.millisecondsSinceEpoch.toDouble();
    final msSpan = (maxMs - minMs).abs() < 1 ? 1.0 : maxMs - minMs;

    Offset at(WeightPoint p) => Offset(
          (p.date.millisecondsSinceEpoch - minMs) / msSpan * size.width,
          // 6px vertical padding so dots don't clip.
          6 + (1 - (p.kg - minKg) / span) * (size.height - 12),
        );

    final line = Paint()
      ..color = PawPalette.mint
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = PawPalette.mint;

    final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (final p in points.skip(1)) {
      final o = at(p);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, line);
    for (final p in points) {
      canvas.drawCircle(at(p), 3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.points != points;
}
