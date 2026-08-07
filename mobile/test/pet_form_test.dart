// Mockup `edit_pet`.
//
// The reference draws five fields `pets` has no column for — Neutered, Colour,
// Microchip ID, Blood Type and Pet Personality. Each keeps its exact place in
// the grid, renders as a real control and says *Soon*; none is quietly dropped
// and none is faked by folding a value into `medical_notes`, which would push
// a microchip number into the vet report as a clinical note.
//
// It also paints "Delete Pet" in the EMERGENCY red — the colour that means
// GET_HELP_NOW everywhere else in the app, including the nav bar on this very
// screen. The ladder's hues are locked against reuse, so the button keeps its
// position and glyph in the substitute tint. Pinned below.
//
// The form had no test at all before this rebuild.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/health/health_sections.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pet_form_screen.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _pet = Pet(
  id: 'p1',
  userId: 'u1',
  name: 'Buddy',
  species: 'dog',
  breed: 'Golden Retriever',
  sex: 'male',
  weightKg: 28,
  birthDate: DateTime(DateTime.now().year - 3, 1, 1),
  medicalNotes: 'Sensitive to chicken.',
);

void _surface(WidgetTester tester, {double height = 2800}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

Widget _app({Pet? pet}) {
  SharedPreferences.setMockInitialValues(const {});
  return ProviderScope(
    overrides: [
      petsListProvider.overrideWith((ref) async => pet == null ? [] : [pet]),
    ],
    child: MaterialApp(home: PetFormScreen(pet: pet)),
  );
}

void main() {
  group('the mockup, drawn', () {
    testWidgets('every block the reference draws is present', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(pet: _pet));
      await tester.pumpAndSettle();

      expect(find.text('Edit Pet'), findsOneWidget);
      expect(find.byKey(const Key('pet_delete')), findsOneWidget);
      expect(find.byKey(const Key('pet_photo_button')), findsWidgets);
      expect(find.byKey(const Key('pet_name_field')), findsOneWidget);
      expect(find.text('Basic Information'), findsOneWidget);
      expect(find.text('Additional Information'), findsOneWidget);
      expect(find.text('Profile Photo'), findsOneWidget);
      expect(find.text('Health Summary'), findsOneWidget);
      expect(find.byKey(const Key('pet_cancel_button')), findsOneWidget);
      expect(find.byKey(const Key('pet_save_button')), findsOneWidget);
      expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget);
    });

    testWidgets('the record loads into the fields', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(pet: _pet));
      await tester.pumpAndSettle();

      expect(find.text('Buddy'), findsWidgets);
      expect(find.text('Golden Retriever'), findsOneWidget);
      expect(find.text('Dog'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('28.0'), findsOneWidget);
      expect(find.text('Sensitive to chicken.'), findsOneWidget);
    });

    testWidgets('age is calculated from the birthday, never typed',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(pet: _pet));
      await tester.pumpAndSettle();
      expect(find.text('Calculated'), findsOneWidget);
      expect(find.textContaining('3y'), findsWidgets);
    });

    testWidgets('with no birthday the age slot asks for one', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(
        pet: const Pet(id: 'p1', userId: 'u1', name: 'Rex', species: 'cat'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Set a birthday'), findsOneWidget);
      expect(find.text('Calculated'), findsNothing);
    });

    testWidgets('adding a pet hides Delete and renames the CTA',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Add a Pet'), findsOneWidget);
      expect(find.byKey(const Key('pet_delete')), findsNothing);
      expect(find.text('Add Pet'), findsOneWidget);
    });
  });

  group('the fields with no column keep their place', () {
    testWidgets('all five render, in the grid, saying Soon', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(pet: _pet));
      await tester.pumpAndSettle();

      for (final key in [
        'pet_neutered_soon',
        'pet_colour_soon',
        'pet_microchip_soon',
        'pet_blood_soon',
        'pet_personality_soon',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget,
            reason: '$key must be drawn, not dropped');
      }
      expect(find.text('Neutered'), findsOneWidget);
      expect(find.text('Microchip ID'), findsOneWidget);
      expect(find.text('Blood type'), findsOneWidget);
      expect(find.text('Soon'), findsNWidgets(5));
    });

    testWidgets('tapping one says what is missing, rather than nothing',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(pet: _pet));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pet_microchip_soon')));
      await tester.pumpAndSettle();
      expect(find.textContaining('not stored yet'), findsOneWidget);
    });
  });

  group('validation', () {
    testWidgets('a nameless pet cannot be saved, and is told why',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pet_save_button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Give your pet a name'), findsWidgets);
      // Still on the form.
      expect(find.byKey(const Key('pet_save_button')), findsOneWidget);
    });

    testWidgets('an impossible weight is rejected with a readable message',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('pet_name_field')), 'Rex');
      await tester.enterText(find.byKey(const Key('pet_weight_field')), '900');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pet_save_button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Enter a weight in kg'), findsWidgets);
    });

    testWidgets('no error is shown before the first save attempt',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.textContaining('Give your pet a name'), findsNothing);
    });
  });

  group('the delete flow is safe', () {
    testWidgets('it confirms, and says the record survives', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(pet: _pet));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pet_delete')));
      await tester.pumpAndSettle();

      expect(find.text('Remove Buddy?'), findsOneWidget);
      expect(find.textContaining('Past health records and AI checks are kept'),
          findsOneWidget);
      expect(find.byKey(const Key('pet_delete_confirm')), findsOneWidget);

      // Cancelling leaves the pet alone.
      await tester.tap(find.text('Cancel').first);
      await tester.pumpAndSettle();
      expect(find.text('Remove Buddy?'), findsNothing);
    });

    testWidgets('the delete control is not painted in a ladder hue',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(pet: _pet));
      await tester.pumpAndSettle();

      const ladder = [
        Color(0xFFFF5A52), // emergencyDark
        Color(0xFFC62828), // emergencyLight
        Color(0xFFFFC233), // monitorDark
        Color(0xFFFFB300), // monitorLight
        Color(0xFF1565C0), // actionBookVisit
        Color(0xFF455A64), // actionWatch
      ];
      final pill = tester.widget<HealthActionPill>(
          find.byKey(const Key('pet_delete')));
      expect(ladder.contains(pill.color), isFalse,
          reason: 'the emergency red means GET_HELP_NOW, and the nav bar '
              'below this button is already using it for that');
    });
  });

  group('safety', () {
    testWidgets('the notes field says where its text ends up', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(pet: _pet));
      await tester.pumpAndSettle();
      expect(find.textContaining('your vet report quotes'), findsOneWidget);
      expect(find.textContaining('as your words'), findsOneWidget);
    });

    testWidgets('the photo card states the EXIF strip', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(pet: _pet));
      await tester.pumpAndSettle();
      expect(find.textContaining('Location data is stripped'), findsWidgets);
    });

    testWidgets('nothing on the form grades the animal', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(pet: _pet));
      await tester.pumpAndSettle();
      for (final banned in [
        'Health Score',
        'Excellent',
        'Great',
        'Healthy',
        'Up to date',
      ]) {
        expect(find.textContaining(banned), findsNothing);
      }
    });
  });
}
