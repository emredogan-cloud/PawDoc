// Mockup `add_health_record` — filing a record.
//
// The reference draws one variant (a vet visit, every field filled). This pins
// that the same card renders every type, that what the owner types reaches
// `metadata` under the keys the record surfaces read back, and that the sixth
// type tile is Weight rather than the mockup's "AI Analysis" — an AI check is
// produced by the Check flow, where the emergency override, the quota rules
// and the action ladder apply, and offering it as something to hand-enter
// would be a way around all three.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/health/health_event.dart';
import 'package:pawdoc/src/health/health_event_form_screen.dart';
import 'package:pawdoc/src/health/health_events_repository.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingRepo implements HealthEventsRepository {
  final created = <HealthEvent>[];

  @override
  Future<HealthEvent> create(HealthEvent event) async {
    created.add(event);
    return event;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _pet = Pet(
  id: 'p1',
  userId: 'u1',
  name: 'Buddy',
  species: 'dog',
  breed: 'Golden Retriever',
  weightKg: 28,
);

void _surface(WidgetTester tester, {double height = 2200}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

void _stubAnalytics(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('posthog_flutter'), (call) async => null);
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('posthog_flutter'), null));
}

Widget _app(HealthEventsRepository repo, {String? initialType}) {
  SharedPreferences.setMockInitialValues(const {});
  return ProviderScope(
    overrides: [
      healthEventsRepositoryProvider.overrideWithValue(repo),
      petsListProvider.overrideWith((ref) async => const [_pet]),
    ],
    child: MaterialApp(
      home: HealthEventFormScreen(
          petId: 'p1', petName: 'Buddy', initialType: initialType),
    ),
  );
}

