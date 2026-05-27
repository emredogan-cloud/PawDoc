import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/pets/pet.dart';

void main() {
  test('Pet round-trips through JSON (snake_case columns)', () {
    const json = {
      'id': 'p1',
      'user_id': 'u1',
      'name': 'Rex',
      'species': 'dog',
      'breed': 'Labrador',
      'birth_date': '2022-05-01',
      'sex': 'M',
      'weight_kg': 30.5,
      'photo_url': null,
      'medical_notes': null,
      'is_active': true,
    };
    final pet = Pet.fromJson(json);
    expect(pet.name, 'Rex');
    expect(pet.species, 'dog');
    expect(pet.weightKg, 30.5);
    expect(pet.birthDate, DateTime(2022, 5, 1));

    final cols = pet.toColumns();
    expect(cols['birth_date'], '2022-05-01'); // date-only, not a full timestamp
    expect(cols.containsKey('user_id'), isFalse); // set by the repository
  });

  test('kSpecies covers the onboarding grid', () {
    expect(kSpecies, containsAll(['dog', 'cat', 'rabbit', 'bird', 'reptile']));
  });
}
