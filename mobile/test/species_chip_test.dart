// Phase J — shared SpeciesChip (onboarding + pet form). Labeled (a11y) + tappable.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/pets/species_chip.dart';

void main() {
  testWidgets('SpeciesChip shows a plain-text label and fires onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpeciesChip(species: 'dog', selected: false, onTap: () => taps++),
      ),
    ));
    expect(find.text('Dog'), findsOneWidget);
    await tester.tap(find.text('Dog'));
    expect(taps, 1);
  });

  testWidgets('SpeciesChip shows a check when selected', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpeciesChip(species: 'guinea_pig', selected: true, onTap: () {}),
      ),
    ));
    expect(find.text('Guinea pig'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
