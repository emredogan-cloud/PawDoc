import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The weight range an owner is aiming for, **as they entered it**.
///
/// Mockup `weight_tracking` draws a dashed "Ideal Range (26.0 – 30.0 kg)" band
/// on the chart, an "Ideal" badge on every record and a "Great job! Buddy is
/// within the ideal weight range" card. The app cannot make that judgement: an
/// ideal weight depends on breed, frame, age, neuter status and a body-condition
/// score a vet assigns by hand. Inventing one and then grading an animal
/// against it is the same class of claim as a fabricated health score.
///
/// So the band exists, and its numbers come from the owner — ideally from
/// their vet. Until they set one there is no band, no badge and no verdict.
///
/// **Stored on the device**, not the server: `pets` has no column for it and
/// adding one is a migration plus a deploy. The UI says so ("saved on this
/// device"), because a target that quietly vanishes on a new phone and is
/// never mentioned is worse than one that says where it lives.
class WeightTarget {
  const WeightTarget(this.minKg, this.maxKg);

  final double minKg;
  final double maxKg;

  bool contains(double kg) => kg >= minKg && kg <= maxKg;

  String get label =>
      '${minKg.toStringAsFixed(1)}–${maxKg.toStringAsFixed(1)} kg';

  static String _key(String petId) => 'pawdoc.weight_target.$petId';

  static Future<WeightTarget?> load(String petId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(petId));
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final min = double.tryParse(parts[0]);
    final max = double.tryParse(parts[1]);
    if (min == null || max == null || min <= 0 || max <= min) return null;
    return WeightTarget(min, max);
  }

  static Future<void> save(String petId, WeightTarget target) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(petId), '${target.minKg}:${target.maxKg}');
  }

  static Future<void> clear(String petId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(petId));
  }
}

final weightTargetProvider =
    FutureProvider.autoDispose.family<WeightTarget?, String>(
        (ref, petId) => WeightTarget.load(petId));
