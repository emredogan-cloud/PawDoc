// Phase B (honesty) — pet-name token hardening. Proves personalized copy never
// renders "check on ker" or "in 's health".
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/core/pet_display.dart';

void main() {
  group('petDisplayName', () {
    test('capitalizes a lowercase name', () {
      expect(petDisplayName('ker'), 'Ker');
    });

    test('leaves an already-capitalized name unchanged', () {
      expect(petDisplayName('Rex'), 'Rex');
    });

    test('falls back to "your pet" for null', () {
      expect(petDisplayName(null), 'your pet');
    });

    test('falls back to "your pet" for empty', () {
      expect(petDisplayName(''), 'your pet');
    });

    test('falls back to "your pet" for whitespace only', () {
      expect(petDisplayName('   '), 'your pet');
    });

    test('trims surrounding whitespace, then capitalizes', () {
      expect(petDisplayName('  bella  '), 'Bella');
    });

    test('only the first letter is capitalized (rest preserved)', () {
      expect(petDisplayName('mr fluffy'), 'Mr fluffy');
      expect(petDisplayName('mcFluff'), 'McFluff');
    });
  });

  group('petDisplayPossessive', () {
    test('forms a possessive with a typographic apostrophe', () {
      expect(petDisplayPossessive('ker'), 'Ker’s');
    });

    test('uses the neutral fallback for an empty name', () {
      expect(petDisplayPossessive(''), 'your pet’s');
    });
  });
}
