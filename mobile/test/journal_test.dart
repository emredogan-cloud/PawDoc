import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/health/journal.dart';

void main() {
  test('Journal.fromJson parses a health_journals row', () {
    final j = Journal.fromJson(const {
      'id': 'j1',
      'pet_id': 'p1',
      'user_id': 'u1',
      'narrative_text': 'A calm, quiet week for Lily.',
      'week_start_date': '2026-05-25',
      'model_used': 'gpt-4o-mini',
      'created_at': '2026-05-31T23:59:00Z',
    });
    expect(j.narrativeText, contains('Lily'));
    expect(j.weekStartDate, DateTime(2026, 5, 25));
    expect(j.modelUsed, 'gpt-4o-mini');
  });
}
