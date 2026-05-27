import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pet.dart';
import 'pets_repository.dart';

/// Persists the last-selected pet across launches.
class ActivePetPrefs {
  static const _key = 'pawdoc.active_pet_id';

  static Future<void> save(String petId) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, petId);
  }

  static Future<String?> load() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_key);
  }
}

/// Holds the user-selected active pet id. `null` until the user picks one (or it
/// is hydrated from prefs); [activePetProvider] resolves the actual [Pet] and
/// falls back to the first pet, so the home always has context.
class ActivePetId extends Notifier<String?> {
  @override
  String? build() {
    _hydrate();
    return null;
  }

  Future<void> _hydrate() async {
    final saved = await ActivePetPrefs.load();
    if (saved != null && state == null) state = saved;
  }

  /// Switch the active pet. Updating state makes every dependent provider
  /// ([activePetProvider], the breed card, the timeline) recompute reactively.
  void select(String petId) {
    state = petId;
    ActivePetPrefs.save(petId); // best-effort; selection still applies in-memory
  }
}

final activePetIdProvider =
    NotifierProvider<ActivePetId, String?>(ActivePetId.new);

/// The currently active [Pet]: the selected one if it is still in the list, else
/// the first pet, else null when there are no pets. Recomputes whenever the pet
/// list or the selection changes — this is what makes a switch update the whole
/// home/history/breed surface at once.
final activePetProvider = Provider<Pet?>((ref) {
  final pets = ref.watch(petsListProvider).maybeWhen(
        data: (list) => list,
        orElse: () => const <Pet>[],
      );
  if (pets.isEmpty) return null;
  final id = ref.watch(activePetIdProvider);
  if (id != null) {
    for (final pet in pets) {
      if (pet.id == id) return pet;
    }
  }
  return pets.first;
});
