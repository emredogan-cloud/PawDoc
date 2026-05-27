import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/models/analysis_result.dart';

void main() {
  group('AnalysisResult contract', () {
    final json = <String, dynamic>{
      'triage_level': 'EMERGENCY',
      'confidence': 0.92,
      'primary_concern': 'Suspected bloat (GDV)',
      'visible_symptoms': ['distended abdomen', 'retching'],
      'differential': ['GDV', 'ascites'],
      'recommended_actions': ['Go to an emergency vet now'],
      'urgency_timeframe': 'immediately',
      'disclaimer_required': true,
    };

    test('parses every frozen field from JSON', () {
      final r = AnalysisResult.fromJson(json);
      expect(r.triageLevel, TriageLevel.emergency);
      expect(r.confidence, 0.92);
      expect(r.primaryConcern, 'Suspected bloat (GDV)');
      expect(r.visibleSymptoms, ['distended abdomen', 'retching']);
      expect(r.differential, ['GDV', 'ascites']);
      expect(r.recommendedActions, ['Go to an emergency vet now']);
      expect(r.urgencyTimeframe, 'immediately');
      expect(r.disclaimerRequired, isTrue);
    });

    test('round-trips through toJson without drift', () {
      expect(AnalysisResult.fromJson(json).toJson(), equals(json));
    });

    test('maps all triage levels to their exact wire values', () {
      expect(TriageLevel.emergency.wireValue, 'EMERGENCY');
      expect(TriageLevel.monitor.wireValue, 'MONITOR');
      expect(TriageLevel.normal.wireValue, 'NORMAL');
      expect(TriageLevel.fromWire('NORMAL'), TriageLevel.normal);
    });

    test('rejects an unknown triage level', () {
      expect(() => TriageLevel.fromWire('SEVERE'), throwsArgumentError);
    });
  });
}
