// Internal-test hardening: a health record with no content must not be saveable.
//
// Device-found (Redmi Note 11R): "Save event" on an untouched form wrote a
// vaccination row with `notes: null, metadata: null` — a record the owner can
// neither read nor act on, sitting in the history a vet is meant to read. The
// weight type had the same hole: an unparseable weight saved a weight event
// carrying no weight.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/health/health_event.dart';
import 'package:pawdoc/src/health/health_event_form_screen.dart';
import 'package:pawdoc/src/health/health_events_repository.dart';

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

Widget _host(HealthEventsRepository repo) => ProviderScope(
      overrides: [healthEventsRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(
        home: HealthEventFormScreen(petId: 'p1', petName: 'rex'),
      ),
    );

void _stubAnalytics(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('posthog_flutter'), (call) async => null);
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('posthog_flutter'), null));
}

/// The form is a ListView; fields below the fold aren't built until scrolled to.
Future<void> _fill(WidgetTester tester, String key, String text) async {
  await tester.scrollUntilVisible(find.byKey(Key(key)), 120,
      scrollable: find.byType(Scrollable).first);
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

void main() {
  testWidgets('an untouched form cannot be saved, and says what is missing',
      (tester) async {
    final repo = _RecordingRepo();
    _stubAnalytics(tester);
    await tester.pumpWidget(_host(repo));

    expect(find.byKey(const Key('event_save_hint')), findsOneWidget);
    expect(find.textContaining('vaccine name'), findsWidgets);

    await tester.tap(find.byKey(const Key('event_save_button')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.created, isEmpty, reason: 'no content-free record is written');
    expect(find.byType(HealthEventFormScreen), findsOneWidget,
        reason: 'the form stays open instead of silently "succeeding"');
  });

  testWidgets('naming the vaccine unlocks the save', (tester) async {
    final repo = _RecordingRepo();
    _stubAnalytics(tester);
    await tester.pumpWidget(_host(repo));

    await _fill(tester, 'event_vaccine_name_field', 'Rabies');
    expect(find.byKey(const Key('event_save_hint')), findsNothing);

    await tester.tap(find.byKey(const Key('event_save_button')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.created.single.metadata?['vaccine_name'], 'Rabies');
  });

  testWidgets('a weight event needs a plausible weight', (tester) async {
    final repo = _RecordingRepo();
    _stubAnalytics(tester);
    await tester.pumpWidget(_host(repo));

    await tester.tap(find.text('Weight'));
    await tester.pump();
    expect(find.byKey(const Key('event_save_hint')), findsOneWidget);

    // Not a number → still blocked.
    await _fill(tester, 'event_weight_field', 'abc');
    expect(find.byKey(const Key('event_save_hint')), findsOneWidget);

    // Out of range → still blocked.
    await _fill(tester, 'event_weight_field', '900');
    expect(find.byKey(const Key('event_save_hint')), findsOneWidget);

    // Plausible (and comma decimals are accepted) → saveable.
    await _fill(tester, 'event_weight_field', '31,4');
    expect(find.byKey(const Key('event_save_hint')), findsNothing);

    await tester.tap(find.byKey(const Key('event_save_button')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.created.single.metadata?['weight_kg'], 31.4);
  });
}
