// Mockup `reminder_detail`.
//
// The reference draws a dose, a repeat cadence ("Every 30 days") and six future
// occurrences of one recurring reminder. The `reminders` table holds five
// columns — `reminder_type`, `due_date`, `is_sent`, `notification_sent_at`,
// `created_at` — and none of them is a dose or a cadence. Every fact this
// screen states comes from those columns or from the time the app genuinely
// fires at; the two controls with nothing behind them keep their place and say
// *Soon*.
//
// It also paints "Skip / Postpone" in the EMERGENCY red. The action ladder's
// four hues are locked against decoration, so the button keeps its position and
// weight in a substitute tint. That separation is pinned below.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/core/local_tick_log.dart';
import 'package:pawdoc/src/notifications/local_notifications.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';
import 'package:pawdoc/src/reminders/reminder.dart';
import 'package:pawdoc/src/reminders/reminder_detail_screen.dart';
import 'package:pawdoc/src/reminders/reminders_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pet = Pet(
  id: 'p1',
  userId: 'u1',
  name: 'Buddy',
  species: 'dog',
  breed: 'Golden Retriever',
  weightKg: 28,
);

DateTime _daysFromNow(int d) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).add(Duration(days: d));
}

Reminder _reminder({
  String id = 'r1',
  // The mockup titles this "NexGard Spectra (11–22 kg)". The app's own preset
  // is what an owner actually gets, and it is what the category derivation has
  // to work from — a brand name alone stays uncategorised, which is asserted
  // below rather than papered over with a drug lexicon.
  String type = 'Flea & tick medication',
  int dueInDays = 12,
  DateTime? createdAt,
  DateTime? notificationSentAt,
}) =>
    Reminder(
      id: id,
      petId: 'p1',
      userId: 'u1',
      reminderType: type,
      dueDate: _daysFromNow(dueInDays),
      createdAt: createdAt ?? _daysFromNow(-30),
      notificationSentAt: notificationSentAt,
    );

