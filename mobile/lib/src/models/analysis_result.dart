/// The shared `AnalysisResult` contract (v2) — the single source of truth for
/// the payload that flows AI service (Python) -> Edge Function (TS) -> app
/// (Dart). The field list is FROZEN; the three language bindings cannot drift.
/// Canonical spec: `docs/contracts/ANALYSIS_RESULT.md`.
///
/// v2 (evolution reframe): the triage VERDICT is gone. The wire carries an
/// action ladder with no terminal "do nothing" state, plus a plain-language
/// observation. `confidence` crosses the wire for storage/monitoring but is
/// NEVER rendered to the user anywhere in this app.
library;

enum ActionLevel {
  getHelpNow('GET_HELP_NOW'),
  callToday('CALL_TODAY'),
  bookVisit('BOOK_VISIT'),
  watchAndRecheck('WATCH_AND_RECHECK');

  const ActionLevel(this.wireValue);

  /// The exact string used on the wire / in the database `action` column.
  final String wireValue;

  static ActionLevel fromWire(String value) {
    return ActionLevel.values.firstWhere(
      (level) => level.wireValue == value,
      orElse: () => throw ArgumentError('Unknown action: $value'),
    );
  }
}

class AnalysisResult {
  const AnalysisResult({
    required this.action,
    required this.confidence,
    required this.observation,
    required this.visibleSymptoms,
    required this.vetsLookFor,
    required this.watchFor,
    required this.recommendedActions,
    required this.urgencyTimeframe,
    required this.recheckHours,
    required this.disclaimerRequired,
  });

  final ActionLevel action;

  /// Model confidence in [0.0, 1.0]. INTERNAL — never rendered to the user.
  final double confidence;

  /// Plain-language description of what was observed/reported — never a
  /// condition or disease name.
  final String observation;
  final List<String> visibleSymptoms;

  /// Educational: what a vet typically assesses for this kind of presentation.
  final List<String> vetsLookFor;

  /// Signs that mean the owner should act sooner than the chosen action.
  final List<String> watchFor;
  final List<String> recommendedActions;
  final String urgencyTimeframe;

  /// Hours until a re-check makes sense; drives the re-check reminder CTA.
  /// WATCH_AND_RECHECK always carries one (server-backstopped).
  final int? recheckHours;

  /// API-level guarantee: a disclaimer must be shown when true. Never let the
  /// UI suppress it (disclaimers are injected server-side).
  final bool disclaimerRequired;

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      action: ActionLevel.fromWire(json['action'] as String),
      confidence: (json['confidence'] as num).toDouble(),
      observation: json['observation'] as String,
      visibleSymptoms: _stringList(json['visible_symptoms']),
      vetsLookFor: _stringList(json['vets_look_for']),
      watchFor: _stringList(json['watch_for']),
      recommendedActions: _stringList(json['recommended_actions']),
      urgencyTimeframe: json['urgency_timeframe'] as String,
      recheckHours: (json['recheck_hours'] as num?)?.toInt(),
      disclaimerRequired: json['disclaimer_required'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'action': action.wireValue,
        'confidence': confidence,
        'observation': observation,
        'visible_symptoms': visibleSymptoms,
        'vets_look_for': vetsLookFor,
        'watch_for': watchFor,
        'recommended_actions': recommendedActions,
        'urgency_timeframe': urgencyTimeframe,
        'recheck_hours': recheckHours,
        'disclaimer_required': disclaimerRequired,
      };

  static List<String> _stringList(dynamic value) {
    return (value as List<dynamic>? ?? const [])
        .map((e) => e as String)
        .toList(growable: false);
  }
}
