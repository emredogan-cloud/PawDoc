/// Tests for the AnalysisResult model — JSON parsing + derived flags.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/shared/models/analysis_result.dart';

Map<String, Object?> _validJson({String triage = 'MONITOR', int tier = 3}) => {
  'analysis_id': 'a-1',
  'triage_level': triage,
  'confidence': 0.81,
  'primary_concern': 'Mild ear redness; could be early otitis.',
  'visible_symptoms': ['head shaking'],
  'differential': ['otitis externa'],
  'recommended_actions': ['Schedule a vet visit within a week.'],
  'urgency_timeframe': 'Within 1 week.',
  'disclaimer_required': true,
  'disclaimer_text': 'PawDoc provides triage guidance…',
  'model_used': 'claude-sonnet-x',
  'tier_used': tier,
  'emergency_override_applied': false,
  'cross_verify_disagreement': false,
  'ai_latency_ms': 1234,
  'request_id': 'req_test',
};

void main() {
  group('AnalysisResult.fromJson', () {
    test('parses EMERGENCY', () {
      final r = AnalysisResult.fromJson(_validJson(triage: 'EMERGENCY'));
      expect(r.triageLevel, TriageLevel.emergency);
    });

    test('parses MONITOR', () {
      final r = AnalysisResult.fromJson(_validJson(triage: 'MONITOR'));
      expect(r.triageLevel, TriageLevel.monitor);
    });

    test('parses NORMAL', () {
      final r = AnalysisResult.fromJson(_validJson(triage: 'NORMAL'));
      expect(r.triageLevel, TriageLevel.normal);
    });

    test('throws on unknown triage level', () {
      final bad = _validJson()..['triage_level'] = 'URGENT';
      expect(() => AnalysisResult.fromJson(bad), throwsFormatException);
    });

    test('isGracefulDegradation true when tier_used == 0', () {
      final r = AnalysisResult.fromJson(_validJson(tier: 0));
      expect(r.isGracefulDegradation, isTrue);
    });

    test('isGracefulDegradation false when tier_used > 0', () {
      final r = AnalysisResult.fromJson(_validJson(tier: 2));
      expect(r.isGracefulDegradation, isFalse);
    });

    test('coerces missing optional lists to empty', () {
      final j = _validJson()
        ..remove('visible_symptoms')
        ..remove('differential');
      final r = AnalysisResult.fromJson(j);
      expect(r.visibleSymptoms, isEmpty);
      expect(r.differential, isEmpty);
    });
  });

  test('TriageLevel.tryParse is case-insensitive', () {
    expect(TriageLevel.tryParse('emergency'), TriageLevel.emergency);
    expect(TriageLevel.tryParse('Monitor'), TriageLevel.monitor);
    expect(TriageLevel.tryParse('NORMAL'), TriageLevel.normal);
    expect(TriageLevel.tryParse('bogus'), isNull);
    expect(TriageLevel.tryParse(null), isNull);
  });
}
