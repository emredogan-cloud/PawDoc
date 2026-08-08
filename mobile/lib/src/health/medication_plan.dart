import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/local_tick_log.dart';
import 'timeline.dart';

/// How often a medicine is taken.
enum MedFrequency { hourly, everyNDays, asNeeded, unknown }

/// A medication's schedule, read out of the free text the owner typed.
///
/// The `add_health_record` form takes "Every 12 hours" as a sentence, because
/// that is how a label reads and how an owner thinks. This turns that sentence
/// into slots — and, importantly, **fails to nothing**: an unparseable schedule
/// produces no doses at all rather than a guess. `medication_tracker` then
/// shows the text as written and simply has nothing to tick, which is honest.
class MedicationSchedule {
  const MedicationSchedule({
    required this.frequency,
    required this.raw,
    this.intervalHours = 0,
    this.intervalDays = 0,
    this.dosesPerDay = 0,
  });

  final MedFrequency frequency;
  final String raw;
  final int intervalHours;
  final int intervalDays;
  final int dosesPerDay;

  bool get isScheduled => frequency != MedFrequency.unknown &&
      frequency != MedFrequency.asNeeded;

  /// The first dose of a day, when nothing better is known. Eight in the
  /// morning is the convention a label means by "twice daily".
  static const int firstDoseHour = 8;

  static const _unknownText = MedicationSchedule(
      frequency: MedFrequency.unknown, raw: '');

  static MedicationSchedule parse(String? text) {
    final raw = (text ?? '').trim();
    if (raw.isEmpty) return _unknownText;
    final s = raw.toLowerCase();

    MedicationSchedule hourly(int hours) => MedicationSchedule(
          frequency: MedFrequency.hourly,
          raw: raw,
          intervalHours: hours,
          dosesPerDay: hours >= 24 ? 1 : (24 ~/ hours),
        );

    if (RegExp(r'\b(as needed|as required|prn|when needed)\b').hasMatch(s)) {
      return MedicationSchedule(frequency: MedFrequency.asNeeded, raw: raw);
    }

    final everyHours = RegExp(r'every\s+(\d+)\s*(h|hr|hrs|hour|hours)\b')
        .firstMatch(s);
    if (everyHours != null) {
      final n = int.parse(everyHours.group(1)!);
      if (n > 0 && n <= 24) return hourly(n);
    }

    final timesADay = RegExp(
            r'(\d+)\s*(x|times?|doses?)\s*(a|per|each)?\s*(day|daily)')
        .firstMatch(s);
    if (timesADay != null) {
      final n = int.parse(timesADay.group(1)!);
      if (n > 0 && n <= 12) return hourly((24 / n).floor().clamp(1, 24));
    }

    if (RegExp(r'\b(twice|two times|2x)\b').hasMatch(s)) return hourly(12);
    if (RegExp(r'\b(three times|thrice|3x)\b').hasMatch(s)) return hourly(8);
    if (RegExp(r'\b(four times|4x)\b').hasMatch(s)) return hourly(6);

    final everyDays =
        RegExp(r'every\s+(\d+)\s*(d|day|days)\b').firstMatch(s);
    if (everyDays != null) {
      final n = int.parse(everyDays.group(1)!);
      if (n > 0) {
        return MedicationSchedule(
            frequency: MedFrequency.everyNDays,
            raw: raw,
            intervalDays: n,
            dosesPerDay: 1);
      }
    }

    final everyWeeks =
        RegExp(r'every\s+(\d+)\s*(w|week|weeks)\b').firstMatch(s);
    if (everyWeeks != null) {
      final n = int.parse(everyWeeks.group(1)!);
      if (n > 0) {
        return MedicationSchedule(
            frequency: MedFrequency.everyNDays,
            raw: raw,
            intervalDays: n * 7,
            dosesPerDay: 1);
      }
    }

    if (RegExp(r'\b(weekly|every week|once a week)\b').hasMatch(s)) {
      return MedicationSchedule(
          frequency: MedFrequency.everyNDays,
          raw: raw,
          intervalDays: 7,
          dosesPerDay: 1);
    }
    if (RegExp(r'\b(monthly|every month|once a month)\b').hasMatch(s)) {
      return MedicationSchedule(
          frequency: MedFrequency.everyNDays,
          raw: raw,
          intervalDays: 30,
          dosesPerDay: 1);
    }
    if (RegExp(r'\b(once daily|once a day|daily|every day|每日)\b')
        .hasMatch(s)) {
      return hourly(24);
    }

    return MedicationSchedule(frequency: MedFrequency.unknown, raw: raw);
  }

