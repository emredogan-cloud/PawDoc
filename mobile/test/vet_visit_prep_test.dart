// Mockup `prepare_for_vet_visit`.
//
// The reference's third symptom control is a **Severity** meter reading
// "Moderate" — a signal-strength bar beside a symptom, which reads as an
// assessment when the only assessment on the screen is the owner's. It ships
// as a trajectory instead: better, worse, the same, comes and goes. That is
// the question a vet asks and the one the prep pack was built to answer.
//
// The rest is arithmetic: which of the six stops are done, and what the pack
// carries. Both are pure, so the reference's "4 / 6 Completed" is computed
// rather than drawn.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/export/health_report.dart';
import 'package:pawdoc/src/health/health_event.dart';
import 'package:pawdoc/src/health/health_events_repository.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';
import 'package:pawdoc/src/prep/vet_visit_prep.dart';
import 'package:pawdoc/src/prep/vet_visit_prep_screen.dart';
import 'package:pawdoc/src/reminders/reminder.dart';
import 'package:pawdoc/src/reminders/reminders_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pet = Pet(
  id: 'p1',
  userId: 'u1',
  name: 'Buddy',
  species: 'dog',
  breed: 'Golden Retriever',
  weightKg: 28.2,
);

void _surface(WidgetTester tester, {double height = 4600}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

Widget _app({
  List<Reminder>? reminders,
  List<HealthEvent>? events,
  Map<String, Object> prefs = const {},
}) {
  SharedPreferences.setMockInitialValues(prefs);
  return ProviderScope(
    overrides: [
      petsListProvider.overrideWith((ref) async => const [_pet]),
      remindersForPetProvider
          .overrideWith((ref, petId) async => reminders ?? const []),
      healthEventsRepositoryProvider
          .overrideWithValue(_FakeEvents(events ?? const [])),
    ],
    child: const MaterialApp(home: VetVisitPrepScreen(pet: _pet)),
  );
}

class _FakeEvents implements HealthEventsRepository {
  _FakeEvents(this._events);

  final List<HealthEvent> _events;

  @override
  Future<List<HealthEvent>> listForPet(String petId) async => _events;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _pageText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' ')
    .toLowerCase();

void main() {
  group('progress is counted, not drawn', () {
    test('a blank draft has completed nothing', () {
      expect(completedPrepSteps(const VisitPrepDraft(), recordItems: 0),
          isEmpty);
    });

    test('any reason completes the first stop', () {
      final done = completedPrepSteps(
          const VisitPrepDraft(reasons: {'cough'}), recordItems: 0);
      expect(done, contains(PrepStep.reason));
      expect(done, hasLength(1));
    });

    test('a free-text "Other" reason counts even with no chip', () {
      expect(
        completedPrepSteps(const VisitPrepDraft(otherReason: 'dental quote'),
            recordItems: 0),
        contains(PrepStep.reason),
      );
    });

    test('any one symptom field completes the second stop', () {
      for (final draft in [
        VisitPrepDraft(startedOn: DateTime(2026, 8, 1)),
        const VisitPrepDraft(frequency: SymptomFrequency.daily),
        const VisitPrepDraft(change: SymptomChange.worse),
        const VisitPrepDraft(notes: 'coughs in the morning'),
      ]) {
        expect(completedPrepSteps(draft, recordItems: 0),
            contains(PrepStep.symptoms));
      }
    });

    test('whitespace is not an answer', () {
      expect(
        completedPrepSteps(const VisitPrepDraft(notes: '   ', otherReason: ' '),
            recordItems: 0),
        isEmpty,
      );
    });

    test('the record stop is filled by the record, not by typing', () {
      expect(completedPrepSteps(const VisitPrepDraft(), recordItems: 3),
          contains(PrepStep.record));
      expect(completedPrepSteps(const VisitPrepDraft(), recordItems: 0),
          isNot(contains(PrepStep.record)));
    });

    test('an empty question row does not count as a question', () {
      expect(
        completedPrepSteps(const VisitPrepDraft(questions: ['', '  ']),
            recordItems: 0),
        isNot(contains(PrepStep.questions)),
      );
    });

    test('the summary stop is something the owner did, not something we tick',
        () {
      final everythingElse = VisitPrepDraft(
        reasons: const {'cough'},
        notes: 'a note',
        bring: const {'medications'},
        questions: const ['why?'],
      );
      expect(completedPrepSteps(everythingElse, recordItems: 5),
          isNot(contains(PrepStep.summary)));
      expect(
        completedPrepSteps(
            everythingElse.copyWith(reviewedAt: DateTime(2026, 8, 8)),
            recordItems: 5),
        contains(PrepStep.summary),
      );
    });
  });

  group('the draft survives the back button', () {
    test('round-trips through storage', () async {
      SharedPreferences.setMockInitialValues(const {});
      final draft = VisitPrepDraft(
        reasons: const {'cough', 'other'},
        otherReason: 'second opinion',
        startedOn: DateTime(2026, 8, 1),
        frequency: SymptomFrequency.occasional,
        change: SymptomChange.worse,
        notes: 'quieter than usual on walks',
        bring: const {'medications', 'media'},
        questions: const ['how long should this take?'],
        reviewedAt: DateTime(2026, 8, 8, 9),
      );
      await VisitPrepDraft.save('p1', draft);
      final back = await VisitPrepDraft.load('p1');

      expect(back.reasons, draft.reasons);
      expect(back.otherReason, draft.otherReason);
      expect(back.startedOn, draft.startedOn);
      expect(back.frequency, SymptomFrequency.occasional);
      expect(back.change, SymptomChange.worse);
      expect(back.notes, draft.notes);
      expect(back.bring, draft.bring);
      expect(back.questions, draft.questions);
      expect(back.reviewedAt, draft.reviewedAt);
    });

    test('a corrupt draft is a blank draft, never a crash', () async {
      SharedPreferences.setMockInitialValues(
          {VisitPrepDraft.storeKey('p1'): 'not json at all'});
      expect((await VisitPrepDraft.load('p1')).reasons, isEmpty);
    });

    test('drafts are per pet', () async {
      SharedPreferences.setMockInitialValues(const {});
      await VisitPrepDraft.save(
          'p1', const VisitPrepDraft(reasons: {'cough'}));
      expect((await VisitPrepDraft.load('p2')).reasons, isEmpty);
    });
  });

  group('what the pack carries', () {
    test('the owner’s answers are transcribed, never interpreted', () {
      final lines = visitPrepAnswerLines(VisitPrepDraft(
        reasons: const {'cough', 'appetite'},
        startedOn: DateTime(2026, 8, 1),
        frequency: SymptomFrequency.daily,
        change: SymptomChange.worse,
        notes: 'less active than usual',
        bring: const {'medications'},
      ));
      expect(lines, contains('Reason for the visit: Coughing, Loss of appetite'));
      expect(lines, contains('First noticed: 2026-08-01'));
      expect(lines, contains('How often: Most days'));
      expect(lines, contains('Since then: Getting worse'));
      expect(lines, contains('In the owner’s words: less active than usual'));
      expect(lines, contains('Bringing: Medications'));
      // No urgency, no timeframe, no advice is derived from any of it.
      final joined = lines.join(' ').toLowerCase();
      for (final banned in [
        'urgent',
        'emergency',
        'severe',
        'severity',
        'within',
        'you should',
        'recommend',
      ]) {
        expect(joined.contains(banned), isFalse, reason: banned);
      }
    });

    test('a blank draft contributes nothing', () {
      expect(visitPrepAnswerLines(const VisitPrepDraft()), isEmpty);
    });

    test('the pack labels the owner section as owner-entered (V-22)', () {
      final pack = buildVetVisitPrepPack(
        pet: _pet,
        recentAnalyses: const [],
        events: const [],
        ownerAnswers: const ['Reason for the visit: Coughing'],
        visitOn: DateTime(2026, 8, 20),
        now: DateTime(2026, 8, 8),
      );
      expect(pack, contains('## About this visit'));
      expect(pack, contains('_Source: entered by the owner._'));
      expect(pack, contains('Appointment: Aug 20, 2026'));
      // The owner's own account comes before anything a model produced.
      expect(pack.indexOf('## About this visit'),
          lessThan(pack.indexOf('## Recent AI checks')));
    });

    test('a pack with no owner answers is unchanged from before', () {
      final pack = buildVetVisitPrepPack(
          pet: _pet, recentAnalyses: const [], events: const []);
      expect(pack, isNot(contains('About this visit')));
      expect(pack, isNot(contains('Appointment:')));
    });
  });

  group('the screen', () {
    testWidgets('draws every block the reference draws', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Prepare for Vet Visit'), findsOneWidget);
      expect(find.byKey(const Key('prep_progress')), findsOneWidget);
      expect(find.byKey(const Key('prep_reasons')), findsOneWidget);
      expect(find.byKey(const Key('prep_symptoms')), findsOneWidget);
      expect(find.byKey(const Key('prep_record')), findsOneWidget);
      expect(find.byKey(const Key('prep_bring')), findsOneWidget);
      expect(find.byKey(const Key('prep_questions')), findsOneWidget);
      expect(find.byKey(const Key('prep_review_summary')), findsOneWidget);
      // Every reason chip in the reference.
      for (final r in kVisitReasons) {
        expect(find.byKey(Key('prep_reason_${r.id}')), findsOneWidget);
      }
      // Every bring tile.
      for (final b in kBringItems) {
        expect(find.byKey(Key('prep_bring_${b.id}')), findsOneWidget);
      }
      expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget);
    });

    testWidgets('no severity control exists, on any state', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final text = _pageText(tester);
      expect(text, isNot(contains('severity')));
      expect(text, isNot(contains('moderate')));
      expect(text, contains('how it is changing'));
    });

    testWidgets('the emergency strip is present and reads nothing back',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('prep_urgent_strip')), findsOneWidget);

      // Selecting the most alarming reasons must not change a single word of
      // it — a triage verdict is not this screen's job.
      final before = _pageText(tester);
      await tester.tap(find.byKey(const Key('prep_reason_vomiting')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('prep_urgent_strip')), findsOneWidget);
      expect(_pageText(tester).contains('if it cannot wait for the appointment'),
          isTrue);
      expect(before.contains('if it cannot wait for the appointment'), isTrue);
    });

    testWidgets('picking a reason advances the counter and persists',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('0 / 6'), findsOneWidget);

      await tester.tap(find.byKey(const Key('prep_reason_cough')));
      await tester.pumpAndSettle();
      expect(find.text('1 / 6'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(VisitPrepDraft.storeKey('p1')),
          contains('cough'));
    });

    testWidgets('tapping a chosen reason clears it again', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('prep_reason_cough')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('prep_reason_cough')));
      await tester.pumpAndSettle();
      expect(find.text('0 / 6'), findsOneWidget);
    });

    testWidgets('"Other" reveals a field, and only when chosen',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('prep_other_reason')), findsNothing);

      await tester.tap(find.byKey(const Key('prep_reason_other')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('prep_other_reason')), findsOneWidget);
    });

    testWidgets('the bring list is a real checklist', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('prep_bring_medications')));
      await tester.pumpAndSettle();
      expect(find.text('1 / 6'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(VisitPrepDraft.storeKey('p1')),
          contains('medications'));
    });

    testWidgets('an example question can be added and removed',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('prep_question_examples')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('prep_example_0')));
      await tester.pumpAndSettle();
      expect(find.text(kQuestionExamples.first), findsOneWidget);
      expect(find.text('1 / 6'), findsOneWidget);

      await tester.tap(find.byKey(const Key('prep_question_remove_0')));
      await tester.pumpAndSettle();
      expect(find.text('0 / 6'), findsOneWidget);
      // The editor always keeps one row to type into.
      expect(find.byKey(const Key('prep_question_0')), findsOneWidget);
    });

    testWidgets('the record card counts what is filed, and says when nothing '
        'is', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(events: [
        HealthEvent(
            petId: 'p1',
            eventType: 'vaccination',
            eventDate: DateTime(2026, 7, 1)),
        HealthEvent(
            petId: 'p1',
            eventType: 'medication',
            eventDate: DateTime(2026, 7, 2)),
      ]));
      await tester.pumpAndSettle();
      // Scoped to the record card: "Medications" is also a bring-list tile.
      final card = find.byKey(const Key('prep_record'));
      expect(find.descendant(of: card, matching: find.text('Vaccinations')),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Medications')),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Recent checks')),
          findsOneWidget);
      // Two events ⇒ the record stop is done.
      expect(find.text('1 / 6'), findsOneWidget);
    });

    testWidgets('an empty record says so rather than showing zeroes',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(_pageText(tester), contains('nothing is filed for this pet yet'));
    });

    testWidgets('with no reminder the visit block offers to add one',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('prep_add_visit')), findsOneWidget);
      expect(find.text('No visit booked'), findsOneWidget);
    });

    testWidgets('a vet reminder becomes the upcoming visit — date only',
        (tester) async {
      _surface(tester);
      final due = DateTime.now().add(const Duration(days: 5));
      await tester.pumpWidget(_app(reminders: [
        Reminder(
            id: 'r1',
            petId: 'p1',
            reminderType: 'Vet appointment',
            dueDate: DateTime(due.year, due.month, due.day)),
        // A non-visit reminder must not be mistaken for one.
        Reminder(
            id: 'r2',
            petId: 'p1',
            reminderType: 'Flea & tick medication',
            dueDate: DateTime(due.year, due.month, due.day)),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Upcoming visit'), findsOneWidget);
      expect(find.byKey(const Key('prep_open_visit')), findsOneWidget);
      expect(find.text('In 5 days'), findsOneWidget);
      // The reference prints "10:30 AM"; reminders hold no time, so no clock
      // time of any shape may appear. (A bare `contains('am')` would trip on
      // "Medications".)
      expect(RegExp(r'\d{1,2}:\d{2}\s*(am|pm)?').hasMatch(_pageText(tester)),
          isFalse);
    });

    testWidgets('a past reminder is not an upcoming visit', (tester) async {
      _surface(tester);
      final past = DateTime.now().subtract(const Duration(days: 3));
      await tester.pumpWidget(_app(reminders: [
        Reminder(
            id: 'r1',
            petId: 'p1',
            reminderType: 'Vet appointment',
            dueDate: DateTime(past.year, past.month, past.day)),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('No visit booked'), findsOneWidget);
    });

    testWidgets('Review summary shows the pack itself and marks the stop done',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('prep_reason_cough')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('prep_review_summary')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('prep_summary_text')), findsOneWidget);
      expect(find.byKey(const Key('prep_share_button')), findsOneWidget);
      final pack = tester
          .widget<SelectableText>(find.byKey(const Key('prep_summary_text')))
          .data!;
      expect(pack, contains('# Vet Visit Prep — Buddy'));
      expect(pack, contains('Reason for the visit: Coughing'));
      expect(pack, contains('not a veterinary diagnosis'));

      // Dismiss the sheet; the sixth stop is now done.
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(find.text('2 / 6'), findsOneWidget);
    });

    testWidgets('the screen says where the draft is kept', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Saved on this device'), findsOneWidget);
    });

    testWidgets('a saved draft is restored when the screen reopens',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(prefs: {
        VisitPrepDraft.storeKey('p1'):
            '{"reasons":["limping"],"notes":"favouring the left hind leg",'
                '"bring":["media"],"questions":["is an x-ray needed?"]}',
      }));
      await tester.pumpAndSettle();

      expect(find.text('4 / 6'), findsOneWidget,
          reason: 'reason + symptoms + bring + questions');
      expect(find.text('is an x-ray needed?'), findsOneWidget);
    });
  });

  group('safety', () {
    testWidgets('nothing on the screen grades, diagnoses or sets a timeframe',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final text = _pageText(tester);
      for (final banned in [
        'severity',
        'risk',
        'urgent',
        'likely',
        'diagnos',
        'infection',
        'within 24',
        'you should',
        'we recommend',
      ]) {
        expect(text.contains(banned), isFalse, reason: banned);
      }
    });

    testWidgets('it never promises the pack improves clinical accuracy',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      // The reference: "These help your vet make accurate decisions."
      expect(_pageText(tester), isNot(contains('accurate')));
      expect(_pageText(tester),
          contains('the things vets most often ask an owner to bring'));
    });
  });
}
