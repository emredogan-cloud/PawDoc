import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../capture/image_compressor.dart' show SquareCrop;
import '../pets/pet.dart';
import '../pets/pet_photo_service.dart';
import '../pets/pets_repository.dart';

/// The pet collected during onboarding, held until there is a session to
/// own it.
///
/// The first-run journey now runs **before** authentication (`0001` →
/// `002`–`009` → the auth gateway), and `PetsRepository.create` reads
/// `auth.currentUser!.id`. So the add-pet step used to throw a null-check the
/// page swallowed as "Could not save your pet. Try again." — the flow could not
/// be finished at all from a cold install. Device-confirmed on the Redmi before
/// this existed.
///
/// The draft is deliberately in memory only, like [FirstRun]: it lives for the
/// few seconds between the add-pet page and the gateway. If the process dies in
/// between, home's empty state asks for the pet again, which is the correct
/// outcome — nothing is silently half-saved.
class PendingPet {
  const PendingPet._();

  static Pet? _pet;

  /// The chosen photo, still local. Uploading needs a session too, so the
  /// bytes and the crop travel with the draft and are uploaded on [flush].
  static (Uint8List, SquareCrop)? _photo;

  static bool get isPending => _pet != null;

  static void hold(Pet pet, {(Uint8List, SquareCrop)? photo}) {
    _pet = pet;
    _photo = photo;
  }

  static void clear() {
    _pet = null;
    _photo = null;
  }

  /// Creates the held pet, once. Safe to call on every authenticated launch:
  /// it returns immediately when nothing is pending.
  ///
  /// Fails soft — a pet without its photo is worth far more than no pet, so an
  /// upload error does not abort the create, and a create error leaves the
  /// draft in place for the next attempt rather than dropping it.
  static Future<void> flush(WidgetRef ref) async {
    final pet = _pet;
    if (pet == null) return;

    String? photoKey;
    final photo = _photo;
    if (photo != null) {
      try {
        photoKey =
            await ref.read(petPhotoServiceProvider).cropAndUpload(photo.$1, photo.$2);
      } catch (e) {
        debugPrint('PendingPet: photo upload failed, saving without it — $e');
      }
    }

    try {
      await ref.read(petsRepositoryProvider).create(
            Pet(
              userId: '',
              name: pet.name,
              species: pet.species,
              breed: pet.breed,
              birthDate: pet.birthDate,
              sex: pet.sex,
              photoKey: photoKey,
            ),
          );
      clear();
      ref.invalidate(petsListProvider);
    } catch (e) {
      debugPrint('PendingPet: create failed, keeping the draft — $e');
    }
  }
}
