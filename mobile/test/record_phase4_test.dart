// Evolution Phase 4 — the record: weight read-back, reminder notification ids,
// and the structured-vaccination metadata shape.
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/notifications/local_notifications.dart';

void main() {
  group('LocalNotifications.idFor', () {
    test('is stable and 31-bit positive for any reminder uuid', () {
      const id = 'a3f2b8d1-1234-5678-9abc-def012345678';
      expect(LocalNotifications.idFor(id), LocalNotifications.idFor(id));
      expect(LocalNotifications.idFor(id), greaterThanOrEqualTo(0));
      expect(LocalNotifications.idFor(id), lessThan(1 << 31));
    });

    test('distinct reminders get distinct notification ids (practically)', () {
      expect(LocalNotifications.idFor('r1'),
          isNot(LocalNotifications.idFor('r2')));
    });
  });
}
