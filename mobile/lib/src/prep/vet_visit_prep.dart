import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The owner's own answers for an upcoming visit — the part of the prep pack
/// that is not already in the record.
///
/// ## Where it lives, and why the screen says so
///
/// **On the device**, keyed by pet. There is no `visit_prep` table, and adding
/// one is a migration plus an RLS review plus a deploy — all founder-gated. A
/// control whose answer is silently forgotten is worse than no control, so the
/// screen states where the draft is kept, exactly as the weight target, the
/// saved breeds and the recent searches do.
///
/// ## The one field the reference has that this does not
///
/// `prepare_for_vet_visit` draws a **Severity** control — a signal-strength
/// meter reading "Moderate". Two problems. A bar meter beside a symptom reads
/// as an assessment, and the only assessment on this screen is the owner's;
/// and an owner's ungrounded "mild" is the sort of thing that turns into "I'll
/// wait until Tuesday". What a vet actually asks — and what the prep pack was
/// built to answer — is *is it better or worse*, so the third control is
/// [SymptomChange]: a trajectory, not a grade.
///
/// Nothing on this screen interprets any of it. No advice is derived from a
/// reason, a frequency or a trajectory; the answers are transcribed into the
/// pack and nowhere else.
class VisitPrepDraft {
  const VisitPrepDraft({
    this.reasons = const {},
    this.otherReason = '',
    this.startedOn,
    this.frequency,
    this.change,
    this.notes = '',
    this.bring = const {},
    this.questions = const [],
    this.reviewedAt,
  });

  /// [VisitReason.id] values the owner ticked.
  final Set<String> reasons;

  /// Free text behind the "Other" chip.
  final String otherReason;

  /// When the owner first noticed it.
  final DateTime? startedOn;

  final SymptomFrequency? frequency;
  final SymptomChange? change;

  /// The owner's own description, in their words.
  final String notes;

  /// [BringItem.id] values ticked off the checklist.
  final Set<String> bring;

  /// One question per entry, in the order they will be printed.
  final List<String> questions;

  /// When the owner last opened the summary. The sixth step is "you have
  /// reviewed this", which is a real thing they did — not a box the app ticks
  /// on their behalf.
  final DateTime? reviewedAt;

  VisitPrepDraft copyWith({
    Set<String>? reasons,
    String? otherReason,
    DateTime? startedOn,
    bool clearStartedOn = false,
    SymptomFrequency? frequency,
    SymptomChange? change,
    String? notes,
    Set<String>? bring,
    List<String>? questions,
    DateTime? reviewedAt,
  }) =>
      VisitPrepDraft(
        reasons: reasons ?? this.reasons,
        otherReason: otherReason ?? this.otherReason,
        startedOn: clearStartedOn ? null : (startedOn ?? this.startedOn),
        frequency: frequency ?? this.frequency,
        change: change ?? this.change,
        notes: notes ?? this.notes,
        bring: bring ?? this.bring,
        questions: questions ?? this.questions,
        reviewedAt: reviewedAt ?? this.reviewedAt,
      );

  /// The questions that will actually print — blank rows are kept in the
  /// editor so a row can be emptied without vanishing under the thumb.
  List<String> get liveQuestions =>
      questions.map((q) => q.trim()).where((q) => q.isNotEmpty).toList();

  /// Every reason as a label, including the free-text one.
  List<String> reasonLabels() => [
        for (final r in kVisitReasons)
          if (r.id != 'other' && reasons.contains(r.id)) r.label,
        if (reasons.contains('other') && otherReason.trim().isNotEmpty)
          otherReason.trim(),
      ];

  Map<String, dynamic> toJson() => {
        'reasons': reasons.toList(),
        'otherReason': otherReason,
        'startedOn': startedOn?.toIso8601String(),
        'frequency': frequency?.name,
        'change': change?.name,
        'notes': notes,
        'bring': bring.toList(),
        'questions': questions,
        'reviewedAt': reviewedAt?.toIso8601String(),
      };

  static VisitPrepDraft fromJson(Map<String, dynamic> json) => VisitPrepDraft(
        reasons: {...?(json['reasons'] as List?)?.map((e) => '$e')},
        otherReason: (json['otherReason'] as String?) ?? '',
        startedOn: DateTime.tryParse((json['startedOn'] as String?) ?? ''),
        frequency: _byName(SymptomFrequency.values, json['frequency']),
        change: _byName(SymptomChange.values, json['change']),
        notes: (json['notes'] as String?) ?? '',
        bring: {...?(json['bring'] as List?)?.map((e) => '$e')},
        questions: [...?(json['questions'] as List?)?.map((e) => '$e')],
        reviewedAt: DateTime.tryParse((json['reviewedAt'] as String?) ?? ''),
      );

  static T? _byName<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  static String storeKey(String petId) => 'pawdoc.visit_prep.$petId';

  /// Never throws: a draft that cannot be parsed is a blank draft, not a
  /// crash on the way into the screen.
  static Future<VisitPrepDraft> load(String petId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storeKey(petId));
    if (raw == null || raw.isEmpty) return const VisitPrepDraft();
    try {
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const VisitPrepDraft();
    }
  }

  static Future<void> save(String petId, VisitPrepDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storeKey(petId), jsonEncode(draft.toJson()));
  }

  static Future<void> clear(String petId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storeKey(petId));
  }
}

// ---------------------------------------------------------------------------
// Vocabulary
// ---------------------------------------------------------------------------

