// Phase J — pets list: warm empty state + identity row (name + species·breed).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.widgetWithText(FilledButton, 'Add a pet'), findsOneWidget);
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
}
