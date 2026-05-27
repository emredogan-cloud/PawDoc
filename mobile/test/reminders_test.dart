import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/reminders/reminder.dart';

void main() {
  test('toColumns omits user_id and sends a date-only due_date', () {
    final r = Reminder(
      petId: 'p1',
      reminderType: 'Flea & tick medication',
      dueDate: DateTime(2026, 7, 1, 9, 30),
    );
    final cols = r.toColumns();
    expect(cols.containsKey('user_id'), isFalse); // added by the repository
    expect(cols['pet_id'], 'p1');
    expect(cols['reminder_type'], 'Flea & tick medication');
    expect(cols['due_date'], '2026-07-01'); // date-only, timezone-agnostic
  });

  test('fromJson parses a reminders row', () {
    final r = Reminder.fromJson(const {
      'id': 'r1',
      'pet_id': 'p1',
      'user_id': 'u1',
      'reminder_type': 'Vaccine',
      'due_date': '2026-07-01',
      'is_sent': true,
    });
    expect(r.reminderType, 'Vaccine');
    expect(r.dueDate, DateTime(2026, 7, 1));
    expect(r.isSent, isTrue);
  });

  test('presets cover the common reminder kinds', () {
    expect(kReminderPresets, contains('Vaccine'));
    expect(kReminderPresets, contains('Vet appointment'));
    expect(kReminderPresets.length, greaterThanOrEqualTo(4));
  });
}
