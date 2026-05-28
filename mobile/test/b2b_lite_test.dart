// Phase 5.4 — B2B-Lite (sitter) tier wiring. Asserts the same gating rules as
// premium/family/trial, plus the unlimited-pets limit and the client_name
// round-trip on the Pet model.
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/account/user_profile.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pet_limits.dart';

void main() {
  group('pet_limits', () {
    test('Family and B2B-Lite are unlimited', () {
      expect(petLimitFor('family'), isNull);
      expect(petLimitFor('b2b_lite'), isNull);
      // Defense-in-depth: canAddPet returns true even at huge counts.
      expect(canAddPet('b2b_lite', 99), isTrue);
    });
    test('Free / trial / Premium are capped at 2', () {
      expect(petLimitFor('free'), 2);
      expect(petLimitFor('trial'), 2);
      expect(petLimitFor('premium'), 2);
      expect(canAddPet('premium', 2), isFalse);
    });
  });

  group('UserProfile.isPremium', () {
    test('B2B-Lite unlocks premium features', () {
      const u = UserProfile(subscriptionStatus: 'b2b_lite', freeUsedThisMonth: 0);
      expect(u.isPremium, isTrue);
    });
    test('Existing premium tiers still pass', () {
      expect(
        const UserProfile(subscriptionStatus: 'premium', freeUsedThisMonth: 0).isPremium,
        isTrue,
      );
      expect(
        const UserProfile(subscriptionStatus: 'family', freeUsedThisMonth: 0).isPremium,
        isTrue,
      );
      expect(
        const UserProfile(subscriptionStatus: 'trial', freeUsedThisMonth: 0).isPremium,
        isTrue,
      );
    });
    test('Free does not', () {
      expect(
        const UserProfile(subscriptionStatus: 'free', freeUsedThisMonth: 0).isPremium,
        isFalse,
      );
    });
  });

  group('Pet.clientName', () {
    test('round-trips JSON and toColumns', () {
      final pet = Pet.fromJson(const {
        'id': 'p1',
        'user_id': 'u1',
        'name': 'Buddy',
        'species': 'dog',
        'client_name': 'Smith family',
      });
      expect(pet.clientName, 'Smith family');
      expect(pet.toColumns()['client_name'], 'Smith family');
    });
    test('defaults to null when absent', () {
      final pet = Pet.fromJson(const {
        'id': 'p1',
        'user_id': 'u1',
        'name': 'Buddy',
        'species': 'dog',
      });
      expect(pet.clientName, isNull);
      expect(pet.toColumns()['client_name'], isNull);
    });
  });
}