/// A reason chip. **A label the owner picks, never a finding.** Nothing reads
/// these back: no timeframe, no urgency, no advice is derived from any of them.
class VisitReason {
  const VisitReason(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;
}

const List<VisitReason> kVisitReasons = [
  VisitReason('cough', 'Coughing', LucideIcons.wind),
  VisitReason('appetite', 'Loss of appetite', LucideIcons.utensils),
  VisitReason('limping', 'Limping', LucideIcons.footprints),
  VisitReason('vomiting', 'Vomiting', LucideIcons.droplet),
  VisitReason('skin', 'Skin issue', LucideIcons.sparkle),
  VisitReason('behaviour', 'Behaviour change', LucideIcons.brain),
  VisitReason('checkup', 'Routine check-up', LucideIcons.shieldCheck),
  VisitReason('other', 'Other', LucideIcons.ellipsis),
];

/// How often the owner sees it. Their words, on their scale.
enum SymptomFrequency {
  once('Happened once'),
  occasional('Now and then'),
  daily('Most days'),
  constant('All the time');

  const SymptomFrequency(this.label);

  final String label;
}

/// Whether it is heading in a good or bad direction — the question the prep
/// pack exists to answer, and the reference's "Severity" meter replaced.
enum SymptomChange {
  worse('Getting worse'),
  same('About the same'),
  better('Getting better'),
  comesAndGoes('Comes and goes');

  const SymptomChange(this.label);

  final String label;
}

/// One tile of "Don't forget to bring".
class BringItem {
  const BringItem(this.id, this.label, this.hint, this.icon);

  final String id;
  final String label;
  final String hint;
  final IconData icon;
}

const List<BringItem> kBringItems = [
  BringItem('medications', 'Medications', 'The boxes, with the dose on them',
      LucideIcons.pill),
  BringItem('records', 'Previous records', 'Anything from another clinic',
      LucideIcons.clipboardList),
  BringItem('food', 'Food & treats', 'Brand names, if you can', LucideIcons.bone),
  BringItem('sample', 'A sample', 'Only if it is safe and easy to collect',
      LucideIcons.beaker),
  BringItem('media', 'Photos or videos', 'Easier to show than to describe',
      LucideIcons.image),
];

/// Prompts owners actually forget — general, non-diagnostic. Nothing here
/// presupposes a symptom or names a condition.
const List<String> kQuestionExamples = [
  'Is this weight still healthy for their age?',
  'Are the vaccinations up to date for where we live?',
  'What should I watch for at home after this visit?',
  'Is there anything in the record that needs a closer look?',
  'How long should this take to settle, and when should I call back?',
  'Does anything need to change about food or exercise?',
];

// ---------------------------------------------------------------------------
// Progress
// ---------------------------------------------------------------------------

/// The six stops of the reference's progress rail.
/// Labels are deliberately short. Six stops across a 393dp screen is 65dp a
/// column, and the reference's own wording ("Reason for Visit", "Symptoms",
/// "Documents", "Questions", "Summary") ellipsises to "Sympto…", "Questi…",
/// "Summa…" on the device — a rail whose labels are cut in half names nothing.
enum PrepStep {
  reason('Reason'),
  symptoms('Notes'),
  record('Record'),
  bring('Bring'),
  questions('Ask'),
  summary('Review');

  const PrepStep(this.label);

  final String label;
}

/// Which stops are done.
///
/// Pure so the reference's "4 / 6 Completed" is arithmetic rather than a
/// picture. [recordItems] is how much the *record* holds for this pet — recent
/// checks, vaccinations, medications, weights — because that step is filled by
/// what has been logged over time, not by anything typed here.
Set<PrepStep> completedPrepSteps(VisitPrepDraft draft, {required int recordItems}) {
  final done = <PrepStep>{};
  if (draft.reasons.isNotEmpty || draft.otherReason.trim().isNotEmpty) {
    done.add(PrepStep.reason);
  }
  if (draft.startedOn != null ||
      draft.frequency != null ||
      draft.change != null ||
      draft.notes.trim().isNotEmpty) {
    done.add(PrepStep.symptoms);
  }
  if (recordItems > 0) done.add(PrepStep.record);
  if (draft.bring.isNotEmpty) done.add(PrepStep.bring);
  if (draft.liveQuestions.isNotEmpty) done.add(PrepStep.questions);
  if (draft.reviewedAt != null) done.add(PrepStep.summary);
  return done;
}

/// The owner's answers as pack lines, ready to append to the prep pack.
///
/// Every line is prefixed by what it is, and the section that carries them is
/// labelled as owner-entered — the same provenance rule the exported report
/// follows (review V-22): a vet reading the pack must be able to tell what a
/// person wrote from what a model produced.
List<String> visitPrepAnswerLines(VisitPrepDraft draft) {
  final lines = <String>[];
  final reasons = draft.reasonLabels();
  if (reasons.isNotEmpty) lines.add('Reason for the visit: ${reasons.join(', ')}');
  if (draft.startedOn != null) {
    final d = draft.startedOn!;
    lines.add('First noticed: ${d.year}-${_two(d.month)}-${_two(d.day)}');
  }
  if (draft.frequency != null) {
    lines.add('How often: ${draft.frequency!.label}');
  }
  if (draft.change != null) {
    lines.add('Since then: ${draft.change!.label}');
  }
  if (draft.notes.trim().isNotEmpty) {
    lines.add('In the owner’s words: ${draft.notes.trim()}');
  }
  final bring = [
    for (final item in kBringItems)
      if (draft.bring.contains(item.id)) item.label,
  ];
  if (bring.isNotEmpty) lines.add('Bringing: ${bring.join(', ')}');
  return lines;
}

String _two(int v) => v.toString().padLeft(2, '0');
