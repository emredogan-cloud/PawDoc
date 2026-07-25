// Internal-test hardening: an offline cold start must not leave Home on
// skeletons forever.
//
// Device-found (Redmi Note 11R, airplane mode): the pets read had no timeout,
// so the socket stalled, the future never settled, and Home rendered loading
// skeletons indefinitely — the "could not load" retry branch below it was
// unreachable. `kDataReadTimeout` bounds the read so this branch actually runs.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/core/connectivity.dart';
import 'package:pawdoc/src/core/data_timeout.dart';
import 'package:pawdoc/src/home/home_screen.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';

void main() {
  test('the pets read is bounded, and generously enough for a slow network', () {
    expect(kDataReadTimeout, greaterThanOrEqualTo(const Duration(seconds: 8)));
    expect(kDataReadTimeout, lessThanOrEqualTo(const Duration(seconds: 20)));
  });

  testWidgets('a timed-out pets load shows connection copy + retry, and keeps '
      'Emergency reachable', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petsListProvider.overrideWith(
            (ref) => Future<List<Pet>>.error(
              TimeoutException('pets', kDataReadTimeout),
            ),
          ),
          connectivityProvider.overrideWith((ref) => Stream.value(false)),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The red path stays reachable when the pet list cannot load — this is the
    // safety invariant the offline cold start exists to protect.
    expect(find.byKey(const Key('home_emergency_button')), findsOneWidget);

    // Offline-aware copy (not a raw exception, not a dead skeleton) + a way out.
    expect(find.textContaining('check your connection'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('TimeoutException'), findsNothing);
  });
}