Future<void> _selectType(WidgetTester tester, String type) async {
  await tester.ensureVisible(find.byKey(Key('event_type_$type')));
  await tester.pump();
  await tester.tap(find.byKey(Key('event_type_$type')));
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pump();
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

void main() {
  group('the mockup, drawn', () {
    testWidgets('every block the reference draws is present', (tester) async {
      _surface(tester);
      _stubAnalytics(tester);
      await tester.pumpWidget(_app(_RecordingRepo()));
      await tester.pumpAndSettle();

      expect(find.text('Add Health Record'), findsOneWidget);
      expect(find.byKey(const Key('record_close')), findsOneWidget);
      expect(find.byKey(const Key('module_pet_name')), findsOneWidget);

      expect(find.text('What type of record is this?'), findsOneWidget);
      expect(find.text('Record Details'), findsOneWidget);

      // The vet-visit variant the reference draws.
      expect(find.byKey(const Key('event_date_field')), findsOneWidget);
      expect(find.byKey(const Key('event_time_field')), findsOneWidget);
      expect(find.byKey(const Key('event_clinic_field')), findsOneWidget);
      expect(find.byKey(const Key('event_vet_field')), findsOneWidget);
      expect(find.byKey(const Key('event_reason_field')), findsOneWidget);
      expect(find.byKey(const Key('event_notes_field')), findsOneWidget);
      expect(find.text('0/500'), findsOneWidget);

      expect(find.text('Attachments'), findsOneWidget);
      expect(find.byKey(const Key('record_add_attachment')), findsOneWidget);
      expect(find.byKey(const Key('record_reminder_switch')), findsOneWidget);
      expect(find.text('Your data is private and secure'), findsOneWidget);
      expect(find.byKey(const Key('event_save_button')), findsOneWidget);
      expect(find.textContaining('Encrypted'), findsOneWidget);
    });

    testWidgets('all six type tiles are on the rail, and none is AI Analysis',
        (tester) async {
      _surface(tester);
      _stubAnalytics(tester);
      await tester.pumpWidget(_app(_RecordingRepo()));
      await tester.pumpAndSettle();

      expect(kHealthEventTypes.length, 6);
      // The rail scrolls and builds lazily, so walk it the way a user would.
      // Found by the rail's own key: an ancestor-of-a-tile finder stops
      // resolving once that tile scrolls off, and the attachment gallery is a
      // second horizontal scrollable on the page.
      final rail = find.descendant(
        of: find.byKey(const Key('record_type_rail')),
        matching: find.byType(Scrollable),
      );
      for (final type in kHealthEventTypes) {
        await tester.scrollUntilVisible(find.byKey(Key('event_type_$type')), 90,
            scrollable: rail);
        await tester.pump();
        expect(find.byKey(Key('event_type_$type')), findsOneWidget,
            reason: '$type tile missing');
      }
      expect(find.text('AI Analysis'), findsNothing,
          reason: 'an AI check is not something to hand-enter');
      expect(find.byKey(const Key('event_type_weight')), findsOneWidget);
    });

    testWidgets('the form opens on Vet Visit, as the reference draws it',
        (tester) async {
      _surface(tester);
      _stubAnalytics(tester);
      await tester.pumpWidget(_app(_RecordingRepo()));
      await tester.pumpAndSettle();
      expect(find.text('Visit Date'), findsOneWidget);
      expect(find.text('Notes & Findings'), findsOneWidget);
    });

    testWidgets('an opening type can be preselected by the caller',
        (tester) async {
      _surface(tester);
      _stubAnalytics(tester);
      await tester
          .pumpWidget(_app(_RecordingRepo(), initialType: 'vaccination'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event_vaccine_name_field')), findsOneWidget);
      expect(find.text('Given On'), findsOneWidget);
    });
  });

  group('the card follows the type', () {
    testWidgets('medication asks for name, dose, form, schedule and end',
        (tester) async {
      _surface(tester);
      _stubAnalytics(tester);
      await tester.pumpWidget(_app(_RecordingRepo()));
      await tester.pumpAndSettle();
      await _selectType(tester, 'medication');

      expect(find.byKey(const Key('event_medication_field')), findsOneWidget);
      expect(find.byKey(const Key('event_dosage_field')), findsOneWidget);
      expect(find.byKey(const Key('event_schedule_field')), findsOneWidget);
      expect(find.byKey(const Key('event_ends_on_field')), findsOneWidget);
      // and drops what a medication has no use for
      expect(find.byKey(const Key('event_vet_field')), findsNothing);
    });

    testWidgets('weight asks only for the weight', (tester) async {
      _surface(tester);
      _stubAnalytics(tester);
      await tester.pumpWidget(_app(_RecordingRepo()));
      await tester.pumpAndSettle();
      await _selectType(tester, 'weight');

      expect(find.byKey(const Key('event_weight_field')), findsOneWidget);
      expect(find.byKey(const Key('event_clinic_field')), findsNothing);
      expect(find.text('Weighed On'), findsOneWidget);
    });

    testWidgets('vaccination keeps its next-due date, which sets a reminder',
        (tester) async {
      _surface(tester);
      _stubAnalytics(tester);
      await tester.pumpWidget(_app(_RecordingRepo()));
      await tester.pumpAndSettle();
      await _selectType(tester, 'vaccination');
      expect(find.byKey(const Key('event_vaccine_next_due')), findsOneWidget);
    });
  });

  group('what reaches the record', () {
    testWidgets('a vet visit files clinic, vet and reason as metadata',
        (tester) async {
      _surface(tester);
      _stubAnalytics(tester);
      final repo = _RecordingRepo();
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await _fill(tester, 'event_clinic_field', 'PawCare Veterinary Clinic');
      await _fill(tester, 'event_vet_field', 'Dr. Ayşe Yılmaz');
      await _fill(tester, 'event_reason_field', 'Skin redness on front paw');
      await _fill(tester, 'event_notes_field', 'Recheck in two weeks.');

      await tester.tap(find.byKey(const Key('event_save_button')));
      await tester.pump(const Duration(milliseconds: 500));

      final event = repo.created.single;
      expect(event.eventType, 'vet_visit');
      expect(event.notes, 'Recheck in two weeks.');
      expect(event.metadata?['clinic'], 'PawCare Veterinary Clinic');
      expect(event.metadata?['veterinarian'], 'Dr. Ayşe Yılmaz');
      expect(event.metadata?['reason'], 'Skin redness on front paw');
    });

    testWidgets('a medication files the keys the tracker reads back',
        (tester) async {
      _surface(tester);
      _stubAnalytics(tester);
      final repo = _RecordingRepo();
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      await _selectType(tester, 'medication');

      await _fill(tester, 'event_medication_field', 'NexGard Spectra');
      await _fill(tester, 'event_dosage_field', '11–22 kg');
      await _fill(tester, 'event_schedule_field', 'Every 30 days');
      await _fill(tester, 'event_reason_field', 'Flea & tick prevention');

      await tester.tap(find.byKey(const Key('event_save_button')));
      await tester.pump(const Duration(milliseconds: 500));

      final meta = repo.created.single.metadata!;
      expect(meta['medication_name'], 'NexGard Spectra');
      expect(meta['dosage'], '11–22 kg');
      expect(meta['schedule'], 'Every 30 days');
      expect(meta['purpose'], 'Flea & tick prevention');
    });

    testWidgets('an empty field is left out rather than stored blank',
        (tester) async {
      _surface(tester);
      _stubAnalytics(tester);
      final repo = _RecordingRepo();
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await _fill(tester, 'event_reason_field', 'Annual checkup');
      await tester.tap(find.byKey(const Key('event_save_button')));
      await tester.pump(const Duration(milliseconds: 500));

      final meta = repo.created.single.metadata!;
      expect(meta.containsKey('clinic'), isFalse);
      expect(meta.containsKey('veterinarian'), isFalse);
      expect(meta['reason'], 'Annual checkup');
    });
  });

  group('leaving', () {
    testWidgets('closing an untouched form just closes it', (tester) async {
      _surface(tester);
      _stubAnalytics(tester);
      await tester.pumpWidget(_app(_RecordingRepo()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('record_close')));
      await tester.pumpAndSettle();
      expect(find.text('Discard this record?'), findsNothing);
    });

    testWidgets('closing a half-typed one asks first', (tester) async {
      _surface(tester);
      _stubAnalytics(tester);
      await tester.pumpWidget(_app(_RecordingRepo()));
      await tester.pumpAndSettle();
      await _fill(tester, 'event_reason_field', 'Half a thought');
      await tester.tap(find.byKey(const Key('record_close')));
      await tester.pumpAndSettle();
      expect(find.text('Discard this record?'), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byType(HealthEventFormScreen), findsOneWidget);
    });
  });
}
