// M3 (#16): saving a health event — under reduce-motion the form pops
// immediately (no morph beat); the morph never blocks an error path.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/health/health_event.dart';
import 'package:pawdoc/src/health/health_event_form_screen.dart';
import 'package:pawdoc/src/health/health_events_repository.dart';

void _stubAnalytics(WidgetTester tester) {
  // _save awaits an analytics capture; stub PostHog so it resolves headless
  // (same pattern as onboarding_test).
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('posthog_flutter'), (call) async => null);
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('posthog_flutter'), null));
}

class _FakeRepo implements HealthEventsRepository {
  _FakeRepo({this.fail = false});
  final bool fail;
  int created = 0;

  @override
  Future<HealthEvent> create(HealthEvent event) async {
    if (fail) throw Exception('db down');
    created++;
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

void main() {
  testWidgets('save pops the form (reduce-motion: no morph delay)',
      (tester) async {
    final repo = _FakeRepo();
    _stubAnalytics(tester);
    await tester.pumpWidget(_host(repo));
    await tester.tap(find.byKey(const Key('event_save_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repo.created, 1);
    expect(find.byType(HealthEventFormScreen), findsNothing,
        reason: 'reduce-motion path pops without the 320ms beat');
  });

  testWidgets('failure keeps the form usable with the error message',
      (tester) async {
    _stubAnalytics(tester);
    await tester.pumpWidget(_host(_FakeRepo(fail: true)));
    await tester.tap(find.byKey(const Key('event_save_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Could not save the event'), findsOneWidget);
    expect(find.text('Save event'), findsOneWidget); // button restored
    await tester.pump(const Duration(seconds: 4)); // drain snackbar
  });
}
