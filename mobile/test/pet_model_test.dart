/// Pet model + age math.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/shared/models/pet.dart';

void main() {
  group('Pet.fromJson', () {
    test('parses a minimal pet', () {
      final pet = Pet.fromJson(const {
        'id': 'p-1',
        'user_id': 'u-1',
        'name': 'Luna',
        'species': 'dog',
        'is_active': true,
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(pet.name, 'Luna');
      expect(pet.species, PetSpecies.dog);
      expect(pet.isActive, isTrue);
    });

    test('parses all optional fields', () {
      final pet = Pet.fromJson(const {
        'id': 'p-1',
        'user_id': 'u-1',
        'name': 'Whiskers',
        'species': 'cat',
        'breed': 'Maine Coon',
        'birth_date': '2020-05-01',
        'sex': 'female',
        'weight_kg': 4.2,
        'photo_url': 'https://example.test/x.jpg',
        'medical_notes': 'allergic',
        'is_active': true,
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(pet.breed, 'Maine Coon');
      expect(pet.sex, PetSex.female);
      expect(pet.weightKg, 4.2);
    });

    test('throws on missing/invalid species', () {
      expect(
        () => Pet.fromJson(const {
          'id': 'p-1',
          'user_id': 'u-1',
          'name': 'Luna',
          'species': 'reindeer',
          'is_active': true,
          'created_at': '2026-01-01T00:00:00Z',
        }),
        throwsFormatException,
      );
    });
  });

  group('Pet.ageYears', () {
    test('returns null when DOB unknown', () {
      final pet = Pet(
        id: 'p',
        userId: 'u',
        name: 'x',
        species: PetSpecies.dog,
        createdAt: DateTime.now(),
      );
      expect(pet.ageYears, isNull);
    });

    test('rounds down correctly across birthday boundary', () {
      // Birthday tomorrow → age is N-1.
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final dobOneYearMinusOneDay = DateTime(
        tomorrow.year - 5,
        tomorrow.month,
        tomorrow.day,
      );
      final pet = Pet(
        id: 'p',
        userId: 'u',
        name: 'x',
        species: PetSpecies.dog,
        birthDate: dobOneYearMinusOneDay,
        createdAt: now,
      );
      expect(pet.ageYears, 4);
    });
  });

  group('PetCreate.toJson', () {
    test('omits null optional fields', () {
      const c = PetCreate(userId: 'u-1', name: 'Luna', species: PetSpecies.dog);
      final j = c.toJson();
      expect(j, isNot(contains('breed')));
      expect(j, isNot(contains('weight_kg')));
      expect(j['species'], 'dog');
    });

    test('formats birth_date as YYYY-MM-DD', () {
      final c = PetCreate(
        userId: 'u',
        name: 'L',
        species: PetSpecies.cat,
        birthDate: DateTime(2024, 3, 5),
      );
      expect(c.toJson()['birth_date'], '2024-03-05');
    });
  });

  group('PetSpecies / PetSex tryParse', () {
    test('handles known values case-insensitively', () {
      expect(PetSpecies.tryParse('DOG'), PetSpecies.dog);
      expect(PetSpecies.tryParse('rabbit'), PetSpecies.rabbit);
      expect(PetSex.tryParse('FEMALE'), PetSex.female);
    });

    test('returns null for unknown / null', () {
      expect(PetSpecies.tryParse('hamster'), isNull);
      expect(PetSpecies.tryParse(null), isNull);
      expect(PetSex.tryParse('other'), isNull);
    });
  });
}