  /// The times a dose is due on [day], given a course that began on [start].
  List<DateTime> slotsOn(DateTime day, DateTime start) {
    final d = DateTime(day.year, day.month, day.day);
    final s = DateTime(start.year, start.month, start.day);
    if (d.isBefore(s)) return const [];
    switch (frequency) {
      case MedFrequency.hourly:
        return [
          for (var i = 0; i < dosesPerDay; i++)
            DateTime(d.year, d.month, d.day,
                (firstDoseHour + i * intervalHours) % 24)
        ]..sort();
      case MedFrequency.everyNDays:
        final elapsed = d.difference(s).inDays;
        if (intervalDays <= 0 || elapsed % intervalDays != 0) return const [];
        return [DateTime(d.year, d.month, d.day, firstDoseHour)];
      case MedFrequency.asNeeded:
      case MedFrequency.unknown:
        return const [];
    }
  }

  /// The next dose strictly after [from].
  DateTime? nextDoseAfter(DateTime from, DateTime start, {DateTime? endsOn}) {
    if (!isScheduled) return null;
    for (var offset = 0; offset <= 400; offset++) {
      final day = DateTime(from.year, from.month, from.day)
          .add(Duration(days: offset));
      if (endsOn != null && day.isAfter(endsOn)) return null;
      for (final slot in slotsOn(day, start)) {
        if (slot.isAfter(from)) return slot;
      }
    }
    return null;
  }

  /// `Every 12 hours` — what the row prints. The owner's own words when they
  /// parsed, so a schedule never reads back differently from how it was typed.
  String get label => raw.isEmpty ? 'No schedule set' : raw;
}

// ---------------------------------------------------------------------------

/// One medicine on the plan, built from a `health_events` medication row.
class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.startedOn,
    required this.schedule,
    this.dosage,
    this.form,
    this.purpose,
    this.endsOn,
    this.note,
  });

  final String id;
  final String name;
  final DateTime startedOn;
  final MedicationSchedule schedule;
  final String? dosage;
  final String? form;
  final String? purpose;
  final DateTime? endsOn;
  final String? note;

  /// A course is current until the day it ends, inclusive.
  bool activeOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    if (d.isBefore(DateTime(startedOn.year, startedOn.month, startedOn.day))) {
      return false;
    }
    if (endsOn == null) return true;
    return !d.isAfter(DateTime(endsOn!.year, endsOn!.month, endsOn!.day));
  }

  static Medication? fromTimelineItem(TimelineItem item) {
    if (item.eventType != 'medication' || item.id == null) return null;
    final meta = item.payload ?? const <String, dynamic>{};
    final name = (meta['medication_name'] as String?)?.trim();
    return Medication(
      id: item.id!,
      // A row filed before the form had a name field has only its note; that
      // note is what the owner called it, so it is the name.
      name: (name == null || name.isEmpty)
          ? (item.subtitle?.trim().isNotEmpty == true
              ? item.subtitle!.trim()
              : 'Medication')
          : name,
      startedOn: item.date,
      schedule: MedicationSchedule.parse(meta['schedule'] as String?),
      dosage: (meta['dosage'] as String?)?.trim(),
      form: (meta['form'] as String?)?.trim(),
      purpose: (meta['purpose'] as String?)?.trim(),
      endsOn: meta['ends_on'] == null
          ? null
          : DateTime.tryParse(meta['ends_on'].toString()),
      // `item.detail` only — `subtitle` is the headline the timeline built
      // from the metadata, and echoing it as the note repeats the name.
      note: item.detail,
    );
  }
}

/// One dose slot on a day.
class DoseSlot {
  const DoseSlot({
    required this.medication,
    required this.at,
    required this.index,
  });

  final Medication medication;
  final DateTime at;

