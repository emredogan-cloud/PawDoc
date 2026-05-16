/// Mobile mirror of `ai-service/app/models/schemas.AnalysisResult`.
///
/// We don't generate this from the AI service's schema; the boundary is
/// the edge function, and field names there are stable. Keep this small,
/// explicit, and reviewable.
library;

import 'package:flutter/foundation.dart';

enum TriageLevel {
  emergency,
  monitor,
  normal;

  String get displayName => switch (this) {
    TriageLevel.emergency => 'Emergency',
    TriageLevel.monitor => 'Monitor',
    TriageLevel.normal => 'Likely normal',
  };

  static TriageLevel? tryParse(String? raw) {
    return switch (raw?.toUpperCase()) {
      'EMERGENCY' => TriageLevel.emergency,
      'MONITOR' => TriageLevel.monitor,
      'NORMAL' => TriageLevel.normal,
      _ => null,
    };
  }
}

@immutable
class AnalysisResult {
  const AnalysisResult({
    required this.analysisId,
    required this.triageLevel,
    required this.confidence,
    required this.primaryConcern,
    required this.visibleSymptoms,
    required this.differential,
    required this.recommendedActions,
    required this.urgencyTimeframe,
    required this.disclaimerRequired,
    required this.disclaimerText,
    required this.modelUsed,
    required this.tierUsed,
    required this.emergencyOverrideApplied,
    required this.crossVerifyDisagreement,
    required this.aiLatencyMs,
    required this.requestId,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final triage = TriageLevel.tryParse(json['triage_level'] as String?);
    if (triage == null) {
      throw FormatException(
        'analysis.triage_level missing or invalid: ${json['triage_level']}',
      );
    }
    return AnalysisResult(
      analysisId: json['analysis_id'] as String? ?? '',
      triageLevel: triage,
      confidence: (json['confidence'] as num).toDouble(),
      primaryConcern: json['primary_concern'] as String,
      visibleSymptoms: _stringList(json['visible_symptoms']),
      differential: _stringList(json['differential']),
      recommendedActions: _stringList(json['recommended_actions']),
      urgencyTimeframe: json['urgency_timeframe'] as String,
      disclaimerRequired: (json['disclaimer_required'] as bool?) ?? true,
      disclaimerText: json['disclaimer_text'] as String? ?? '',
      modelUsed: json['model_used'] as String? ?? '',
      tierUsed: (json['tier_used'] as num?)?.toInt() ?? 0,
      emergencyOverrideApplied:
          (json['emergency_override_applied'] as bool?) ?? false,
      crossVerifyDisagreement:
          (json['cross_verify_disagreement'] as bool?) ?? false,
      aiLatencyMs: (json['ai_latency_ms'] as num?)?.toInt() ?? 0,
      requestId: json['request_id'] as String? ?? '',
    );
  }

  final String analysisId;
  final TriageLevel triageLevel;
  final double confidence;
  final String primaryConcern;
  final List<String> visibleSymptoms;
  final List<String> differential;
  final List<String> recommendedActions;
  final String urgencyTimeframe;
  final bool disclaimerRequired;
  final String disclaimerText;
  final String modelUsed;
  final int tierUsed;
  final bool emergencyOverrideApplied;
  final bool crossVerifyDisagreement;
  final int aiLatencyMs;
  final String requestId;

  /// Tier 0 means the AI service hit graceful-degradation — both providers
  /// were unavailable. We surface this in the UI as a clear "we couldn't
  /// analyze" state rather than a fake MONITOR.
  bool get isGracefulDegradation => tierUsed == 0;

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).toList(growable: false);
  }
}
