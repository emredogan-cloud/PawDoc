import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics.dart';
import 'pet.dart';
import 'pet_form_screen.dart';
import 'pets_repository.dart';

/// Single entry point for "Add pet", used by both the home switcher and the
/// "My pets" screen. No pet cap on any tier; fires `multi_pet_added` once the
/// user has more than one pet.
Future<void> startAddPetFlow(BuildContext context, WidgetRef ref) async {
  final pets = ref.read(petsListProvider).maybeWhen(
        data: (list) => list,
        orElse: () => const <Pet>[],
      );

  final added = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const PetFormScreen()),
  );
  if (added == true) {
    ref.invalidate(petsListProvider);
    final newCount = pets.length + 1;
    if (newCount > 1) await Analytics.multiPetAdded(newCount);
  }
}