  /// Which dose of the day this is — part of the key, so two doses on the same
  /// day are tracked separately.
  final int index;

  String get key => DoseLog.keyFor(medication.id, at, index);
}

// ---------------------------------------------------------------------------

/// Which doses have been ticked off.
///
/// **On the device, and the screen says so.** There is no dose table: adding
/// one is a migration plus an RLS policy plus a deploy, all founder-gated, and
/// shipping a "Mark as taken" button whose answer is silently forgotten would
/// be worse than not shipping one. Device-local persistence is real
/// persistence — it survives restarts — it just does not follow the owner to a
/// second phone, and the tracker says that in as many words.
class DoseLog {
  const DoseLog._();

  static const prefix = 'pawdoc.dose.';

  /// The shared implementation. `reminder_detail` keeps its own log under its
  /// own prefix; the storage and the honesty rule are the same.
  static const log = LocalTickLog(prefix);

  static String keyFor(String medId, DateTime at, int index) =>
      '$prefix$medId.${LocalTickLog.dayKey(at)}.$index';

  static Future<Map<String, DateTime>> loadAll() => log.loadAll();

  static Future<void> set(String key, DateTime at) =>
      LocalTickLog.set(key, at);

  static Future<void> clear(String key) => LocalTickLog.clear(key);
}

/// The ticked doses, as a live map keyed by [DoseLog.keyFor].
class DoseLogController extends AsyncNotifier<Map<String, DateTime>> {
  @override
  Future<Map<String, DateTime>> build() => DoseLog.loadAll();

  Future<void> toggle(String key, {DateTime? at}) async {
    final current = Map<String, DateTime>.from(state.value ?? const {});
    if (current.containsKey(key)) {
      current.remove(key);
      await DoseLog.clear(key);
    } else {
      final when = at ?? DateTime.now();
      current[key] = when;
      await DoseLog.set(key, when);
    }
    state = AsyncData(current);
  }
}

final doseLogProvider =
    AsyncNotifierProvider<DoseLogController, Map<String, DateTime>>(
        DoseLogController.new);

// ---------------------------------------------------------------------------

/// How much of the plan was actually ticked off over a window.
///
/// **A statement about the routine, never about the animal.** The mockup reads
/// "Medication Adherence · 96% · Excellent" over nothing at all; this is
/// counted from doses the owner ticked, and it is null — not zero — when there
/// was nothing to tick, because 0% would read as a failure that never happened.
class Adherence {
  const Adherence({required this.taken, required this.expected});

  final int taken;
  final int expected;

  double? get ratio => expected == 0 ? null : taken / expected;

  int? get percent => ratio == null ? null : (ratio! * 100).round();

  /// Banded in words about the routine. Deliberately no "Excellent": a value
  /// judgement on an owner's week is not the app's to make, and it is one step
  /// from reading as a judgement on the pet.
  String get band {
    final p = percent;
    if (p == null) return 'No doses scheduled';
    if (p >= 95) return 'On track';
    if (p >= 75) return 'Mostly on track';
    if (p >= 40) return 'Some doses missed';
    return 'Just getting started';
  }

  /// The same reading, short enough for a quarter-width statistic tile.
  String get tileBand {
    final p = percent;
    if (p == null) return 'None due';
    if (p >= 95) return 'On track';
    if (p >= 75) return 'Mostly';
    if (p >= 40) return 'Some missed';
    return 'Starting';
  }

  static Adherence over(
    List<Medication> medications,
    Map<String, DateTime> log, {
    required DateTime from,
    required DateTime to,
  }) {
    var taken = 0;
    var expected = 0;
    for (var day = DateTime(from.year, from.month, from.day);
        !day.isAfter(to);
        day = day.add(const Duration(days: 1))) {
      for (final med in medications) {
        if (!med.activeOn(day)) continue;
        final slots = med.schedule.slotsOn(day, med.startedOn);
        for (var i = 0; i < slots.length; i++) {
          // Doses still in the future cannot have been missed.
          if (slots[i].isAfter(to)) continue;
          expected++;
          if (log.containsKey(DoseLog.keyFor(med.id, slots[i], i))) taken++;
        }
      }
    }
    return Adherence(taken: taken, expected: expected);
  }
}