void _surface(WidgetTester tester, {double height = 2600}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

Widget _app({
  Reminder? reminder,
  List<Reminder>? siblings,
  Map<String, Object> prefs = const {},
}) {
  SharedPreferences.setMockInitialValues(prefs);
  final r = reminder ?? _reminder();
  return ProviderScope(
    overrides: [
      petsListProvider.overrideWith((ref) async => const [_pet]),
      reminderByIdProvider.overrideWith((ref, id) async => r),
      remindersForPetProvider
          .overrideWith((ref, petId) async => siblings ?? [r]),
    ],
    child: MaterialApp(home: ReminderDetailScreen(reminderId: r.id!)),
  );
}

void main() {
  group('the row, read', () {
    test('parses the two columns the model never used to', () {
      final r = Reminder.fromJson(const {
        'id': 'r1',
        'pet_id': 'p1',
        'user_id': 'u1',
        'reminder_type': 'Vaccine',
        'due_date': '2026-07-01',
        'is_sent': true,
        'created_at': '2026-06-01T10:15:00Z',
        'notification_sent_at': '2026-07-01T06:00:00Z',
      });
      expect(r.createdAt, isNotNull);
      expect(r.notificationSentAt, isNotNull);
      expect(r.isSent, isTrue);
    });

    test('a row without them still parses — they are nullable columns', () {
      final r = Reminder.fromJson(const {
        'id': 'r1',
        'pet_id': 'p1',
        'user_id': 'u1',
        'reminder_type': 'Vaccine',
        'due_date': '2026-07-01',
      });
      expect(r.createdAt, isNull);
      expect(r.notificationSentAt, isNull);
    });

    test('days until due counts from today, and goes negative', () {
      expect(_reminder(dueInDays: 12).daysUntilDue, 12);
      expect(_reminder(dueInDays: 0).daysUntilDue, 0);
      expect(_reminder(dueInDays: -3).daysUntilDue, -3);
      expect(_reminder(dueInDays: -3).isPastDue, isTrue);
      expect(_reminder(dueInDays: 0).isPastDue, isFalse);
    });

    test('copyWith moves the date and keeps everything else', () {
      final r = _reminder();
      final moved = r.copyWith(dueDate: _daysFromNow(40));
      expect(moved.id, r.id);
      expect(moved.reminderType, r.reminderType);
      expect(moved.createdAt, r.createdAt);
      expect(moved.dueDate, _daysFromNow(40));
    });
  });

  group('the category is a filing label on the owner\'s own words', () {
    test('reads the common kinds', () {
      expect(ReminderCategory.of('Vaccine'), ReminderCategory.vaccine);
      expect(ReminderCategory.of('DHPP booster'), ReminderCategory.vaccine);
      expect(ReminderCategory.of('Vet appointment'), ReminderCategory.vetVisit);
      expect(ReminderCategory.of('Nail trim'), ReminderCategory.grooming);
      expect(ReminderCategory.of('Give the ear drops'),
          ReminderCategory.medication);
    });

    test('parasite control wins over medication — the text says both', () {
      expect(ReminderCategory.of('Flea & tick medication'),
          ReminderCategory.parasite);
      expect(ReminderCategory.of('Deworming tablet'), ReminderCategory.parasite);
    });

    test('anything unrecognised stays general, never a guess', () {
      expect(ReminderCategory.of('Ask about the limp'),
          ReminderCategory.general);
      expect(ReminderCategory.of(''), ReminderCategory.general);
    });

    test('a bare brand name is not classified — there is no drug lexicon', () {
      // The mockup's own example. Guessing that "Spectra" is a parasiticide
      // would mean shipping a medicines database and being wrong about the
      // rest of it.
      expect(ReminderCategory.of('NexGard Spectra (11–22 kg)'),
          ReminderCategory.general);
    });
  });

  group('the mockup, drawn', () {
    testWidgets('every block the reference draws is present', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Reminder Detail'), findsOneWidget);
      expect(find.byKey(const Key('module_pet_name')), findsOneWidget);
      expect(find.byKey(const Key('reminder_edit')), findsOneWidget);
      expect(find.byKey(const Key('reminder_more')), findsOneWidget);
      expect(find.byKey(const Key('reminder_title')), findsOneWidget);
      expect(find.byKey(const Key('reminder_status')), findsOneWidget);
      expect(find.byKey(const Key('reminder_facts')), findsOneWidget);
      expect(find.text('About this reminder'), findsOneWidget);
      expect(find.text('Reminder Schedule'), findsOneWidget);
      expect(find.byKey(const Key('reminder_schedule_rail')), findsOneWidget);
      expect(find.text('Notification Settings'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.byKey(const Key('reminder_mark_taken')), findsOneWidget);
      expect(find.byKey(const Key('reminder_postpone')), findsOneWidget);
      expect(find.text('Safe & Secure'), findsOneWidget);
      expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget);
    });

    testWidgets('the fact grid states the row, not an invention',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Parasite control'), findsWidgets);
      expect(find.text('Repeats'), findsOneWidget);
      expect(find.text('One-time'), findsOneWidget);
      expect(find.text('Next reminder'), findsOneWidget);
      expect(find.text('In 12 days'), findsOneWidget);
      expect(find.text('Set on'), findsOneWidget);
      // The one time the app actually fires at, read from the scheduler.
      expect(find.textContaining('9:00 AM'), findsWidgets);
    });

    testWidgets('a past-due reminder counts backwards, never in red',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(reminder: _reminder(dueInDays: -3)));
      await tester.pumpAndSettle();
      expect(find.text('3 days ago'), findsOneWidget);
      expect(find.text('Date passed'), findsWidgets);
    });

    testWidgets('the rail plots real dates, this one lit', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(siblings: [
        _reminder(),
        _reminder(id: 'r2', type: 'Vaccine', dueInDays: 40),
        _reminder(id: 'r3', type: 'Nail trim', dueInDays: 70),
      ]));
      await tester.pumpAndSettle();
      expect(find.textContaining('3 scheduled for Buddy'), findsOneWidget);
      expect(find.textContaining('Each reminder happens once'), findsOneWidget);
    });
  });

  group('marking it taken', () {
    testWidgets('ticks, says where it is kept, and undoes', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Mark as Taken'), findsOneWidget);
      await tester.tap(find.byKey(const Key('reminder_mark_taken')));
      await tester.pumpAndSettle();

      expect(find.text('Taken · undo'), findsOneWidget);
      expect(find.text('Marked as taken. Kept on this device.'),
          findsOneWidget);
      // …and it becomes a history entry.
      expect(find.byKey(const Key('reminder_history_0')), findsOneWidget);

      await tester.tap(find.byKey(const Key('reminder_mark_taken')));
      await tester.pumpAndSettle();
      expect(find.text('Mark as Taken'), findsOneWidget);
    });

    testWidgets('a tick already on the device is read back', (tester) async {
      _surface(tester);
      final r = _reminder();
      final key = ReminderDetailScreen.tickKey(r.id!, r.dueDate);
      await tester.pumpWidget(_app(
        reminder: r,
        prefs: {key: DateTime.now().toIso8601String()},
      ));
      await tester.pumpAndSettle();
      expect(find.text('Taken · undo'), findsOneWidget);
    });

    test('the key is the due date, so moving the reminder drops the tick', () {
      final r = _reminder();
      final moved = r.copyWith(dueDate: r.dueDate.add(const Duration(days: 1)));
      expect(
        ReminderDetailScreen.tickKey(r.id!, r.dueDate),
        isNot(ReminderDetailScreen.tickKey(moved.id!, moved.dueDate)),
        reason: 'a tick belongs to the date it was for — you moved it because '
            'it had not happened',
      );
    });

    test('the tick namespace cannot collide with a medication dose', () {
      final key = ReminderDetailScreen.tickKey('r1', DateTime(2026, 8, 7));
      expect(key.startsWith('pawdoc.reminder.done.'), isTrue);
      expect(key.startsWith('pawdoc.dose.'), isFalse);
      expect(key, contains('2026-08-07'));
    });
  });

  group('history', () {
    testWidgets('lists only what really happened', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(
        reminder: _reminder(
          notificationSentAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Notification delivered'), findsOneWidget);
      expect(find.textContaining('Reminder created'), findsOneWidget);
    });

    testWidgets('an untouched reminder says so rather than inventing a row',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(
        reminder: Reminder(
          id: 'r1',
          petId: 'p1',
          reminderType: 'Vaccine',
          dueDate: _daysFromNow(5),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reminder_history_empty')), findsOneWidget);
    });
  });

  group('postponing', () {
    testWidgets('offers real dates and explains why there is no skip',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reminder_postpone')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reminder_postpone_day')), findsOneWidget);
      expect(find.byKey(const Key('reminder_postpone_week')), findsOneWidget);
      expect(find.byKey(const Key('reminder_postpone_pick')), findsOneWidget);
      expect(find.textContaining('nothing to skip to'), findsOneWidget);
    });
  });

  group('safety', () {
    testWidgets('nothing grades the animal or instructs on dosing',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      for (final banned in [
        'Excellent',
        'Great job',
        'Up to date',
        'Fully protected',
        'On Schedule',
        'Give medications',
        'Chewable Tablet',
        'protects Buddy',
      ]) {
        expect(find.textContaining(banned), findsNothing,
            reason: '"$banned" is a claim or an instruction the app '
                'cannot make');
      }
    });

    testWidgets('the two absent features keep their place and say Soon',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reminder_setting_lead')), findsOneWidget);
      expect(find.byKey(const Key('reminder_setting_missed')), findsOneWidget);
      expect(find.textContaining('Soon'), findsWidgets);
    });

    testWidgets('the about card points at the vet, not at a schedule',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.textContaining('between you and your vet'), findsOneWidget);
    });

    testWidgets('no category tint is one of the ladder\'s locked hues',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(ReminderDetailScreen));
      const ladder = [
        Color(0xFFFF5A52), // emergencyDark
        Color(0xFFC62828), // emergencyLight
        Color(0xFFFFC233), // monitorDark
        Color(0xFFFFB300), // monitorLight
        Color(0xFF1565C0), // actionBookVisit
        Color(0xFF455A64), // actionWatch
      ];
      for (final c in ReminderCategory.values) {
        expect(ladder.contains(reminderTint(context, c)), isFalse,
            reason: 'the ${c.name} tint reads as a severity signal');
      }
    });

    testWidgets('Skip / Postpone is not painted in the emergency red',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('reminder_postpone'));
      final icons = tester.widgetList<Icon>(
          find.descendant(of: button, matching: find.byType(Icon)));
      expect(icons, isNotEmpty);
      for (final icon in icons) {
        expect(icon.color, isNot(const Color(0xFFFF5A52)));
        expect(icon.color, isNot(const Color(0xFFC62828)));
      }
    });
  });

  group('the scheduler is the single source of the time', () {
    test('the screen does not carry its own copy of the hour', () {
      expect(LocalNotifications.reminderHour, 9);
    });

    test('the shared tick log namespaces by prefix', () async {
      SharedPreferences.setMockInitialValues({
        'pawdoc.reminder.done.r1.2026-08-07': '2026-08-07T08:02:00Z',
        'pawdoc.dose.m1.2026-08-07.0': '2026-08-07T08:02:00Z',
      });
      const log = LocalTickLog('pawdoc.reminder.done.');
      final ticks = await log.loadAll();
      expect(ticks.keys, ['pawdoc.reminder.done.r1.2026-08-07']);
    });
  });
}
