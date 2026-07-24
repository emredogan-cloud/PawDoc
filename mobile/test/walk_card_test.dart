// Next Evolution Phase 5 — Home walk card states (fixed controller states;
// no location/network).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';
import 'package:pawdoc/src/walks/walk_scorer.dart';
import 'package:pawdoc/src/walks/walk_card.dart';
import 'package:pawdoc/src/walks/walks_controller.dart';
import 'package:pawdoc/src/walks/weather_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedWalks extends WalksController {
  _FixedWalks(this.fixed);
  final WalksState fixed;

  @override
  WalksState build() => fixed; // no auto-refresh, no prefs, no location
}

Widget _app(WalksState state) {
  SharedPreferences.setMockInitialValues(const {});
  return ProviderScope(
    overrides: [
      walksControllerProvider.overrideWith(() => _FixedWalks(state)),
      petsListProvider.overrideWith((ref) async =>
          const [Pet(id: 'p1', userId: 'u1', name: 'Rex', species: 'dog')]),
    ],
    child: const MaterialApp(home: Scaffold(body: WalkCard())),
  );
}

void main() {
  testWidgets('initial state is a pre-prompt with the privacy line',
      (tester) async {
    await tester.pumpWidget(_app(const WalksInitial()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('walk_card_initial')), findsOneWidget);
    expect(find.byKey(const Key('walk_card_enable')), findsOneWidget);
    expect(find.textContaining('never stored'), findsOneWidget);
    expect(find.textContaining('Rex'), findsOneWidget);
  });

  testWidgets('permission-needed renders a calm settings path',
      (tester) async {
    await tester.pumpWidget(_app(const WalksPermissionNeeded(
        deniedForever: true, serviceOff: false)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('walk_card_permission')), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('ready state shows the ring, headline, and pet copy',
      (tester) async {
    final hour = HourlyWeather(
      time: DateTime(2026, 7, 24, 12),
      tempC: 15,
      windMs: 2,
      precipMm: 0,
    );
    await tester.pumpWidget(_app(WalksReady(
      hours: [hour],
      now: scoreWalkHour(hour),
      todayWindows: const [],
      places: const [],
      lat: 52.52,
      lon: 13.405,
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('walk_card_ready')), findsOneWidget);
    expect(find.text('Great walk weather'), findsOneWidget);
    expect(find.textContaining('Rex'), findsOneWidget);
    expect(find.textContaining('15°C'), findsOneWidget);
  });

  testWidgets('error state offers retry', (tester) async {
    await tester.pumpWidget(_app(const WalksError()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('walk_card_error')), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
