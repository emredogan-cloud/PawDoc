// Phase F — home re-rank. Verifies the warm empty state and that logout is no
// longer a one-tap AppBar action (moved into the overflow menu).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/core/connectivity.dart';
import 'package:pawdoc/src/home/home_screen.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';

void main() {
  testWidgets('Home empty state is warm; logout is not a one-tap AppBar action',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petsListProvider.overrideWith((ref) async => <Pet>[]),
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Warm, illustrated welcome with a single "Add your pet" CTA.
    expect(find.text('Welcome to PawDoc 🐾'), findsOneWidget);
    expect(find.byKey(const Key('home_add_pet')), findsOneWidget);

    // Logout lives in the overflow menu (closed here), NOT as a top-level icon.
    expect(find.byKey(const Key('home_overflow_menu')), findsOneWidget);
    expect(find.byKey(const Key('sign_out_button')), findsNothing);

    // Open the menu → "Sign out" is now reachable.
    await tester.tap(find.byKey(const Key('home_overflow_menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sign_out_button')), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });
}
