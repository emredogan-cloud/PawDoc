/// The shared `AnalysisResult` contract — the single source of truth for the
/// triage payload that flows AI service (Python) -> Edge Function (TS) -> app
/// (Dart). The field list is FROZEN here in Phase 1.1 (Critical Review #16) so
/// the three language bindings cannot drift. Canonical spec:
/// `docs/contracts/ANALYSIS_RESULT.md`.
///
/// JSON keys are snake_case; `triage_level` is one of EMERGENCY | MONITOR | NORMAL.
library;

enum TriageLevel {
  emergency('EMERGENCY'),
  monitor('MONITOR'),
  normal('NORMAL');

  const TriageLevel(this.wireValue);

  /// The exact string used on the wire / in the database `triage_level` column.
  final String wireValue;

  static TriageLevel fromWire(String value) {
    return TriageLevel.values.firstWhere(
      (level) => level.wireValue == value,
      orElse: () => throw ArgumentError('Unknown triage_level: $value'),
    );
  }
}

class AnalysisResult {
  const AnalysisResult({
    required this.triageLevel,
    required this.confidence,
    required this.primaryConcern,
    required this.visibleSymptoms,
    required this.differential,
    required this.recommendedActions,
    required this.urgencyTimeframe,
    required this.disclaimerRequired,
  });

  final TriageLevel triageLevel;

  /// Model confidence in [0.0, 1.0].
  final double confidence;
  final String primaryConcern;
  final List<String> visibleSymptoms;
  final List<String> differential;
  final List<String> recommendedActions;
  final String urgencyTimeframe;

  /// API-level guarantee: a disclaimer must be shown when true. Never let the
  /// UI suppress it (disclaimers are injected server-side — see Phase 1.4).
  final bool disclaimerRequired;

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      triageLevel: TriageLevel.fromWire(json['triage_level'] as String),
      confidence: (json['confidence'] as num).toDouble(),
      primaryConcern: json['primary_concern'] as String,
      visibleSymptoms: _stringList(json['visible_symptoms']),
      differential: _stringList(json['differential']),
      recommendedActions: _stringList(json['recommended_actions']),
      urgencyTimeframe: json['urgency_timeframe'] as String,
      disclaimerRequired: json['disclaimer_required'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'triage_level': triageLevel.wireValue,
        'confidence': confidence,
        'primary_concern': primaryConcern,
        'visible_symptoms': visibleSymptoms,
        'differential': differential,
        'recommended_actions': recommendedActions,
        'urgency_timeframe': urgencyTimeframe,
        'disclaimer_required': disclaimerRequired,
      };

  static List<String> _stringList(dynamic value) {
    return (value as List<dynamic>? ?? const [])
        .map((e) => e as String)
        .toList(growable: false);
  }
}
