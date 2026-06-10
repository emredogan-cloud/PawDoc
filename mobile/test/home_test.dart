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

    // Account entry present; sign-out is NOT a one-tap home action — it now
    // lives inside the Account screen behind a confirm (roadmap §3.10.2).
    expect(find.byKey(const Key('home_account_button')), findsOneWidget);
    expect(find.byKey(const Key('sign_out_button')), findsNothing);
  });
}
