// Phase J — pets list: warm empty state + identity row (name + species·breed).
// M0 F-4 — the last-check chip renders whenever a triage exists.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/analysis/analysis_service.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_list_screen.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';

void main() {
  testWidgets('Pets list shows a warm empty state', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [petsListProvider.overrideWith((ref) async => <Pet>[])],
      child: const MaterialApp(home: PetsListScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('No pets yet'), findsOneWidget);
    // The warm empty state survives the `manage_multiple_pets` rebuild; the
    // affordance is the dashed add card the rest of the app uses rather than a
    // bare FilledButton, and the header keeps its own Add Pet pill.
    expect(find.byKey(const Key('pets_empty')), findsOneWidget);
    expect(find.byKey(const Key('pets_add')), findsOneWidget);
  });

  testWidgets('Pets list renders an identity row (name + species·breed)',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        petsListProvider.overrideWith((ref) async => const [
              Pet(id: 'p1', userId: 'u', name: 'rex', species: 'dog', breed: 'Labrador'),
            ]),
      ],
      child: const MaterialApp(home: PetsListScreen()),
    ));
    await tester.pumpAndSettle();

    // Name is display-capitalized; meta shows species · breed.
    expect(find.text('Rex'), findsOneWidget);
    expect(find.textContaining('Dog · Labrador'), findsOneWidget);
  });

  testWidgets('Pets list renders the last-check chip when a triage exists (F-4)',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        petsListProvider.overrideWith((ref) async => const [
              Pet(id: 'p1', userId: 'u', name: 'rex', species: 'dog', breed: 'Labrador'),
            ]),
        latestTriageProvider.overrideWith((ref, petId) =>
            LatestTriage(level: 'CALL_TODAY', checkedAt: DateTime.now())),
      ],
      child: const MaterialApp(home: PetsListScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('last_check_chip_p1')), findsOneWidget);
    // Friendly ladder label, not the raw `CALL_TODAY` wire token (RC UX fix).
    expect(find.text('Call today'), findsOneWidget);
  });

  testWidgets('No chip when the pet has no checks yet', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        petsListProvider.overrideWith((ref) async => const [
              Pet(id: 'p1', userId: 'u', name: 'rex', species: 'dog'),
            ]),
        latestTriageProvider.overrideWith((ref, petId) => null),
      ],
      child: const MaterialApp(home: PetsListScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(Chip), findsNothing);
  });
}
