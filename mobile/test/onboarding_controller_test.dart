/// Tests for the onboarding draft controller.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/features/onboarding/onboarding_controller.dart';
import 'package:pawdoc/shared/models/pet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('OnboardingDraft.validate', () {
    test('rejects empty species', () {
      const d = OnboardingDraft();
      expect(d.validate(), isNotNull);
    });

    test('rejects empty name', () {
      const d = OnboardingDraft(species: PetSpecies.dog);
      expect(d.validate(), contains('name'));
    });

    test('rejects whitespace-only name', () {
      const d = OnboardingDraft(species: PetSpecies.dog, name: '   ');
      expect(d.validate(), contains('name'));
    });

    test('rejects birth date in the future', () {
      final d = OnboardingDraft(
        species: PetSpecies.dog,
        name: 'Luna',
        birthDate: DateTime.now().add(const Duration(days: 30)),
      );
      expect(d.validate(), contains('future'));
    });

    test('rejects implausibly old age', () {
      final d = OnboardingDraft(
        species: PetSpecies.dog,
        name: 'Luna',
        birthDate: DateTime(1900),
      );
      expect(d.validate(), contains('implausible'));
    });

    test('rejects non-positive weight', () {
      const d = OnboardingDraft(
        species: PetSpecies.dog,
        name: 'Luna',
        weightKg: -1,
      );
      expect(d.validate(), contains('positive'));
    });

    test('rejects oversized notes', () {
      final d = OnboardingDraft(
        species: PetSpecies.dog,
        name: 'Luna',
        notes: 'x' * 600,
      );
      expect(d.validate(), contains('too long'));
    });

    test('accepts a complete valid draft', () {
      final d = OnboardingDraft(
        species: PetSpecies.cat,
        name: 'Whiskers',
        birthDate: DateTime(2020, 5, 1),
        weightKg: 4.2,
        breed: 'Maine Coon',
        notes: 'allergic to chicken',
      );
      expect(d.validate(), isNull);
    });
  });

  group('OnboardingController', () {
    test('starts empty when no draft saved', () async {
      final prefs = await SharedPreferences.getInstance();
      final ctrl = OnboardingController(prefs);
      expect(ctrl.state, equals(OnboardingDraft.empty()));
    });

    test('persists updates across instances', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ctrl1 = OnboardingController(prefs);
      ctrl1.update(
        const OnboardingDraft(species: PetSpecies.dog, name: 'Luna'),
      );
      // Force the debounced save to flush.
      await Future<void>.delayed(const Duration(milliseconds: 400));

      final ctrl2 = OnboardingController(prefs);
      expect(ctrl2.state.species, PetSpecies.dog);
      expect(ctrl2.state.name, 'Luna');
    });

    test('clear wipes the saved draft', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ctrl = OnboardingController(prefs);
      ctrl.update(const OnboardingDraft(species: PetSpecies.cat, name: 'Kit'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await ctrl.clear();
      expect(ctrl.state, equals(OnboardingDraft.empty()));

      final ctrl2 = OnboardingController(prefs);
      expect(ctrl2.state, equals(OnboardingDraft.empty()));
    });
  });

  group('OnboardingDraft round-trip JSON', () {
    test('serializes and restores all fields', () {
      final original = OnboardingDraft(
        species: PetSpecies.rabbit,
        name: 'Hopper',
        birthDate: DateTime(2022, 3, 15),
        sex: PetSex.female,
        weightKg: 2.1,
        breed: 'Holland Lop',
        notes: 'shy with strangers',
      );
      final restored = OnboardingDraft.fromJson(original.toJson());
      expect(restored.species, original.species);
      expect(restored.name, original.name);
      expect(restored.birthDate, original.birthDate);
      expect(restored.sex, original.sex);
      expect(restored.weightKg, original.weightKg);
      expect(restored.breed, original.breed);
      expect(restored.notes, original.notes);
    });
  });
}
