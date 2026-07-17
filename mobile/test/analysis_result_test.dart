import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/models/analysis_result.dart';

void main() {
  group('AnalysisResult contract (v2 action ladder)', () {
    final json = <String, dynamic>{
      'action': 'GET_HELP_NOW',
      'confidence': 0.92,
      'observation':
          'A visibly swollen, firm belly with retching that brings nothing up.',
      'visible_symptoms': ['swollen, firm abdomen', 'unproductive retching'],
      'vets_look_for': ['whether the stomach is distended or rotated'],
      'watch_for': ['collapse', 'pale or blue gums'],
      'recommended_actions': ['Contact an emergency veterinarian now.'],
      'urgency_timeframe': 'immediately',
      'recheck_hours': null,
      'disclaimer_required': true,
    };

    test('parses every frozen field from JSON', () {
      final r = AnalysisResult.fromJson(json);
      expect(r.action, ActionLevel.getHelpNow);
      expect(r.confidence, 0.92);
      expect(r.observation, contains('swollen, firm belly'));
      expect(r.visibleSymptoms, hasLength(2));
      expect(r.vetsLookFor, hasLength(1));
      expect(r.watchFor, ['collapse', 'pale or blue gums']);
      expect(r.recommendedActions, ['Contact an emergency veterinarian now.']);
      expect(r.urgencyTimeframe, 'immediately');
      expect(r.recheckHours, isNull);
      expect(r.disclaimerRequired, isTrue);
    });

    test('round-trips through toJson without drift', () {
      expect(AnalysisResult.fromJson(json).toJson(), equals(json));
    });

    test('recheck_hours parses when present (drives the re-check CTA)', () {
      final r = AnalysisResult.fromJson({
        ...json,
        'action': 'WATCH_AND_RECHECK',
        'recheck_hours': 24,
      });
      expect(r.action, ActionLevel.watchAndRecheck);
      expect(r.recheckHours, 24);
    });

    test('maps all four ladder actions to their exact wire values', () {
      expect(ActionLevel.getHelpNow.wireValue, 'GET_HELP_NOW');
      expect(ActionLevel.callToday.wireValue, 'CALL_TODAY');
      expect(ActionLevel.bookVisit.wireValue, 'BOOK_VISIT');
      expect(ActionLevel.watchAndRecheck.wireValue, 'WATCH_AND_RECHECK');
      expect(ActionLevel.fromWire('WATCH_AND_RECHECK'), ActionLevel.watchAndRecheck);
    });

    test('rejects unknown actions — including the retired v1 verdicts', () {
      expect(() => ActionLevel.fromWire('SEVERE'), throwsArgumentError);
      expect(() => ActionLevel.fromWire('NORMAL'), throwsArgumentError);
      expect(() => ActionLevel.fromWire('EMERGENCY'), throwsArgumentError);
    });
  });
}
